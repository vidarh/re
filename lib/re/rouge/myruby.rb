
require_relative 'layered_lexer'
require_relative 'mymarkdown'
require_relative 'sexp_lexer'

class CommentLexer < Rouge::Lexer
  def initialize(opts)
    super(opts)
    @ttype = opts[:token_type]
    @mf = ReFormatter.new(Rouge::Themes::ThankfulEyes.new)
    @md = MyMarkdown.new
  end

  def stream_tokens(text)
    data = text.match(/([^#]*)#( ?)(.*)/) || ["",nil,"",text]
    tail = AnsiTerm::String.new(data[2]+
    String.new(@mf.format(
      @md.continue_lex(data[3]+"\n")).
      gsub("\n",""))
    )
    str  = data[1] ? "#{data[1]}\e[0;34m\u2503" : ""
    if tail.length < 71
      tail << " "*(71-tail.length)
    end
    tail.merge_attr_below(0..tail.length, AnsiTerm::Attr.new(bgcol: "48;2;10;10;32"))

    yield @ttype,(str+tail.to_str)
  end

  def stack
    []
  end
end

class MyRuby < Rouge::LayeredLexer
  @@rb = Rouge::Lexer.find("ruby")
  @@sp = SpecialLexer.new
  @@sexp = SexpLexer.new

  def initialize(opts = {})
    super({
      lexer: @@rb.new,
      sublexers: {
        "Text" => @@sp,
# Uh oh, something causes this to badly break things
#        "Literal.String.Other" => @@sexp,
        "Comment.Single" => CommentLexer.new(token_type: Rouge::Token::Tokens::Comment::Single),
        "Comment.Multiline" => CommentLexer.new(token_type: Rouge::Token::Tokens::Comment::Multiline)
      }
    })
  end

  def self.detect?(text)
    return true if text.shebang? 'ruby'
  end

  tag 'ruby'
  aliases(*@@rb.aliases)
  filenames(*@@rb.filenames)
end
