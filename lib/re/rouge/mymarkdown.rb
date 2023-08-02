require_relative 'special'

# FIXME: Unify / generalize this and MyRuby
class MyMarkdown < Rouge::LayeredLexer
  attr_reader :lexer

  @@md = Rouge::Lexer.find("markdown")
  @@sp = SpecialLexer.new

  def initialize(opts = {})
    super(opts.merge({
            lexer: @@md.new,
            sublexers: {"Text" => @@sp}
            })
          )
  end

  tag 'markdown'
  aliases(*@@md.aliases)
  filenames(*@@md.filenames)
end


