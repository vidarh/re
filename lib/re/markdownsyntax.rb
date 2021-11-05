# # MarkdownSyntax #
#
# This wraps the Rouge Markdown lexer and adds a few additional
# capabilities (if you'reviewing this with RE, you'll see them
# rendered properly:
#
# * (A),(B),(C),(D),(E),(Q) -- coloured; I use these for my TODO
#    lists, specifying priority or (Q)uick.
# * Headings using one or more "#" are rendered more nicely.
# * @WORD rendered in purple. E.g. @FOO or @BAR
# * A certain set of words are implicitly treated as @word:
#    FIXME, TBC, TBD, TODO
#    (TODO: Differentiate colours?)
#  * @3am or @03:10 rendered with white text on purple background to
#    stand out.
#  * +WORD I use this for tagging things I want to stand out particulaly
#    strongly.
#  * Mark something **DONE** and the rest of the line uses strikeout
#  * "Quoted Strings" gets a different token.
#  * Github style code-blocks:
# 
# ```ruby
#     def foo bar
#     end
# ```
#
#    (Any Rouge supported language should work here^^^)
#
#  * Indented code blocks:
#     def foo; if x=="This is indented code"; end
#  * (Since I use this mostly for Ruby, I've cheekily for now defaulted
#    to Ruby if no language is specified)
#  * Unless the code starts with "$ " or "# " which is often used
#    for shell example:
#     $ ls -x -y /bin
#     # ls -l
#
# ##  FIXME: Currently not working:
#
#  * The comment renderer expects one extra space after '#',
#    and `=begin/=end` blocks are not currently supported properly
#  * Decouple the lexing and formatting / theme
#  * Strikethrough on "DONE"
#  * Auto-indenting in comment block
#
#
#

=begin

# This is a test
+FOO

This is a test

=end

require_relative 'formatter'
require 'rouge/layered_lexer'

class SpecialLexer < Rouge::RegexLexer
  def initialize
    @rl = Rouge::Lexer.find("ruby")
    @sh = Rouge::Lexer.find("shell")
  end

  state :string1 do
    rule /[^"]/, Literal::String
    rule /^\"/, Literal::String::Double # Don't pop if first character in line
    rule /\"/, Literal::String::Double, :pop! #punctuation for string
  end

  state :root do
    rule /\+[a-zA-Z]+/,         Comment::Special
    rule /\([ABCDEQ]\)/,        Comment::Special
    rule /FIXME|TBC|TBD|TODO/,  Comment::Special
    rule /@[a-zA-Z]+/,          Comment::Special
    rule /(\@[0-9:]+[a|p]?m?)/, Comment::Special

    rule /^[^\"]*\"$/, Literal::String
    rule /\"$/, Literal::String::Double # Don't start a string at the end of a line
    rule /\"/, Literal::String::Double, :string1 #punctuation for string

    rule /\s+\n/, Error

    rule /^(\s{4}+)([$#] )(.+)$/ do |m|
      token Text, m[1]
      token Punctuation, m[2]
      delegate @sh, m[3]
    end

    rule /^(\s{4}+)(.+)$/ do |m|
      token Text, m[1]
      delegate @rl, m[2]
    end

    rule /./, Text
  end

  #  def serialize
  #  {rl: @rl.serialize, sh: @sh.serialize}
  #end

  #def deserialize(states)
  #  @rl.deserialize(states[:rl])
  #  @sh.deserialize(states[:sh])
  #end 
end
