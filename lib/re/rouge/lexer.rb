#
# Monkey-patching Rouge
#

module Rouge
  class Lexer
    def serialize
      nil
    end

    def deserialize(state)
      nil
    end
  end

  class RegexLexer < Lexer
    def serialize
      stack.map { |s| s.name }[1..-1] # elide the root state
    end

    def deserialize(states)
      @stack = [get_state(:root)]
      states.each do |s|
        @stack << get_state(s)
      end
    end
  end
end
