# coing: utf-8
require_relative 'viewmodel'
require_relative 'moderender'
require 'ansiterm'

#
# # View #
#
# This mess handles the rendering. It's a wonder it can keep up with
# the required performance at all. Lots of low hanging fruit to speed it# up:
#
#  * Don't re-check the options and re-generate the colour attributes
#    so many times.
#  * Cache the rouge-feedback better.
#  * Avoid the expensive attribute merging where possible.
#  * Support \e]11;color\a to set background colour.
#  * Scroll using VT100 sequences where possible
#
# But start by refactoring so it's reasonable to benchmark
#
class View
  attr_reader :editor, :opts, :xoff, :w, :h
  attr_accessor :top

  # # Settings #
  #
  # FIXME: Extrat settings (and unify formats)
  #
  CUTOFF_MARKER     = ANSI.sgr(33) {"\u25b8"}
  MAX_LENGTH_MARKER = ANSI.sgr(33) {"\u25bf"}
  EOL_MARKER        = nil #ANSI.sgr(30,49,:bold){"\u25c2"}
  EOF_MARKER = '' #ANSI.sgr(40,32) {"<EOF>"}
  GUTTER = [16,16,32]

  TABCHAR = "\u2504"
  TAB = AnsiTerm::String.new(ANSI.sgr(38,2,80,40,40)+TABCHAR*4).freeze

  MATCH_ATTRS = {
    true => AnsiTerm.attr(
      fgcol: 32,
      bgcol: 45,
      flags: AnsiTerm::Attr::UNDERLINE
    ),
    false => AnsiTerm::Attr.new(
      fgcol: 32,
      bgcol: 44,
      flags: nil
    )
  }.freeze

  CHSTYLE = {
    true  => AnsiTerm.attr(fgcol: 34, flags: AnsiTerm::Attr::BOLD | AnsiTerm::Attr::UNDERLINE),
    false => AnsiTerm.attr(fgcol: 33, flags: AnsiTerm::Attr::UNDERLINE)
  }

  # FIXME: Maybe make this match on word boundaries?
  # FIXME: Leverage this for matching current token
  OTHER_MATCHES = { 'NOTE' => CHSTYLE[true]}

  # Pre-creating to avoid passing it through the ANSI parser every time.
  PAD=AnsiTerm::String.new("\e[48m"+' '*200)
  BGRESET = AnsiTerm::Attr.new(flags: 0, bgcol: 49, fgcol: 39)

  LINENO_LEN = 6
  WBUF = 2 # Extra space for marks etc.


  TABS = [
    TAB[0..3].freeze,
    TAB[0..2].freeze,
    TAB[0..1].freeze,
    TAB[0..0].freeze
  ].freeze


  def fg(r,g,b); ANSI.sgr(38,2,r,g,b); end
  def bg(r,g,b); ANSI.sgr(48,2,r,g,b); end

  # FIXME: Make this validate
  def hexcol(c)
    return nil if !c
    return nil if c[0] != ?#
    if c.match(/#rgba\((\d)+,(\d)+,(\d)+,.*\)/)
      [$1.to_i,$2.to_i,$3.to_i]
    else
      [c[1..2].to_i(16),c[3..4].to_i(16),c[5..6].to_i(16)]
    end
  end

  def get_style_option(conf, option, default: nil)
    t = @editor&.mode&.theme&.other_styles rescue nil
    if t
      style = t[conf]
      if style
        if value = style[option]
          pval = @editor&.mode&.theme.palette[value]
          value = pval if pval
          return value
        end
      end
    end
    return default
  end

  # FIXME: This doesn't handle files 10000 lines and above.
  def lineno_format(curline=false)
    t = @editor&.mode&.theme&.other_styles rescue nil

    fgcol = hexcol(get_style_option('line-numbers', :fg, default: '#4080e0'))
    bgcol = hexcol(get_style_option('line-numbers', :bg, default: '#0c0c28'))

    if curline
      fgcol = fgcol.map{|c| (c*1.5).clamp(0,255)}
      bgcol = bgcol.map{|c| (c*3).clamp(0,255)}
    end
    bgdark = bgcol.map{|c| c/1.5}

    "#{fg(*fgcol)+bg(*bgcol)+ANSI.sgr(1)}%4d#{fg(*bgcol)+bg(*bgdark)}\u258B#{ANSI.sgr(0,49,39)} "
  end

  def initialize(editor)
    @editor = editor
    @top    = 0

    @x = 0
    @y = 0

    # If 0 or negative, relative to console width/height
    @w = 0
    @h = 0

    @out = AnsiTerm::Buffer.new(width, height)

    @opts = {
      show_lineno: true,
      highlight: true
    }

    @moderender = ModeRender.new
    reset!
  end

  def buffer; @editor.buffer; end
  def cursor; @editor.cursor; end

  # FIXME: Should ask the TermBuffer about this.
  def winsize; IO.console.winsize end

  def width; @w > 0 ? @w : winsize[1]+@w; end
  def height; @h > 0 ? @h : winsize[0]+@h; end
  def text_xoff; (@opts[:show_lineno] || @opts[:left_margin]) ? LINENO_LEN : 1; end
  def text_width; width - WBUF - text_xoff; end
  def print *args; @out.print(*args); end
  def max_line_length; @opts[:max_line_length]; end

  def render_status
    h,w = winsize

    if max_line_length
      off = @opts[:show_lineno] || @opts[:left_margin] ? 4 : 0
      @out.move_cursor(off+max_line_length+2,1)
      print MAX_LENGTH_MARKER
    end

    pos = '(%d,%d)' % [cursor.col, cursor.row + 1]
    mode = (@editor.mode || 'text').to_s
    status = "#{@editor.ctrl && @editor.ctrl.lastcmd} #{pos} #{mode} "
    status = status[0..w-1] if status.length >= w

    #@out.move_cursor(w-status.length-1,0)
    @out.move_cursor(0,0)
    start = ' Re2'
    pl = (w-status.length-start.length)
    pad = pl > 0 ? ' '*pl : ''
    print "#{ANSI.sgr(48,2,40,40,80,37)}#{start}#{pad}#{status}#{ANSI.sgr(49,37,:bold)}"

    msg = @editor.message[0..w-5]
    if msg.length > 0
      @out.move_cursor(w-msg.size,h-1) #w-msg.size-2,h-1)
      print ANSI.sgr(:normal)+ANSI.sgr(37,45)+msg
    end

    @editor.message = ''
    status.size
  end

  def update_top
    return if !cursor
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

  def move(row,col); @out.move_cursor(col+@x, row+@y); end

  def each_specific_match(str, match)
    start = 0
    sl = match.length
    r = Search.safe_regexp(match)
    while i = str.index(r,start)
      start = i + sl
      yield(i .. start-1, match)
    end
  end

  def each_match(str)
    OTHER_MATCHES.keys.each do |k|
      each_specific_match(str,k) { |r| yield(r, k) }
    end

    if @editor.search && !@editor.search.empty?
      each_specific_match(str,@editor.search) do |r|
        yield(r, @editor.search)
      end
    end
  end

  def match_attrs(current, string)
    return MATCH_ATTRS[current] if string == @editor.search

    m = OTHER_MATCHES[string]
    if m.is_a?(Hash)
      return m[current]
    else
      return m
    end
  end

  def render_marks line, y
#    line = line.dup
    m = @editor.mark || @editor.cursor

    each_match(line) do |r, str|
      c = !m.nil? && m.row == y && m.col == r.first
      a = match_attrs(c, str)
      line.set_attr(r, a) if a
    end
    line
  end

  def adjust_xoff(w)
    @xoff ||= 0
    return if !cursor
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
  # FIXME: Migrate to viewmodel
  def update_line(y,line=nil)
    if !line
      line = AnsiTerm::String.new(buffer.lines(y))
    end
    if !line.is_a?(AnsiTerm::String)
      line = AnsiTerm::String.new(line.to_s)
    end

    if line.index("\t").nil?
      return line
    end

    pos = 0
    max = line.length
    col = 0
    nline = AnsiTerm::String.new
    first = true
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

  # Must be called if the mode or buffer changes.
  def reset!
    @bg = hexcol(@opts[:background_color]) ||
    hexcol(get_style_option('text', :bg)) ||
    hexcol(get_style_option('background-pattern', :bg))

    # Attributes affected by mode changes
    @gutter_attr = AnsiTerm::Attr.new(flags: 0, bgcol: [
      48,2,*(adjust_color(@bg, 0.8) || GUTTER)])

    @cursor_attr = AnsiTerm::Attr.new(
      bgcol: [48,2,*hexcol(get_style_option('cursor', :bg, default: '#802080'))],
      fgcol: [38,2,*hexcol(get_style_option('cursor', :fg, default: '#ffffff'))],
      flags: nil
    )

    if @bg
      @bgcol_attr = AnsiTerm::Attr.new(bgcol: [48,2, *@bg])
    end

    @moderender.mode   = @editor.mode
    @moderender.buffer = @editor.buffer
    @moderender.reset!
  end

  # Pads the line with the background up to tw characters
  def pad(line, l, tw)
    c = tw - l + 1
    if c > 0
      line << PAD[0..c]
    end
  end

  def render_gutter(line)
    # FIXME: This is *merging*. Shound separate set/merge
    # since set can be much faster
    if m = max_line_length
      line.set_attr(m+2..-1, @gutter_attr)
    end
  end

  def render
    return if !buffer
    update_top

    h  = height
    w  = width
    tw = text_width

    adjust_xoff(tw)

    max = [@top+h-1, buffer.lines_count + 1].min

    if @opts[:show_lineno]
      lf = lineno_format
      clf = lineno_format(true)
    elsif @opts[:left_margin]
      lf = clf = AnsiTerm::String.new('      ')
      lf.set_attr(0..-2, @gutter_attr)
    else
      lf = clf = AnsiTerm::String.new(' ')
      lf.set_attr(0..0, BGRESET)
    end

    # Ensure the buffer size matches the terminal
    # If the dimensions change, the cache is invalidated by this.
    @out.resize(w,h)

    # This clears the term *buffer* not the actual screen.
    @out.cls

    @moderender.mode = opts[:highlight] ? @editor.mode : nil
    @moderender.render(@top...max).
    map do |line,orig,cnt|

      move(cnt-@top+1,0)
      if opts[:show_lineno]
        if cnt == cursor.row
          print(AnsiTerm::String.new(clf % (cnt+1)))
        else
          print(AnsiTerm::String.new(lf % (cnt.to_i+1)))
        end
      else
        print(lf)
      end

      line = EOF_MARKER if line.nil?

      # FIXME, this is not accurate for padded comment blocks
      line << EOL_MARKER if EOL_MARKER

      line = update_line(cnt, line) if line
      line = render_marks(line, cnt)

      # Truncate line
      line = line[@xoff..tw+@xoff] || AnsiTerm::String.new

      if line.length <= tw
        l = line.length
        pad(line, l, tw)

        # FIXME: This is ugly. Should be a more efficient way
        # of setting default next attribute.
        max = max_line_length ? max_line_length + 1 : tw
        line.set_attr(l..max, BGRESET)
      end

      if orig.to_s.length-@xoff > tw
        line << CUTOFF_MARKER
      end

      render_gutter(line)

      @out.print(line)
    end

    render_background
    render_curline_highlight
    render_cursor
    render_status
    flush
  end

  def adjust_color(col, factor)
    return nil if col.nil?
    newcol = col.map {|c| c = (c * factor).to_i; c > 255 ? 255 : c }
  end

  def render_background
    if @bgcol_attr
      @out.lines.each do |line|
        line&.merge_attr_below(0..-1, @bgcol_attr)
      end
    end
  end

  def render_curline_highlight
    #@out.move_cursor(40,0)
    #@out.print("== #{text_width} ==")

    lfw = text_xoff-1
    max = max_line_length ? max_line_length : text_width
    # Mark current line
    # FIXME: Might be better to simply set this directly on the TermBuffer
    bg = hexcol(get_style_option('current-line', :bg)) #|| [0,0,96]
    return if !bg
    curlinecol = AnsiTerm::Attr.new(bgcol: [48,2, *bg])
    #curlinecol = AnsiTerm::Attr.new(bgcol: [48,2, 0xff,0xff,0xff])
    # `#merge_attr_below` prevents "overwriting" other background colours
    # vs. `#set_attr`. Downside is that it doesn't "highlight" colours like
    # this. Might want to consider a setting to "blend" colours.
    l = @out.lines[cursor.row-@top+1]
    if l
      # FIXME: This is only needed here because I've disabled
      # padding elsewhere. Revisit.
      l.set_attr(lfw..lfw+max+1, curlinecol)
    end
    #@out.move_cursor(lfw+max,cursor.row-@top)
    #@out.print("X")
  end

  # Draw fake cursor (we turn off the real cursor to prevent flickering,
  # you get reasonable results by turning it off when rendering and then on
  # again, so maybe add an option)
  def render_cursor
    # This is necessary to handle characters that render
    # as more or less than 1 character, such as e.g. tabs.
    y = cursor.row
    x = editor.model.cursor_x(y, cursor.col-@xoff)+text_xoff

    # Make cursor visible even if currently no character
    # FIXME: Update AnsiTerm w/function to allow forcing a space
    # w/out this
    l = @out.lines[cursor.row-@top+1]
    if !l || !l[x]
      @out.move_cursor(x,cursor.row-@top+1)
      @out.print(' ')
    end
    l = @out.lines[cursor.row-@top+1]
    l.set_attr(x..x, @cursor_attr)
  end

  def flush
    buf = @out.to_s
    #$editor&.log("view: #{buf.size}")
    STDOUT.print(buf)
    @top  ||= 0
    @xoff ||= 0
  end

  def reset_screen
    reset!
    @out.reset
    flush
  end
end
