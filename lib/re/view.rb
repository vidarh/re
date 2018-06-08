class View
  attr_reader :buffer

  def initialize(editor)
    @editor = editor
    @top    = 0

    @x = 0
    @y = 0

    # If 0 or negative, relative to console width/height
    @w = 0
    @h = -2
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

  def height
    @h > 0 ? @h : winsize[0]+@h
  end

  def render_status
    h,w = winsize
    ANSI.move_cursor(h-2,0)

    status = " "*200
    pos = "col %03d, line %0d / top=#{@top}" % [cursor.col, cursor.row]
    lastchar = @editor.lastchar.inspect
    status[3 .. 3+pos.length] = pos
    status[30 .. 30+lastchar.length] = lastchar
    #message = @editor.message
    #status[40 .. 40+message.length] = message

    mode = (@editor.mode || "text").to_s
    status[60 .. 60+mode.length] = mode

    status = status[0..w-1] if status.length >= w
    print "#{ANSI.sgr(47,30)}#{status}#{ANSI.sgr(49,37,:bold)}"
    print ANSI.sgr(:normal)+(@editor.message[0.. w-2]+" ")+ANSI.el
  end

  def render_line(str)
    if @editor.mode && @editor.mode.respond_to?(:call)
      @editor.mode.call(str)
    else
      str
    end
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
    while cursor.row >= @top+h
      @top += 1
    end
    if cursor.row < @top
      @top = cursor.row
    end
  end

  def move(row,col)
    ANSI.move_cursor(row+@y,col+@x)
  end

  CUTOFF_MARKER = ANSI.sgr(33) {"\u25b8"}
  EOL_MARKER    = ANSI.sgr(30,:bold){"\u25c2"}
  LINENO_FORMAT = "#{ANSI.sgr(40,32,1)}%3d#{ANSI.sgr(30){"\u2502"}}"

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

  def render
    update_top
    #clear_screen
    h = height
    w = width

    @xoff ||= 0
    while @editor.cursor.col-@xoff > w-8
      @xoff += 10
    end

    while @editor.cursor.col-@xoff < 0
      @xoff -= 10
    end

    if @xoff < 0
      @xoff = 0
    end

    max = @top+h
    y = 0
    Array(buffer.lines(@top...max)).each_with_index do |line,cnt|
      line = line.gsub("\t", "...")

      line = AnsiTerm::String.new(render_line(line))
      line = render_marks(line, @top+y)

      if line.length-@xoff > w - 8
        line = line[@xoff..w-8+@xoff]
        end_marker =  CUTOFF_MARKER
      else
        line = (line[@xoff..-1]||"")
        end_marker = EOL_MARKER unless line.length == 0
      end

      line = "#{LINENO_FORMAT} %s#{end_marker}#{ANSI.el}" % [@top+cnt, line.to_str]

      print "\e[?25l" # hide cursor
      if @x > 0
        move(y,-1)
        print "\u2502"
      else
        move(y,0)
      end

      print line

      if @w < 0
        move(y,width)
        print "|"
      end

      y+=1
    end

    while y < h
      move(y,0)
      print " "*w
      y += 1
    end

    render_status
    render_cursor
    print "\e[?25h"
  end

  def render_cursor
    move(cursor.row-@top,cursor.col+5-@xoff)
  end

  def reset_screen
    @cache = {}
    print ANSI.cls
  end

end
