require 'reality/gitattributes'
require_relative 'rouge/special'

# # RougeMode #
#
# We use Rogue for most syntax highlighting unless there's a very good
# reason not to.
#
class RougeMode
  attr_reader :lexer, :formatter, :theme

  DEFAULT_THEME = Rouge::Theme.find('thankful_eyes').new

  def to_s
    @lexer.tag
  end

  def theme=(theme)
    @theme = Rouge::Theme.find(theme)&.new if theme.is_a?(String)
    @theme ||= DEFAULT_THEME
    @themename = @theme&.name
    @formatter = nil
  end

  def formatter
    @formatter ||= ReFormatter.new(@theme)
  end

  def initialize(lexer, theme = 'thankful_eyes')
    @lexer = lexer.is_a?(Class) ? lexer.new : lexer
    if !lexer.is_a?(Rouge::LayeredLexer)
      @lexer = Rouge::LayeredLexer.new(
        {
          lexer: @lexer,
          sublexers: { 'Text' => SpecialLexer.new }
        }
      )
    end

    self.theme = theme
  end

  def format(l)
    formatter.format(l || '')
    #  rescue Exception => e
    #    "ERROR: #{e.inspect}"
  end

  # FIXME: Making this callable is misleading
  # as there's not just a single reasonable
  # default operation
  def call(str)
    format(@lexer.continue_lex(str || '')) # + @lexer.serialize.inspect)
  end

  def serialize
    @lexer.serialize
  end

  def deserialize(states)
    @lexer.deserialize(states)
  rescue
    []
  end

  def should_insert_prefix(c, prev)
    case @lexer.tag
    when 'ruby'
      return '#' if prev[c] == '#'
    when 'markdown'
      return '* ' if prev[c - 1..c + 1] == ' * '
      return '* ' if c == 0 && prev[0..1] == '* '
    end
    return nil
  end
end

require_relative 'rouge/markdown'
# require_relative 'rouge/mymarkdown'
require_relative 'rouge/ruby'
require_relative 'rouge/myruby'

class BufferList
  def to_s
    'buffer-list'
  end

  def call str
    'Buffer List!'
  end
end

class Modes
  def self.choose_by_gitattributes(filename)
    return nil if !filename

    path = filename
    while path != '/' && path != '.'
      !File.exist?(path + '/.git')

      if File.exist?(path + '/.gitattributes')
        attrpath ||= path + '/.gitattributes'
      end
      path = File.dirname(path)
    end

    if File.exist?(path + '/.git/info/attributes')
      attrpath = path + '/.git/info/attributes'
      relpath  = path
    end

    attributes = Reality::Git::Attributes.parse(path,
                                                attrpath,
                                                relpath)

    relpath ||= path

    if attributes && attrs = attributes.attributes(filename.gsub(/\a{relpath}/, ''))
      lang = attrs['language'] || attrs['gitlab-language']
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
    rl ||= Rouge::Lexer.guess({ filename: filename, source: source.join("\n") })
    return rl ? RougeMode.new(rl) : nil
  end
end
