require 'readline'
require 'editorconfig'
require_relative 'bufferfactory'
require_relative 'bufferintercept'
require_relative 'keymap'
require 'termcontroller'
require 'timeout'
require 'editor_core'
require_relative 'search'
require_relative 'helperregistry'
require_relative 'detect_file_or_url'

include EditorCore

class Editor < EditorCore::Core
  include Search

  attr_reader :lastcmd, :message, :mode, :search, :mark, :view, :ctrl,:model
  attr_reader :blank_buffer, :line_sep, :filename, :config, :debug_buffer
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
        cmd, char = @ctrl.handle_input
        return char if cmd == :char && (char == "y" || char == "n")
      end
    end
  end

  def load_config
    @config = EditorConfig.load_file(@filename)
    if @config.dig("rouge_theme")
      @view.opts[:theme] = @config["rouge_theme"]
    end
    if @config.dig("background_color")
      @view.opts[:background_color] = @config["background_color"]
    end
    if @config.dig("show_lineno")
      @view.opts[:show_lineno] = @config["show_lineno"] == "true"
      @view.opts[:left_margin] = @config["left_margin"] == "true"
    end

    if l = @config.dig("max_line_length")
      @view.opts[:max_line_length] = l == "off" ? nil : l.to_i
    end
    @view.reset! unless @headless
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

  #
  #FIXME: Refactor out
  #
  def filename_or_url_at_cursor
    line = buffer.lines(cursor.row)
    fname, type = detect_file_or_url(line, cursor.col)
    @message = "#{fname} / #{type}"
    return if !fname
    if type == :file
      path = File.dirname(self.filename)
      return path+"/"+fname.to_s, :file
    end
    return fname, type
  end

  def filename_at_cursor
    fname, type = filename_or_url_at_cursor
    type == :file ? fname : nil
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

  def url_open(f)
    @message = @helpers.url_open(f)
  end

  def open_at_cursor
    f, type = filename_or_url_at_cursor
    return if !f

    return url_open(f) if type == :url

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

    fname ||= @helpers.select_file
    return if fname == "" || fname.nil?
    fname = fname.strip
    @filename,row = fname.split(":")
    data      = @factory.read_file_data(@filename)
    open_buffer(File.expand_path(@filename),data)

    reset_screen

    goto_line(row.to_i) if row

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

  def initialize(filename: nil, factory: nil, buffer: nil, intercept: false, readonly: false, headless: false)
    @intercept = intercept
    @filename = nil
    @factory  = BufferFactory.new(factory)

    @headless = headless

    @view     = View.new(self)
    @model    = ViewModel.new(self)
    @ctrl     = readonly ? nil : Termcontroller::Controller.new(self, KeyBindings.map)
    @helpers = HelperRegistry.new

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
    @debug_buffer = @factory.open("*debug*")
  end

  def resize
    update(self)
  end

  def log *data
    @log ||= Logger.new(File.open(File.expand_path("~/.re-log.txt"),"a+"))
    @log.debug(data.join(" "))
  end

  # FIXME: Track which buffer.
  def update(context = self)
    # FIXME: log context
    @do_refresh = true
    @ctrl.commands << :render unless @paste_mode
  end

  def choose_mode
    # Fragment to allow us to parse mode lines etc.
    src = Array(@buffer.lines(0..4)).concat(Array(@buffer.lines(-5..-1)))
    oldmode = @mode
    @mode = Modes.choose(
      filename: @filename,
      source: src,
      language: @config.dig("source_language")
    )

    if @chosentheme
      @mode.theme = @chosentheme
    end

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
    #@view.reset!
  end

  def run
    reset_screen
    @just_refreshed = false
    loop do
      # FIXME: Call "#update" instead?
      # Thou
      if @do_refresh
        render
        @do_refresh = false
      end
      handle_input
    end
  end

  def render
    # Don't render while pasting... Might want to ease up on that
    # to re-render every x milliseconds etc., but this speeds up paste
    # substantially.
    return if @paste_mode || @headless

    IO.console.raw do
      @view.render
    end
  end

  def gets(str = "")
    prompt
    str = @ctrl.pause { Readline::readline("#{str} ") }
    reset_screen
    str
  end

  def prompt(str = "")
    puts ANSI.move_cursor(@view.height-2,0)
    print ANSI.el
    $stdout.print str
    $stdout.flush
  end

  def switch_buffer
    sel = @helpers.select_buffer
    return if sel.empty?
    if b = @factory.get_buffer(sel.to_i)
      @buffer = b
      init_buffer
    end
  end

  def mouse_down action, x, y
    # FIXME: Update termcontroller to cook the
    #   button values etc.
    case action
    when 0, 32 # 32 on subsequent move
      # Left button
      if x > @view.text_xoff
#        move(y+view.top-1, x-view.text_xoff+view.xoff-1)
        @cursor = @cursor.move(@buffer, y+@view.top-1, x-@view.text_xoff+@view.xoff-1)
      end
    when 1 # Middle button
      @message="1"
    when 2 # Right button
      @message="2"
    when 64 # Scroll wheel up
      view_up(2)
      @do_refresh=true
    when 65 # Scroll wheel down
      view_down(2)
      @do_refresh=true
    else
      @message=action.to_s
    end
  end

  # Quiet UI event reporting
  def mouse_up *args; end
  def mouse_click *args; end

  def goto_line(num = nil)
    if num.nil?
      numstr = gets("Line:") do |str,ch|
        "0123456789".include?(ch[0])
      end

      num = Integer(numstr) rescue nil
    end

    if !num.nil?
      move(num-1, cursor.col)
      # FIXME: How do I adjust the view so this ends
      # up more in the middle? Seems like view_down() should
      # do this, but view_down also shifts the cursor?
    end
  end

  def select_theme(theme=nil)
    theme ||= @helpers.select_syntax_theme
    @chosentheme = theme # Persist across open
    @mode.theme = theme
    view.reset!
    refresh
  end

  def split_vertical
    @helpers.split_vertical(@buffer.buffer_id)
  end

  def split_vertical_term(cmd = nil)
    @helpers.split_vertical_term
  end

  def split_horizontal
    @helpers.split_horizontal(@buffer.buffer_id)
  end

  def split_horizontal_term(cmd = nil)
    @helpers.split_horizontal_term(cmd)
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
    char("\t")
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
    # FIXME: Does supporting this make sense any more?
    if !@ctrl
      sleep(0.1)
      @do_refresh = true
      @message = "Read Only View"
      return
    end

    if c = @ctrl.handle_input
      @lastcmd = @ctrl.lastcmd if @ctrl.lastcmd
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
      char(ch)
    end
  end

  def enter(no_indent: false, paste: false)
    rstrip_line # Strip the end of the current line
    @buffer.break_line(cursor)
    rstrip_line # Strip the end after splitting.
    @cursor = cursor.enter(buffer)

    # FIXME: Generalize support for hooks
    if !@paste_mode && !paste
      indent unless no_indent
      insert_prefix
    end
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

  def cursor_at_soft_break?
    @view.opts[:max_line_length] &&
    cursor.col >= @view.opts[:max_line_length]
  end

  def char(ch)
    # FIXME: I'm not sure if this makes sense
    # combined with the check for "soft_break"
    # in #break_line
    if cursor_at_soft_break?
      if ch == ' '
        enter
        line_end
        join_line
        line_home
        return
      end
    end

    buffer.insert(cursor, ch)
    @do_refresh = true #@view.update_line(cursor.row)
    if cursor_at_soft_break?
      break_line
    end

    right(ch.size)
    render
  end

  def reset_screen
    return if @headless
    IO.console.raw do
      @view.reset_screen
    end
    @do_refresh = true
  end

  def reload
    @factory.reload(@buffer, cursor)
    @line_sep = "\n"
    @cursor = cursor.clamp(@buffer)
    @message = "Reloaded #{filename}"
    @do_refresh = true
  end

  def suspend
    @ctrl.suspend do
      puts ANSI.move_cursor(@view.height-2,0)
    end
  end

  def resume; reset_screen end

  def toggle_lineno
    o = self.view.opts
    o[:show_lineno] = !o[:show_lineno]
    reset_screen
  end

  def toggle_highlight
    o = self.view.opts
    o[:highlight] = !o[:highlight]
    reset_screen
  end
  
  def pry(e=nil)
    @ctrl.pause do
      #puts ANSI.cls
      binding.pry
    end
    reset_screen
  end
end
