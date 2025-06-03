
require "rouge"
require "re/rouge/ruby"
require "re/rouge/layered_lexer"


class TestLexer < Rouge::RegexLexer
  state :root do
    rule /NotAllowed/, Error
    rule /./, Text
  end
end

RSpec.describe Rouge::LayeredLexer do

  let (:ruby_lexer) { Rouge::Lexer.find("ruby").new }
  let (:c_lexer)    { Rouge::Lexer.find("c").new }

  let (:error_lexer) {
    Rouge::LayeredLexer.new(
      {
        lexer: ruby_lexer,
        sublexers: {"Name.Class" => TestLexer.new }
      }
    )
  }

  let (:error_program) {
    program = <<-END
      class NotAllowedButRestIs < Foo
        def foo
          NotAllowed.cant_be_used
        end
      end
    END
  }

  it "calls into the provided sub-lexer for a given token class and rewrites tokens" do
    # First let's check it *doesn't* do this with the normal ruby lexer
    lex = ruby_lexer.lex(error_program).to_a
    expect(lex[3]).to eq([Rouge::Token::Tokens::Name::Class, "NotAllowedButRestIs"])

    lex = error_lexer.lex(error_program).to_a
    expect(lex[3]).to eq([Rouge::Token::Tokens::Error, "NotAllowed"])
    expect(lex[4]).to eq([Rouge::Token::Tokens::Text, "ButRestIs "])
  end

  let(:crossline_lexer) { ruby_lexer
    Rouge::LayeredLexer.new(
      {
        lexer: ruby_lexer,
        sublexers: {"Comment.Multiline" => TestLexer.new }
      }
    )
  }

=begin
This is a multline comment
(A) (B) (C)
=end
"This is a string start

string still here Class Name "

  let(:crossline_program) {
    program = <<-END
    Foo
    =begin
     MultiLine comment
     We expect NotAllowed to get picked up as an Error
    =end
    Bar
    END
    program.split("\n").map(&:strip).join("\n")
  }

  it "can be called line by line and the sub lexer will remain active across lines" do

    # Check the normal lexer
    expect(ruby_lexer.lex(crossline_program).to_a[2][0]).to eq(Rouge::Token::Tokens::Comment::Multiline)

    program = crossline_program.split("\n")

    # Check the normal lexer w/lines split
    lexer = ruby_lexer
    lex = program.map do |line|
      lexer.continue_lex(line).to_a
    end
    expect(lex[1][0][0]).to eq(Rouge::Token::Tokens::Comment::Multiline)
    expect(lex[2][0][0]).to eq(Rouge::Token::Tokens::Comment::Multiline)
    expect(lex[3][0][0]).to eq(Rouge::Token::Tokens::Comment::Multiline)
    expect(lex[4][0][0]).to eq(Rouge::Token::Tokens::Comment::Multiline)

    # Check the layered lexer w/lines split
    lexer = crossline_lexer
    lex = program.map do |line|
      lexer.continue_lex(line).to_a
    end
    expect(lex[1][0][0]).to eq(Rouge::Token::Tokens::Text)
    expect(lex[2][0][0]).to eq(Rouge::Token::Tokens::Text)
    expect(lex[3][0][0]).to eq(Rouge::Token::Tokens::Text)
    expect(lex[3][1][0]).to eq(Rouge::Token::Tokens::Error)
    expect(lex[3][1][1]).to eq("NotAllowed")
    expect(lex[3][2][0]).to eq(Rouge::Token::Tokens::Text)
    expect(lex[4][0][0]).to eq(Rouge::Token::Tokens::Text)
  end
end
