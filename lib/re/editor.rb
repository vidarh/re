require 'readline'

class BufferFactory
  def initialize server
    @server = server
  end

  def lines_from_data(data)
    if data.empty?
      ['']
    else
      line_sep = data["\r\n"] || "\n"
      data.split(line_sep)
    end
  end

  def read_file_data(filename)
    if filename && File.exist?(filename)
      File.read(filename)
    else
      ''
    end
  end

  def set_buffer_contents(buffer, cursor,data, created_at = Time.now)
    buffer.created_at = created_at
    buffer.modify(cursor, 0..-1) do |_|
      lines_from_data(data)
    end
  end

  def reload(buffer,cursor)
    data = read_file_data(buffer.name)
    set_buffer_contents(buffer,cursor,data, Time.now)
  end

  def open(filename, data = "\n", created_at = Time.at(0))
    base = File.basename(filename)

    data = lines_from_data(data)  
    buffer = @server.new_buffer(filename, data, created_at)

    if base == "buffer-list"
      set_buffer_contents(buffer,Cursor.new(0,0), @server.list_buffers)
    end

    buffer
  end

end

class Editor
  attr_reader :cursor, :buffer, :lastchar, :message, :mode, :search, :mark

  def open_buffer(filename,data)
    @line_sep = data["\r\n"] || "\n" # FIXME: Should be property of Buffer
    @buffer   = @factory.open(filename,data, Time.now)
    init_buffer
  end

  def init_buffer
    @do_refresh = true
    @buffer.add_observer(self,:update)
    @cursor   = Cursor.new
    @filename = @buffer.name

    Dir.chdir(File.dirname(@filename))
    choose_mode

    mtime = File.mtime(@filename) rescue Time.at(0)
    if Time.at(@buffer.created_at.to_i) < mtime
      prompt("File changed on disk (created_at=#{@buffer.created_at}, mtime=#{mtime}. Reload? (y/n)")
      loop do
        char = @ctrl.read_char
        if char
          if char == "y"
            reload
            break
          elsif char == "n"
            break
          else
            p char
          end
        end
      end
    end
  end

  def open(filename = nil)
    filename ||= gets("Filename: ")

    @filename,row = filename.split(":")
    data      = @factory.read_file_data(@filename)

    open_buffer(File.expand_path(@filename),data)

    reset_screen

    if row
      row = row.to_i
      @view.down(row-10)
      @cursor  = @cursor.down(buffer,row)
      @message = "Starting at #{row}"
    end
  end

  def initialize(filename: nil, factory: nil, buffer: nil)
    @filename = nil
    @factory  = BufferFactory.new(factory)

    @view     = View.new(self)
    @ctrl     = Controller.new(self)

    @buffer   = buffer
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
    @mode = Modes.choose(filename: @filename, first_line: @buffer.lines(0))
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

  private

  attr_reader :blank_buffer, :line_sep, :filename

  def render
    IO.console.raw do
      @view.render
    end
  end

  def gets(str = "")
    prompt
    Readline::readline("#{str} ")
  end

 def prompt(str = "")
   @view.move(@view.height+1,0)
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

 def find_next
   right
   left if !find_forward
 end

  def find(str = nil)
    @search = str || @search || ""

    update = -> do
      render    
      prompt("Find: #{@search}")
    end

    update.call
    @mark = cursor    
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
        elsif char == "\cf"
          find_next
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

    def goto_line(num = nil)
      if num.nil?
        numstr = gets("Line: ") do |str,ch|
          "0123456789".include?(ch[0])
        end

        num = numstr.to_i if !numstr.empty?
      end

      if !num.nil?
        @cursor = @cursor.move(@buffer,num+10, @cursor.col)
      end
    end

    def split_vertical
      case ENV["DESKTOP_SESSION"]
      when "bspwm"
        system("sh -c 'bspc node -p south ; exec term e --buffer #{@buffer.buffer_id}' &")
      else
        system("i3-msg 'split vertical; exec term e --buffer #{@buffer.buffer_id}'")
      end
    end

    def split_horizontal
      case ENV["DESKTOP_SESSION"]
      when "bspwm"
        system("sh -c 'bspc node -p east ; exec term e --buffer #{@buffer.buffer_id}' &")
      else
        system("i3-msg 'split horizontal; exec term e --buffer #{@buffer.buffer_id}'")
      end
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
        @yank_buffer.modify(@yank_cursor, 0..-1) do
          [""]
        end
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
          enter(no_indent: true)
        end
        buffer.insert(cursor, line)
        @cursor = @cursor.right(buffer, line.size)
        first = false
      end
    end

    def insert_tab
      2.times { insert_char(" ") }
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
      @buffer.modify(cursor,row) do |line|
        (" "*pos)+line.lstrip
      end
      @cursor = Cursor.new(row,pos).clamp(@buffer)
    end


    def handle_input
      if char = @ctrl.handle_input
        @lastchar = char
        @do_refresh = true
      end
    end

    def refresh
      reset_screen
      render
    end

    def quit
      reset_screen
      exit
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
      @cursor = cursor.up(buffer,off)
    end

    def down(off=1)
      @cursor = cursor.down(buffer,off)
    end

    def right
      @cursor = cursor.right(buffer)
    end

    def left
      @cursor = cursor.left(buffer)
    end

    def join_line
      buffer.join_lines(cursor)
    end

    def backspace
      return if cursor.beginning_of_file?


      if cursor.col == 0
        cursor_left = buffer.lines(cursor.row).size + 1
        buffer.join_lines(cursor,-1)
        cursor_left.times { @cursor = cursor.left(buffer) }
      else
        buffer.delete(cursor, cursor.col - 1)
        @cursor = cursor.left(buffer)
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
      data = buffer.lines(0..-1).join(line_sep).chomp(line_sep)
      data << line_sep unless data.empty?
      data
    end

    def save
      begin
        FileWriter.write(filename, data)
        @buffer.created_at = File.mtime(filename).to_i + 1
        @message = "#{filename} saved"
      rescue Exception => e
        @message = "Error saving #{filename}: #{e.message}"
      end
    end

    def enter no_indent: false
      @buffer.break_line(cursor)
      @cursor = cursor.enter(buffer)
      indent unless no_indent
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
      buffer.insert(cursor, char)
      @cursor = cursor.right(buffer)
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

  end
