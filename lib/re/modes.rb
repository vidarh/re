# = Foo
#
#
class Highlighter
  def wrap_match(pat, code, line)
    m = line.split(pat)
    Array(m).each_slice(2).collect do |text, tok|
      [text, code, tok, "\e[39;49m"]
    end.flatten.compact.join
  end

  def self.fg(col,bold=false)
    "\e[3#{col}#{bold ?";1":""}m"
  end
  def self.bg(col, bold=false)
    "\e[4#{col}#{bold ?";1":""}m"
  end

  def normal; "\e[39;49m"; end
  def bg(col,bold=false); self.class.bg(col,bold); end
  def fg(col,bold=false); self.class.fg(col,bold); end


  FORMATTER = Rouge::Formatters::Terminal256.new(Rouge::Themes::ThankfulEyes.new)

  def format(lex)
    FORMATTER.format(lex)
  end

end

class RougeMode < Highlighter
  def to_s 
    @lexer.name.split("::")[-1]
  end

  def initialize(lexer)
    @lexer = lexer
  end

  def call(str)
    format(@lexer.lex(str))
  end
end

class RubyHighlighter < Highlighter
  @@lexer = Rouge::Lexers::Ruby.new

  def to_s; "Ruby"; end

  def call(str)
    lex = @@lexer.lex(str).collect do |t,text|
      [t,text]
    end
    # Highlight whitespace only lines
    if lex.length == 1 && lex[0][1].strip.empty?
      lex[0][1] = "\e[41m#{lex[0][1]}\e[0m"
    end

    format(lex)
  end
end

# FIXME: Decouple the lexing and formatting / theme
class MarkdownSyntax < Highlighter
  def to_s; "Markdown"; end

  @@lexer = Rouge::Lexers::Markdown.new
  @@formatter = Rouge::Formatters::Terminal256.new(Rouge::Themes::ThankfulEyes.new)

  PRI = {
    "A" => fg(1)+"(A)",
    "B" => fg(1,:B)+"(B)",
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
      bg(4)+fg(7,:bold)+r
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

      r = handle_heading(t,r)

      if r[0..1] == "**"
        strike = true
      end

      if m = r.split(/(\([A-Z]\))/)
        r = m.collect do |s|
          if s.length == 3 && s[0] == "(" && s[2] == ")" && PRI[s[1]]
            "#{PRI[s[1]]}\e[0m"
          else
            s
          end
        end.join
      end

      r = wrap_match(/(\@[a-zA-Z]+)/, fg("5"), r)
      r = wrap_match(/(\@[0-9:]+[a|p]?m?)/, fg("7")+bg("5"), r)
      r = wrap_match(/(\+[a-zA-Z]+)/, fg("0")+bg("3"), r)

      [t,r]
    end

    format(lex)
  end
end

class BufferList
  def to_s
    "buffer-list"
  end

  def call str
    "Buffer List!"
  end
end

# FIXME: This should defer the mode selection to Rouge as much a possible
class Modes

  @@alist_interpreters = {
    "/usr/bin/ruby" => RubyHighlighter.new,
    "/bin/sh"   => "Shell"
  }

  @@alist_ext = {
    ".md" => MarkdownSyntax.new,
    ".rb" => RubyHighlighter.new,
    "Gemfile" => RubyHighlighter.new
  }

  def self.choose(filename: nil, first_line:)

    mode = nil
    first_line ||= ""
    if m = first_line.match(/\-\*\- *mode: *([^ \t]*) *\-\*\-/)
      mode = @@alist_mode[m[1]]
    end
    if !mode
      if m = first_line.match(/^\#\!((\/[a-zA-Z0-9]+)+)$/)
        mode = @@alist_interpreters[m[1]]
      end
    end
    if filename
      mode   = @@alist_ext[File.extname(filename)] ||
               @@alist_ext[File.basename(filename)]
    end

    if !mode
      rl = Rouge::Lexer.guess({ filename: filename,
                                source: first_line})
      if rl
        mode = RougeMode.new(rl)
      end
    end

    return mode
  end
end
