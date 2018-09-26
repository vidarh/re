
require_relative 'highlighter'
require_relative 'markdownsyntax'

# # RougeMode #
#
# A very basic default renderer for anything that has a Rouge lexer
#
# This is too simplistic: We want to not have to lex an entire file at
# once. _Most_ of the time this works fine. The big challenge is 
# multiline blocks, such as inlined code, which require us to keep
# state. Ideally we'd probably wrap Rouge with a wrapper using callcc 
# or something to let it parse line by line, or we pass the entire page
# to Rouge in one go, and postprocess the full page that way. Needs
# testing
#
#
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
  @@markdown = MarkdownSyntax.new

  def to_s; "Ruby"; end

  def call(str)
    lex = @@lexer.lex(str).collect do |t,text|
      if t.qualname == "Comment.Single"
        data = text.match(/([^#]*)#( ?)(.*)/)
        tail = AnsiTerm::String.new("\e[37m"+data[2]+@@markdown.call(data[3]))
        str  = "#{data[1]}\e[0;34m\u2503"
        if tail.length < 71
          tail << " "*(71-tail.length)
        end
        tail.set_attr(0..tail.length-1, AnsiTerm::Attr.new(bgcol: "48;2;10;10;32"))
        [t,(str+tail.to_str)] #+AnsiTerm::String.new("\e[37m\e[49m\u2503").to_str)]
      else
        [t,text]
      end
    end
    # Highlight whitespace only lines
    if lex.length == 1 && lex[0][1].strip.empty?
      lex[0][1] = "\e[41m#{lex[0][1]}\e[0m"
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

  def self.find_fancy(name)
    case name.downcase
    when "ruby"
      return RubyHighlighter.new
    when "markdown"
      return MarkdownSyntax.new
    else
      l = Rouge::Lexer.find_fancy(name)
      l ? RougeMode.new(l) : nil
    end
  end

  def self.choose(filename: nil, first_line:)

    mode = nil
    first_line ||= ""
    #if m = first_line.match(/\-\*\- *mode: *([^ \t]*) *\-\*\-/)
    #  mode = @@alist_mode[m[1]]
    #  return mode if mode
    #end
    #if m = first_line.match(/^\#\!((\/[a-zA-Z0-9]+)+)$/)
    #  mode = @@alist_interpreters[m[1]]
    #  return mode if mode
    #end
    if filename
      mode   = @@alist_ext[File.extname(filename)] ||
               @@alist_ext[File.basename(filename)]
      return mode if mode
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
