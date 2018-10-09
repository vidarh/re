# # MarkdownSyntax #
#
# This wraps the Rouge Markdown lexer and adds a few additional
# capabilities (if you'reviewing this with RE, you'll see them
# rendered properly:
#
#  * (A),(B),(C),(D),(E),(Q) -- coloured; I use these for my TODO
#    lists, specifying priority or (Q)uick.
#  * Headings using one or more "#" are rendered more nicely.
#  * @WORD rendered in purple. E.g. @FOO or @BAR
#  * A certain set of words are implicitly treated as @word:
#    FIXME, TBC, TBD, TODO
#    (TODO: Differentiate colours?)
#  * @3am or @03:10 rendered with white text on purple background to
#    stand out.
#  * +WORD I use this for tagging things I want to stand out particulaly
#    strongly.
#  * Mark something **DONE** and the rest of the line uses strikeout
#  * Embedded code blocks (currently quite buggy) 
#
# ```ruby
# def foo bar
# end
# ```
#
# ~~~ruby
#     def foo bar
#     end
# ~~~
#
# FIXME Adding "~"+"~"+"~" anywhere on the line breaks things, and it doesn't
# properly terminae the inline code mode. Or we'd demonstrate c mode 
# here:
#
# void foo(int blah) {
#   if (a == c) {
#   }
# }
# ~~~
#
#    (Any Rouge supported language should work here^^^)
#
#  * Indented code blocks:
#     This is indented code
#  * (Since I use this mostly for Ruby, I've cheekily for now defaulted
#    to Ruby if no language is specified)
#  * Unless the code starts with "$ " or "# " which is often used
#    for shell example:
#     $ ls 
#     # Root!
#
# There's lots of bugs here... Also note this Markdown renderer is
# used for comment blocks by the Ruby comment renderer only so far.
# Intend to generalize it for other comment blocks. The comment renderer
# expects one extra space after '#', and =begin/=end blocks are not
# currently supported.
#
# * FIXME Decouple the lexing and formatting / theme
# * FIXME Wrapped text changes bakground text to black/transparent even
#    when in a block comment.
# * FIXME Re's end-of-line marker should occur at the end of the "real"
#    line, not the re-formatted line
# * FIXME Text goes white after (A) etc.:
#    foo
#   (A)foo 
# * **DONE** "Special" syntax like @word breaks within code blocks. e.g:
#     foo @bar
# * **DONE** FIXME Underline using *underline* should not continue to end of line
# * **DONE** FIXME Strikethrough should not continue to striketrough for trailing
#   space on the line
# * FIXME auto-indenting in comment block
# * FIXME auto-insert '#' on new line in comment block
#
class MarkdownSyntax < Highlighter
  def to_s; "Markdown"; end

  @@lexer = Rouge::Lexers::Markdown.new
  @@formatter = Rouge::Formatters::Terminal256.new(Rouge::Themes::ThankfulEyes.new)

  PRI = {
    "A" => fg(1)+"(A)",
    "B" => fg(1,:B)+"(B)"+ANSI.sgr(0),
    "C" => fg(3)+"(C)",
    "D" => fg(2)+"(D)",
    "E" => fg(2)+"(E)",
    "Q" => fg(4)+"(Q)"
  }

  def strikethrough
    "\e[9m"
  end

  def is_heading(t)
    t.qualname == "Generic.Heading" ||
      t.qualname == "Generic.Subheading"
  end

  def heading_level str
    str.match(/\A#+/)[0].length rescue 0
  end

  def handle_heading(t,r)
    return r if !is_heading(t)
    level = heading_level(r)
    r = r.gsub("#","\u25B0")

    case level
    when 1
      fg(7,:bold)+bg(4)+r
    when 2
      fg(1)+r
    when 4
      fg(2)+r
    else
      r
    end
  end

  def call(str)
    lex = @@lexer.lex(str)
    strike = false
    lex = lex.collect do |t,r|

      if strike
        r = strikethrough + r
      end

      if r[0..7] == "**DONE**"
        strike = true
      end


      if m = r.split(/(\([A-Z]\))/)
        r = m.collect do |s|
          if s.length == 3 && s[0] == "(" && s[2] == ")" && PRI[s[1]]
            "#{PRI[s[1]]}\e[39m"
          else
            s
          end
        end.join
      end 

      # FIXME
      # To handle this properly
      # we need to keep track of state during rendering, and reset it when
      # rendering from the beginning.
      # Also need to be prepared to "backtrack"
      #
      if r.match(/(~~~|```)( *)([a-zA-Z\-]*)( *)/)
        @codeformatter = Modes.find_fancy($3)
        r = "\e[48;2;16;64;16;30m#{$1}#{$2}\e[39m#{$3}#{$4}"
      else
        if !@codeformatter && r[0..3] == "    "
          if r[4..5] == "$ " || r[4..5] == "# "
            codeformatter = Modes.find_fancy("shell")
            code = codeformatter.call(r[6..-1])
            r = "    \e[48;2;64;10;64m#{r[4..5]}"+code
          else
            codeformatter = RubyHighlighter.new
            code = codeformatter.call(r[4..-1])
            r = "    \e[48;2;64;10;64m"+code
          end
        elsif @codeformatter
          if r.length < 64 
            r += " " * (64 - r.length)
          end
          code = @codeformatter.call(r)
          r = "\e[48;2;64;10;64m"+code
        else
          # NOT CODE
          r = handle_heading(t,r)
          r = wrap_match(/(\@[a-zA-Z]+)/, fg("5"), r)
          r = wrap_match(/(FIXME|TBC|TBD|TODO)/, fg("5"), r)
          r = wrap_match(/(\@[0-9:]+[a|p]?m?)/, fg("7")+bg("5"), r)
          r = wrap_match(/(\+[a-zA-Z]+)/, fg("0")+bg("3"), r)
        end
      end
      [t,r]
    end

    format(lex)
  end
end
