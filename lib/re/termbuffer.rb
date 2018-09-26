
# # TermBuffer #
#
# A terminal buffer that will eventually handle ANSI style strings
# fully. For now it will handle the sequences AnsiTerm::String handles
# but e.g. cursor movement etc. needs to be explicitly handled.
#
class TermBuffer
  def initialize(w=80, h=25)
    @lines = []
    @x = 0
    @y = 0
    @w = w
    @h = h
    @cache = []
  end

  def cls
    @lines = (1..@h).map { nil } #AnsiTerm::String.new } #AnsiTerm::String.new("\e[37;40;0m"+(" "*@w)) }
  end

  def move_cursor(x,y)
    @x = x
    @y = y
    @x = @w-1 if @x >= @w
    @y = @y-1 if @y >= @h
  end

  def resize(w,h)
    @w, @h = w,h
    @cache = []
  end

  def scroll
    while @y >= @h
      @lines.shift
      @lines << nil #AnsiTerm::String.new #"" #AnsiTerm::String.new("\e[37;40;0m"+(" "*@w))
      @y -= 1
    end
    true
  end

  def print *args
    args.each do |str|
      @lines[@y] ||= AnsiTerm::String.new("\e[37;48;0m")
      @dirty << @y
      l = @lines[@y]

      if l.length < @x
        l << (" "*(@x - l.length))
      end
      l[@x..@x+str.length] = str
#      l[@x] << str
#      if @x + s.length > @w
#        l[@x .. @w-1] = s[0 .. @w - @x]
#        @x = 0
#        @y += 1
#        scroll if @y >= @h
#      end
    end
  end

  def to_s
    out = ""
    @lines.each_with_index do |line,y|
      line ||= ""
      l = line.length
      s = line.to_str
      if @cache[y] != s
        out << ANSI.cup(y,0) << s << ANSI.sgr(:reset) << ANSI.el #<< X\n"
        @cache[y] = s
      end
      #if l < @w
      #  out << " "*(@w-l)
      #end
    end
    @dirty = Set[]
    out
  end
end
