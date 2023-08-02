require 'readline'
require 'editorconfig'
require_relative 'bufferfactory'
require_relative 'bufferintercept'
require_relative 'keymap'
require 'editor_core'

include EditorCore

class Editor < EditorCore::Core
  attr_writer :message

  attr_accessor :intercept

  def possibly_intercept(buffer)
    return nil if buffer.nil?
    intercept ? BufferIntercept.new(buffer) : buffer
  end

  def open_buffer(filename,data)
    @line_sep = data["\r\n"] || "\n" # FIXME: Should be property of Buffer
    @buffer   = possibly_intercept(@factory.open(filename,data, Time.now))
    init_buffer
  end

  def read_yn
    @ctrl.raw do
      loop do
        char = @ctrl.read_char
        return char if char == "y" || char == "n"
      end
    end
  end

  def load_config
    @config = EditorConfig.load_file(@filename)
    if @config.dig("rouge_theme")
      @view.opts[:theme] = @config["rouge_theme"]
    end
    if @config.dig("show_lineno")
      @view.opts[:show_lineno] = @config["show_lineno"] == "true"
    end

    if l = @config.dig("max_line_length")
      @view.opts[:max_line_length] = l == "off" ? nil : l.to_i
    end
    @view.reset!
  end

  def init_buffer
    @do_refresh = true
    @buffer.add_observer(self,:update)
    @cursor   = Cursor.new
    @filename = @buffer.name

    begin
      Dir.chdir(File.dirname(@filename))
    rescue Errno::ENOENT
      @message = "WARNING: No such directory: #{File.dirname(@filename)}. Unable to open file"
      return
    end

    load_config
    choose_mode

    mtime = File.mtime(@filename) rescue Time.at(0)
    if @buffer.created_at.to_i < mtime.to_i
      prompt("File changed on disk (created_at=#{@buffer.created_at}, mtime=#{mtime}. Reload? (y/n)")
      reload if read_yn == "y"
    end
  end

  def filename_at_cursor
    line = buffer.lines(cursor.row)
    start = line.rindex(/[<(\[']/, cursor.col)
    return if !start
    if line[start] == "["
      start = line.index("](")
      return if !start
      start += 1
    end
    start+=1
    stop = line.index(/[>)']/, cursor.col)
    return if !stop
    stop-=1
    fname = line[start..stop].split(":")
    if fname.length > 1
      if fname != "file"
        return nil
      end
      fname.shift
    end
    path = File.dirname(self.filename)
    path+"/"+fname.first
  end

  def open_previous
    prev = @prevfile
    return if !prev
    c = @prevcursor
    @prevfile = self.filename
    @prevcursor = self.cursor
    open(prev)
    @cursor = c
  end

  def open_at_cursor
    f = filename_at_cursor
    return if !f

    if File.directory?(f)
      if File.exists?(f+".md")
        f += ".md"
      else
        f += "/index.md"
      end
    end
    if !File.exists?(f)
      if[-3..-1] != ".md"
        f += ".md"
      end
    end
    open(f)
  end

  def open(fname = nil)
    @prevfile = self.filename
    @prevcursor = self.cursor

    fname ||= `filesel` #gets("Filename: ")
    return if fname == "" || fname.nil?
    fname = fname.strip
    @filename,row = fname.split(":")
    data      = @factory.read_file_data(@filename)
    open_buffer(File.expand_path(@filename),data)

    reset_screen

    if row
      row = row.to_i
      @view.down(row-10)
      @cursor  = @cursor.down(buffer,row)
      @message = "Starting at #{row}"
    end
  rescue Errno::EISDIR
    Dir.chdir(fname)
    fname = nil
    retry
  end


  def help
    open(File.expand_path("#{__FILE__}/../help.md"))
  end
  
  # For bracketed paste.
  def start_paste
    @paste_mode = true
  end

  def end_paste
    @paste_mode = false
  end

  def initialize(filename: nil, factory: nil, buffer: nil, intercept: false, readonly: false)
    @intercept = intercept
    @filename = nil
    @factory  = BufferFactory.new(factory)

    @view     = View.new(self)
    @model    = ViewModel.new(self)
    @ctrl     = readonly ? nil : Controller.new(self)

    @paste_mode = false

    @buffer   = possibly_intercept(buffer)
    if @buffer
      init_buffer
    else
      if filename
        open(filename)
      else
        open_buffer("(*scratch*)","") 
      end
    end

    @message  = ""
    @search   = ""
    @lastcmd  = nil
    @yank_buffer = @factory.open("*yank*")

    Signal.trap("WINCH") do
      update(self)
    end
  end

  def log *data
    @log ||= Logger.new(File.open(File.expand_path("~/.re-log.txt"),"a+"))
    @log.debug(data.first.name)
  rescue
  end

  # FIXME: Track which buffer.
  def update(context)
    log context
    @do_refresh = true
  end

  def choose_mode
    # Fragment to allow us to parse mode lines etc.
    src = Array(@buffer.lines(0..4)).concat(Array(@buffer.lines(-5..-1)))
    @mode = Modes.choose(filename: @filename, source: src, language: @config.dig("source_language"))

    if @view.opts[:theme]
      @mode.theme = view.opts[:theme]
    end

    src.each do |line|
      if line && line.match(/ re: ([a-zA-Z:]+)/)
        $1.split(":").each do |opt|
          case opt
          when "nolineno"
            view.opts[:show_lineno] = false
          end
        end
      end
    end
  end

  def run
    reset_screen

    loop do
      if @do_refresh
        render
        @do_refresh = false
      else
        @old_cursor = @cursor
      end
      handle_input
    end
  end

  attr_reader :blank_buffer, :line_sep, :filename

  def render
    # Don't render while pasting... Might want to ease up on that
    # to re-render every x milliseconds etc., but this speeds up paste
    # substantially.
    return if @paste_mode

    IO.console.raw do
      @view.render
    end
  end

  def gets(str = "")
    prompt
    @ctrl.pause do
      Readline::readline("#{str} ")
    end
  end

 def prompt(str = "")
   puts ANSI.move_cursor(@view.height-2,0)
   print ANSI.el
   $stdout.print str
   $stdout.flush
 end

 def find_forward
   row = cursor.row
   col = cursor.col
   max = buffer.lines_count
   while (row < max) && (line = buffer.lines(row))
     if i = line[col .. -1].index(@search)
       @cursor = Cursor.new(row,col+i)

       @do_refresh = true
       @mark = @cursor
       return true
     end
     row += 1
     col = 0
   end
   false
 end

 def goto_start
   @cursor = Cursor.new(0,0).clamp(@buffer)
   @do_refresh = true
 end

 def find_next
   right
   if find_forward
     true
   else
     goto_start
     @mark = @cursor
     false
   end
 end

  def find(str = nil)
    @search = str || @search || ""

    update = -> do
      render
      prompt("Find: #{@search}")
    end

    update.call
    @mark = cursor
    @ctrl.raw do
      loop do
        char = @ctrl.read_char
        if char
          if char == "\cc" || char == "\e"
            @search = ""
            @message = "Search terminated."
            break
          elsif char == "\177"
            @search.slice!(-1)
            find_forward
          elsif char == "\r"
            @message = "Search paused. To cont. press ^f; To cancel ^f + ^c"
            break
          elsif char == "\ck"
            @search = ""
          elsif char == "\cf"
            if find_next
            else
              find_next
              @message = "Wrapped around; ^f to restart search"
              break
            end
          elsif char =~ /\A[[:print:]]+\Z/
            @search += char
            find_forward
          else
#          @search += char.inspect
#          find_forward
          end
          update.call
        end
      end
    end
  end

  def switch_buffer
    sel =`select-buffer 2>/dev/null`
    return if sel.empty?
    if b = @factory.get_buffer(sel.to_i)
      @buffer = b
      init_buffer
    end
  end

    def goto_line(num = nil)
      if num.nil?
        numstr = gets("Line: ") do |str,ch|
          "0123456789".include?(ch[0])
        end

        num = numstr.to_i if !numstr.empty?
      end

      if !num.nil?
        @cursor = @cursor.move(@buffer,num+10, @cursor.col)
        @cursor = @cursor.move(@buffer,num-1, @cursor.col)
      end
    end

    def select_theme(theme=nil)
      theme ||= `select-rouge-theme`.strip
      @mode.theme = theme
      @view.reset!
      refresh
    end

    def split_vertical
      system("split-vertical term e --buffer #{@buffer.buffer_id}")
    end

    def split_vertical_term
      system("split-vertical term")
    end

    def split_horizontal(cmd=nil)
      if !cmd
        cmd = "term e --buffer #{@buffer.buffer_id}"
      end
      system("split-horizontal #{cmd}")
    end

    def split_horizontal_term(cmd = "")
      system("split-horizontal term #{cmd}")
    end

    def set_mode(m)
      @bufmode = m
    end

    def get_after
      @buffer.lines(cursor.row)[@cursor.col..-1]
    end

    def kill
      @yank_cursor ||= Cursor.new(0,0)
      if @yank_mark != cursor
        @yank_buffer.replace_contents(cursor,"")
        @yank_cursor = Cursor.new(0,0)
      end
      if @cursor.col >= @buffer.lines(@cursor.row).length
          @yank_buffer.break_line(@yank_cursor)
          @yank_cursor = @yank_cursor.enter(@yank_buffer)
        join_line
      else
        str = get_after
        @yank_buffer.insert(@yank_cursor, str)
        @yank_cursor = @yank_cursor.line_end(@yank_buffer)
        delete_after
      end
      @yank_mark = @cursor
    end

    def yank
      first = true
      @yank_buffer.lines(0..-1).each do |line|
        if !first
          enter(paste: true)
        end
        buffer.insert(cursor, line)
        right(line.size)
        first = false
      end
    end

    def insert_tab
      insert_char("\t")
    end

    def get_indent(row)
      return 0 if row < 0
      last_line = @buffer.lines(row)
      pos = 0
      while(last_line[pos] == " ")
        pos += 1
      end
      return nil if pos == last_line.length
      pos
    end

    def determine_indent(row)
      off = -1
      until pos = get_indent(row+off) do; off -= 1; end

      prev = @buffer.lines(row+off)
      cur  = @buffer.lines(row)
      calc_indent(pos, prev, cur)
    end

    def indent
      row = @cursor.row
      pos = determine_indent(row)
      @buffer.indent(cursor,row,pos)
      @cursor = Cursor.new(row,pos).clamp(@buffer)
    end


    def handle_input
      if !@ctrl
        sleep(0.1)
        @do_refresh = true
        @message = "Read Only View"
        return
      end

      if c = @ctrl.handle_input
        @lastchar = @ctrl.lastchar if @ctrl.lastchar
        @do_refresh = true
      end
    end

    def refresh
      reset_screen
      render
    end

    def quit
      reset_screen
      puts ANSI.cls
      IO.console.cooked!
      exit
    end

    def buffer_home
      @view.home
      @cursor = cursor.move(buffer, 0, cursor.col)
    end

    def buffer_end
      @view.end
      @cursor = cursor.move(buffer, buffer.lines_count, cursor.col)
    end

    def page_down
      lines = @view.down(@view.height-1)
      @cursor = cursor.down(buffer, @view.height-1)
    end

    def page_up
      lines = @view.up(@view.height-1)
      @cursor = cursor.up(buffer, lines)
    end

    def up(off=1)
      @cursor = cursor.up(buffer,off.to_i)
    end

    def down(off=1)
      @cursor = cursor.down(buffer,off.to_i)
    end

    def right(offset=1)
      @cursor = cursor.right(buffer,offset)
    end

    def left
      @cursor = cursor.left(buffer,1)
    end

    def join_line
      buffer.join_lines(cursor)
    end

    def backspace
      return if cursor.beginning_of_file?

      if cursor.col == 0
        cursor_left = buffer.lines(cursor.row).size + 1
        buffer.join_lines(cursor,-1)
        cursor_left.times { left }
      else
        buffer.delete(cursor, cursor.col - 1)
        left
      end
    end

    def delete
      return if cursor.end_of_file?(buffer)

      if cursor.end_of_line?(buffer)
        buffer.join_lines(cursor)
      else
        buffer.delete(cursor, cursor.col)
      end
    end

    def data
      line_sep ||= "\n"
      data = buffer.lines(0..-1).join(line_sep).chomp(line_sep) || []
      data << line_sep unless data.empty?
      data
    end

    def show_filename
      @message = filename
    end

    def save
      begin
        FileWriter.write(filename, data)
        @buffer.created_at = File.mtime(filename).to_i + 1
        @message = "#{filename} saved"
      rescue Exception => e
        @message = "Error saving #{filename}: #{e.message}"
        @message = e.backtrace.join(",")
      end
    end

    def insert_prefix
      r = cursor.row
      c = cursor.col
      return if r < 1
      prev = @buffer.lines(r-1)
      if ch = @mode.should_insert_prefix(c, prev)
        insert_char(ch)
      end
    end

    def current_line
      @buffer.lines(cursor.row)
    end

    def rstrip_line
      line = current_line
      stripped = current_line.rstrip
      return if line.length == stripped.length
      col = cursor.col
      oldc = cursor
      @cursor = cursor.move(@buffer, cursor.row, stripped.length)
      delete_after
      if col < stripped.length
        @cursor = oldc
      end
    end

    def enter(no_indent: false, paste: false)
      rstrip_line # Strip the end of the current line
      @buffer.break_line(cursor)
      rstrip_line # Strip the end after splitting.
      @cursor = cursor.enter(buffer)
      if !@paste_mode && !paste
        indent unless no_indent
        insert_prefix
      end
    end

    def prev_word
      return if cursor.col == 0
      line = current_line
      c = cursor.col
      if c > 0
        c -= 1
      end
      while c > 0 && line[c] && line[c].match(/[ \t]/)
        c -= 1
      end
      while c > 0 && !(line[c-1].match(/[ \t\-]/))
        c -= 1
      end
      off = cursor.col - c
      @cursor = Cursor.new(cursor.row, c)
      off
    end

    def break_line
      if @config.dig("soft_break")
        # FIXME: this will move the cursor,
        # without preserving position within the word
        off = prev_word
        enter
        right(off)
      else
        enter
      end
    end

    def history_undo
      return unless @buffer.can_undo?
      @cursor = @buffer.undo(cursor)
    end

    def history_redo
      return unless @buffer.can_redo?
      @cursor = @buffer.redo
    end

    def insert_char(char)
      if @view.opts[:max_line_length] && cursor.col >= @view.opts[:max_line_length]
        break_line
      end

      buffer.insert(cursor, char)
      @view.update_line(cursor.row)
      right(char.size)
    end

    def line_home
      @cursor = cursor.line_home
    end

    def line_end
      @cursor = cursor.line_end(buffer)
    end

    def delete_before
      @buffer.delete(cursor, 0, cursor.col)
      line_home
    end

    def delete_after
      @buffer.delete(cursor, cursor.col,-1)
    end

    def reset_screen
      IO.console.raw do
        @view.reset_screen
      end
      @do_refresh = true
    end


    def reload
      @factory.reload(@buffer, cursor)
      @line_sep = "\n"
      @cursor = Cursor.new(@cursor.row,@cursor.col).clamp(@buffer)
      @message = "Reloaded #{filename}"
      @do_refresh = true
    end

    def suspend
      begin
        Timeout.timeout(0.2) {
          @view.reset_screen
          puts "FIXME: Buggy suspend. Ctrl+z once more to suspend."
          Process.kill("STOP", Process.pid)
        }
      rescue Timeout::Error
        refresh
      end
    end

    def toggle_lineno
      o = self.view.opts
      o[:show_lineno] = !o[:show_lineno]
      reset_screen
    end

    def pry
      @ctrl.mode = :pause
      sleep(0.1)
      IO.console.cooked!
      puts ANSI.cls
      binding.pry
      @ctrl.mode = :cooked
      reset_screen
    end
  end
