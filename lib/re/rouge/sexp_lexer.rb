#
# @FIXME: The naming here tramples all over lisps, which is
# fine for me personally since I don't use Lisp, but less suitable
# for a general release.
#
# Inheriting the Ruby lexer as we reuse a bunch of string states.
# Relying on '%s(' occurring near the start of the file to recognise
# to avoid matching on filename extension, as I use '.l' for my
# compiler which matches lisps because that gets reasonable syntax
# highlighting elsewhere.
#
class SexpLexer < Rouge::RegexLexer
  title 'Sexp'
  desc "S-expressions as used by vidarh's Ruby compiler"
  tag 'vhsexp'

  def self.detect?(text)
    return true if text =~ /%s\(/
  end

  #start do
  #  push :sexpmain
  #end

  state :root do
    rule /\%s/, Operator, :sexpmain #, :sexpmain
  end

  state :sexpbuiltin do
    rule /(malloc|calloc|printf|__ralloc|__array)\b/, Name::Builtin
    rule /(if|return|assign|while|index|bindex|defun|defm|do|let|callm|call|lambda|sexp|required|rest|class|module)\b/, Keyword
    rule /(eq|lt|le|gt|ge|ne|add|sub|mul|mod|div)\b/, Operator
    rule /[ \t]+/, Text
  end

  state :sexpmain do
    rule /#.*$/, Comment::Single
    rule /\(/, Punctuation, :sexpmain
    rule /\)/, Punctuation, :pop!

    mixin :sexpbuiltin
    rule /([A-Z][_a-zA-Z]*[!?=]?)/, Name::Class
    rule /<<|\[\]=|\[\]|===?|!=|\+|-|<=?|>=?|\*|\/|\%|!/, Operator
    rule /([\._a-z][_a-zA-Z0-9]*[!?=]?)/, Name::Variable
    rule /(@@?[_a-zA-Z]+)/, Name::Variable::Instance
    rule /(-?[0-9]+)/, Num::Integer
    mixin :strings
  end


  # From the Ruby lexer:
  state :strings do
    rule /'(\\\\|\\'|[^'])*'/, Str::Single
    rule /"(\\\\|\\"|[^"])*"/, Str::Double
  end
end
