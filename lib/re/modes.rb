require 'reality/gitattributes'
require_relative 'markdownsyntax'

# # RougeMode #
#
# We use Rogue for most syntax highlighting unless there's a very good
# reason not to.
#
class RougeMode
  attr_reader :lexer, :formatter

  def to_s
    @lexer.tag
  end

  def theme=(theme)
    @themename = theme
    @theme = Rouge::Theme.find(theme).new
    @formatter = nil
  end

  def formatter
    @formatter ||= ReFormatter.new(@theme)
  end

  def initialize(lexer,theme = "thankful_eyes")
    @lexer = lexer
    if !lexer.is_a?(Rouge::LayeredLexer)
      @lexer = Rouge::LayeredLexer.new(
        {
          lexer: @lexer,
          sublexers: {"Text" => SpecialLexer.new}
        }
      )
    end

    self.theme = theme
  end

  def format(l)
    formatter.format(l||"")
#  rescue Exception => e
#    "ERROR: #{e.inspect}"
  end

  # FIXME: Making this callable is misleading
  # as there's not just a single reasonable
  # default operation
  def call(str)
    format(@lexer.lex(str||""))
  end

  def should_insert_prefix(c,prev)
    return nil if @lexer.tag != "ruby"
    return nil if !prev || prev[c] != '#'
    return '#'
  end
end

# FIXME: Unify / generalize this and MyRuby
class MyMarkdown < Rouge::LayeredLexer
  attr_reader :lexer

  @@md = Rouge::Lexer.find("markdown")
  @@sp = SpecialLexer.new

  def initialize(opts = {})
    super(opts.merge({
            lexer: @@md.new,
            sublexers: {"Text" => @@sp}
    }))
  end

  tag 'markdown'
  aliases(*@@md.aliases)
  filenames(*@@md.filenames)
end

class MyRuby < Rouge::LayeredLexer
  @@rb = Rouge::Lexer.find("ruby")
  @@sp = SpecialLexer.new
  @@md = Rouge::Lexer.find("markdown")

  def initialize(opts = {})
    @mf = ReFormatter.new(Rouge::Themes::ThankfulEyes.new)
    @md = @@md.new

    super({
      lexer: @@rb.new,
      sublexers: {"Text" => @@sp}
    })

    md = @md
    mf = @mf
    l = lambda do |t,text|
      data = text.match(/([^#]*)#( ?)(.*)/) || ["",nil,"",text]
      tail = AnsiTerm::String.new(data[2]+
        String.new(mf.format(
          md.continue_lex(data[3]+"\n")).
            gsub("\n",""))
      )
      str  = data[1] ? "#{data[1]}\e[0;34m\u2503" : ""
      if tail.length < 71
        tail << " "*(71-tail.length)
      end
      tail.merge_attr_below(0..tail.length, AnsiTerm::Attr.new(bgcol: "48;2;10;10;32"))

      [t,(str+tail.to_str)]
    end

    self.register_sublexer("Comment.Single", l)
    self.register_sublexer("Comment.Multiline", l)
  end

  def self.detect?(text)
    return true if text.shebang? 'ruby'
  end

  tag 'ruby'
  aliases(*@@rb.aliases)
  filenames(*@@rb.filenames)
end


class BufferList
  def to_s
    "buffer-list"
  end

  def call str
    "Buffer List!"
  end
end

class Modes
  def self.choose_by_gitattributes(filename)
    return nil if !filename
    path = filename
    while path != "/" &&
      !File.exists?(path+"/.git")

      if File.exists?(path+"/.gitattributes")
        attrpath ||= path+"/.gitattributes"
      end
      path = File.dirname(path)
    end

    if File.exists?(path+"/.git/info/attributes")
      attrpath = path+"/.git/info/attributes"
      relpath  = path
    end

    attributes = Reality::Git::Attributes.parse(path,
      attrpath,
      relpath
    )

    relpath ||= path

    if attributes && attrs = attributes.attributes(filename.gsub(/\a{relpath}/,""))
      lang = attrs["language"] || attrs["gitlab-language"]
    end

    choose_by_string(lang)
  end

  def self.choose_by_string(lang)
    if lang
      Rouge::Lexer.find(lang)
    else
      nil
    end
  end

  def self.choose(filename: nil, source:, language: nil)
    rl = choose_by_string(language)
    rl ||= choose_by_gitattributes(filename)
    rl ||= Rouge::Lexer.guess({ filename: filename, source: source.join("\n")})
    return rl ? RougeMode.new(rl) : nil
  end
end
