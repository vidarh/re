# frozen_string_literal: true

module Rouge
  # @abstract
  # A stateful lexer that allows you to register lexer to apply
  # to specific types of tokens returned from the main lexer.
  #
  # Example use (transforms trailing whitespace on a line to `Error` tokens):
  # 
  # ```ruby
  # class TrailingWhitespaceLexer < Rouge::RegexLexer
  #   state :root do
  #     rule /\s+\n/, Error
  #     rule /./, Text
  #   end
  # end
  #
  # lexer = LayeredLexer.new(
  #  {lexer: Lexer.find("ruby").new,
  #   sublexers: {"Text" => TrailingWhitespaceLexer.new)}
  #  }
  # )
  # lexer.lex("def foo   \nend\n")
  # ```

  class LayeredLexer < Lexer
    option :lexer,     "Main lexer"
    option :sublexers, "Hash of token qualnames to sub-lexers"

    def initialize(opts = {})
      @lexer =     opts.delete(:lexer)
      @sublexers = opts.delete(:sublexers) { {} }
      @cur_lexer = nil
      super(opts)
    end

    def register_sublexer(qualname,b)
      @sublexers[qualname] = b
    end

    def deserialize(state)
      state.each do |k,v|
        if k == :_cur_lexer
          @cur_lexer = v
        elsif k == :_lexer
          @lexer.deserialize(v)
        else
          @sublexers[k]&.deserialize(v)
        end
      end
    end

    def reset!
      @cur_lexer = nil
      @lexer.reset! if @lexer.respond_to?(:reset!) # FIXME: Probably a bug
      @sublexers.values.each do |sl|
        sl.reset! if sl.respond_to?(:reset!)
      end
    end

    def serialize
      m = {}
      if @cur_lexer
        m[:_cur_lexer] = @cur_lexer
      end
      m[:_lexer] = @lexer.serialize
      @sublexers.each do |k,v|
        s = v.serialize
        if !s.empty?
          m[k] = s
        end
      end
      m
    end

    def stream_tokens(str,&b)
      @lexer.lex(str,continue: true) do |tok,val|
        if sl = @sublexers[@cur_lexer || tok.qualname]
          if sl.respond_to?(:lex)
            sl.lex(val, continue: !@cur_lexer.nil?) do |t,v|
              b.call(t,v)
            end
            if sl.stack.size > 1
              @cur_lexer ||= tok.qualname
            else
              @cur_lexer = nil
            end
          else
            b.call(*sl.call(tok,val))
          end
        else
          b.call(tok,val)
        end
        nil
      end
    end
  end
end
