# coding: utf-8
require_relative 'viewmodel'
require_relative 'termbuffer'

class View
  attr_reader :editor, :opts

  CUTOFF_MARKER     = ANSI.sgr(33) {"\u25b8"}
  MAX_LENGTH_MARKER = ANSI.sgr(33) {"\u25bf"}
  EOL_MARKER        = ANSI.sgr(30,49,:bold){"\u25c2"}


  # FIXME: This doesn't handle files 10000 lines and above.
  LINENO_FORMAT = "\e[38;2;0;192;0m\e[48;2;16;48;16m\e[1m%4d\e[38;2;16;48;16m\e[48;2;8;24;8m\u258B#{ANSI.sgr(0,49,39)} "
  LINENO_LEN = 6
  WBUF = 3 # Extra space for marks etc.
  TABCHAR = "\u2504"
  #TAB = AnsiTerm::String.new(ANSI.sgr(38,2,32,16,16)+"\u2503"+TABCHAR*3)
  #TAB = AnsiTerm::String.new(TABCHAR*4)
  TAB = AnsiTerm.str(" "*4).freeze

  MATCH_ATTRS = {
    true => AnsiTerm.attr(
      fgcol: 32,
      bgcol: 45,
      flags: AnsiTerm::Attr::UNDERLINE
    ),
    false => AnsiTerm::Attr.new(
      fgcol: 32,
      bgcol: 44
    )
  }.freeze

  TABS = [
    TAB[0..3].freeze,
    TAB[0..2].freeze,
    TAB[0..1].freeze,
    TAB[0..0].freeze
  ].freeze

  def initialize(editor)
    @editor = editor
    @top    = 0

    @x = 0
    @y = 0

    # If 0 or negative, relative to console width/height
    @w = 0
    @h = 0

    @out = TermBuffer.new(width, height)

    @opts = {
      show_lineno: true
    }
  end

  def buffer
    @editor.buffer
  end

  def cursor
    @editor.cursor
  end

  def winsize
    IO.console.winsize
  end

  def width
    @w > 0 ? @w : winsize[1]+@w
  end

  def text_xoff
    @opts[:show_lineno] ? LINENO_LEN : 1
  end

  def text_width
    width - WBUF - text_xoff
  end

  def height
    @h > 0 ? @h : winsize[0]+@h
  end

  def print *args
    @out.print(*args)
  end

  def render_status
    h,w = winsize

    if @opts[:max_line_length]
      off = @opts[:show_lineno] ? 4 : 0
      @out.move_cursor(@opts[:max_line_length]+1,0)
      print MAX_LENGTH_MARKER
    end

    pos = "(%d,%d)" % [cursor.col, cursor.row + 1]
    mode = (@editor.mode || "text").to_s
    status = "#{@editor.ctrl && @editor.ctrl.lastchar} #{pos} #{mode} "
    status = status[0..w-1] if status.length >= w

    @out.move_cursor(w-status.length-1,0)
    print "#{ANSI.sgr(48,2,32,32,32,37)} #{status}#{ANSI.sgr(49,37,:bold)}"
    msg = @editor.message[0.. w-1]
    @out.move_cursor(w-msg.size-2,h-1)
    print ANSI.sgr(:normal)+ANSI.sgr(37,45)+msg
    @editor.message = ""
    status.size
  end

  def down(offset = 1)
    oldtop = @top
    @top += offset
    if @top > buffer.lines_count
      @top = buffer.lines_count
    end
    @top - oldtop
  end

  def up(offset = 1)
    oldtop=@top
    @top -= offset
    @top = 0 if @top < 0
    oldtop - @top
  end

  def home
    @top = 0
  end

  def end
    @top = buffer.lines_count - height/2
  end

  def update_top
    h = height
    while cursor.row >= @top+h-2
      @top += 1
    end
    if cursor.row < @top+2
      @top = cursor.row-2
    end
    if @top < 0
      @top = 0
    end
  end

  def move(row,col)
    @out.move_cursor(row+@y,col+@x)
  end

  def each_match(str,match)
    start = 0
    sl = match.length
    while i = str.index(match,start)
      start = i + sl
      yield(i ... start)
    end
  end

  def render_marks line, y
    line = line.dup
    s = @editor.search
    return line if !s || s.empty?
    m = @editor.mark

    each_match(line, s) do |r|
      c = m && m.row == y && m.col == r.first
      line.set_attr(r, MATCH_ATTRS[c])
    end
    line
  end

  def adjust_xoff(w)
    @xoff ||= 0
    while @editor.cursor.col-@xoff > w
      @xoff += 10
    end

    while @editor.cursor.col-@xoff < 0
      @xoff -= 10
    end

    if @xoff < 0
      @xoff = 0
    end
  end

  # FIXME
  # Using index would probably be better/faster.
  #
  #
  def update_line(y,line=nil)
    if !line
      line = AnsiTerm::String.new(buffer.lines(y))
    end

    pos = 0
    max = line.length
    col = 0
    nline = AnsiTerm::String.new
    while (pos < max)
      ch = line.char_at(pos)
      if ch == "\t"
        t = 4-(col%4)
        nline << TABS[4-t]
        col += t
      else
        nline << line[pos]
        col+= 1
      end
      pos+= 1
    end

    nline
  end

  # FIXME: Much to gain here by rendering a margin on either side, and only
  # updating if "lines" are dirty.
  def mode_render(r)
    lines = buffer.lines(r)

    @viewcache   ||= Hash.new { "" }
    @rendercache ||= Hash.new { AnsiTerm::String.new }

    if @viewcache[r] != lines
      @editor.mode.reset! if @editor.mode.respond_to?(:reset!)
      @viewcache[r]   = lines
      @rendercache[r] = @editor.mode ? @editor.mode.call(lines.join("\n")).split("\n").map{|l| AnsiTerm::String.new(l) } : lines
    end

    @rendercache[r].enum_for(:zip, lines, r)
  end

  def reset!
    @viewcache   = Hash.new { "" }
    @rendercache = Hash.new { AnsiTerm::String.new }
  end

  def render
    update_top

    h  = height
    w  = width
    tw = text_width

    adjust_xoff(tw)

    max = @top+h
    lf = @opts[:show_lineno] ? LINENO_FORMAT : " "

    @out.resize(w,h)
    @out.cls

    mode_render(@top...max).
    map {|line,orig,cnt| [update_line(cnt, line), orig,cnt]  }.
    map {|line,orig,cnt| [render_marks(line, cnt),orig,cnt]  }.
    map {|line,orig,cnt| [line[@xoff..tw+@xoff],  orig, cnt] }.
    map {|line,orig,cnt|
      orig ||= ""
      end_marker =  orig.length-@xoff > tw ? CUTOFF_MARKER : ""
      "#{lf % (cnt+1)}#{line}#{end_marker}#{ANSI.el}"
    }.
    zip((0..Float::INFINITY).lazy).each do |line,y|
      move(0,y)
      @out.print(line)
    end

    render_status
    flush
  end

  def flush
    STDOUT.print "\e[?25l" # Hide cursor
    STDOUT.print(@out.to_s)
    @top  ||= 0
    @xoff ||= 0
    # FIXME
    # Figure out where current x position in line actually is on screen
    #
    y = (cursor.row||0)
    ANSI.move_cursor(y-@top,
      editor.model.cursor_x(y, cursor.col-@xoff)+text_xoff)
    STDOUT.print "\e[?25h" # Show cursor
  end

  def reset_screen
    @cache = {}
    flush
  end

end
