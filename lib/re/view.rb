require_relative 'viewmodel'
require_relative 'termbuffer'

class View
  attr_reader :editor, :opts

  def initialize(editor)
    @editor = editor
    @top    = 0

    @x = 0
    @y = 0

    # If 0 or negative, relative to console width/height
    @w = 0
    @h = 0

    @out = TermBuffer.new(width, height)
    @rendercache = {} #@FIXME Need LRU

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
    @opts[:show_lineno] ? LINENO_LEN : 0
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

    pos = "(%d,%d)" % [cursor.col, cursor.row]
    mode = (@editor.mode || "text").to_s
    status = " #{pos} #{mode} "
    status = status[0..w-1] if status.length >= w

    @out.move_cursor(w-status.length-1,0)
    print "#{ANSI.sgr(40,37)}#{status}#{ANSI.sgr(49,37,:bold)}"
    msg = @editor.message[0.. w-2].strip
    @out.move_cursor(w-msg.size-1,h-1)
    print ANSI.sgr(:normal)+ANSI.sgr(37,45)+msg
    @editor.message = ""
    status.size
 end

  def render_line(str)
    if out = @rendercache[str.hash]
      return out
    end
    if @editor.mode && @editor.mode.respond_to?(:call)
      line = @editor.mode.call(str)
    else
      line = str
    end
    @rendercache[str.hash]=line
    line
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

  CUTOFF_MARKER = ANSI.sgr(33) {"\u25b8"}
  EOL_MARKER    = ANSI.sgr(30,49,:bold){"\u25c2"}
  LINENO_FORMAT = "#{ANSI.sgr(40,32,1)}%3d#{ANSI.sgr(30){"\u2502"}}#{ANSI.sgr(0,49,39)} "
  LINENO_LEN = 5
  WBUF = 3 # Extra space for marks etc.
  TABCHAR = "\u2504"
  TAB = ANSI.sgr(30,:bold) { TABCHAR*3 + "\u2578" }

  def render_marks line, y
    s = @editor.search
    return line if !s || s.empty?

    start = 0
    n = ""
    m = @editor.mark

    while i = line.index(s, start)
      n << "\e[0m"
      n << (line[start .. i-1] || "")
      if m && m.row == y && m.col == i
        n << "\e[32;45;4m#{s}"
      else
        n << "\e[32;44m#{s}"
      end
      start = i + s.length
    end
    n << "\e[0m"
    n << (line[start .. -1] || "")

    AnsiTerm::String.new(n)
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

  def update_line(y,line=nil)
    line ||= buffer.lines(y)
    line = line.gsub("\t", TABCHAR*4)
    @viewlines[y] = line
    line
  end

  def render
    update_top
    #clear_screen
    h = height
    w = width
    tw = text_width

    adjust_xoff(tw)

    max = @top+h
    y = 0
    @viewlines = []
    @out.resize(w,h)
    @out.cls

    lf = @opts[:show_lineno] ? LINENO_FORMAT : ""
    Array(buffer.lines(@top...max)).each_with_index do |line,cnt|
      line = update_line(@top+cnt, line)
      #line = buffer.lines(@top+cnt)
      line = line.gsub("\t", TAB)
      line = AnsiTerm::String.new(render_line(line))
      line = render_marks(line, @top+y)

      if line.length-@xoff > tw
        line = line[@xoff..tw+@xoff]
        end_marker =  CUTOFF_MARKER
      else
        line = (line[@xoff..-1]||"")
        end_marker = EOL_MARKER unless line.length == 0
      end

      if @opts[:show_lineno]
        line = "#{lf}%s#{end_marker}#{ANSI.el}" % [@top+cnt, line.to_str]
      else
        line = "#{line.to_str}#{end_marker}#{ANSI.el}"
      end

      move(0,y)
      @out.print(line)

      y+=1
    end
    render_status
    flush
  end

  def flush
    STDOUT.print "\e[?25l" # Hide cursor
    STDOUT.print(@out.to_s)
    @top  ||= 0
    @xoff ||= 0
    ANSI.move_cursor((cursor.row||0)-@top,cursor.col+text_xoff-@xoff)
    STDOUT.print "\e[?25h" # Show cursor
  end

  def reset_screen
    @cache = {}
    flush
  end

end
