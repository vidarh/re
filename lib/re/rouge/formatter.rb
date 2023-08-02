
class ReFormatter < Rouge::Formatters::Terminal256
  def is_heading(t)
    t.qualname == "Generic.Heading" ||
    t.qualname == "Generic.Subheading"
  end

  def heading_level str
    str.match(/\A#+/)[0].length rescue 0
  end

  def rewrite_token(tok,val)
    if is_heading(tok)
      val = val.gsub("#","\u25B0")
    elsif tok.qualname == "Punctuation" && (val == "```" || val == "~~~")
      #val = "\u256D\u2500\u2500"
      #val = "\u2570\u2500\u2500"
      val = "\u2550"*3
    end
    val
  end

  def stream(tokens, &b)
    tokens.each do |tok, val|
      escape = escape_sequence(tok,val)
      yield escape.style_string
      val = rewrite_token(tok,val)
      yield val.gsub("\n", "#{escape.reset_string}\n#{escape.style_string}")
      yield escape.reset_string
    end
  end

  def self.style(h)
    Rouge::Theme::Style.new(nil,h)
  end

  HEADER_OVERRIDES = {
    1 => style(fg: "#e5e5e5", bold: true, bg: "#0000ee"),
    2 => style(fg: "#cd0000"),
    4 => style(fg: "#00cd00")
  }

  PRI_OVERRIDES = {
    "A" => style(fg: "#cd0000", bold: true),
    "B" => style(fg: "#ee8040", bold: true),
    "C" => style(fg: "#cdcd00", bold: true),
    "D" => style(fg: "#40cd00", bold: true),
    "E" => style(fg: "#00ee00", bold: true),
    "Q" => style(fg: "#0000ee", bold: true)
  }

  TAG_OVERRIDE     = style(bg: "#eeee00", fg: "#000000")
  TIME_OVERRIDE    = style(bg: "#ee00cd", fg: "#ffffff")
  SPECIAL_OVERRIDE = style(fg: "#ee00cd")
  CODE_OVERRIDE    = style(fg: "#ee00cd")

  # @FIXME:
  # Push this up the chain... Really should propose extension to allow
  # further subdivision of tokens.
  #
  def escape_sequence(token,val)
    style = get_style(token)
    name = token.qualname

    if is_heading(token)
      level = heading_level(val)
      name += "|#{level}"
      style = HEADER_OVERRIDES[level] || style
    elsif token.qualname == "Comment.Special"
      case val[0].chr
      when '('
        style = PRI_OVERRIDES[val[1]] || style
        name += "|pri|#{val[1]}"
      when '+'
        name += "|tag|#{val[1]}"
        style = TAG_OVERRIDE
      else
        if ('0'..'9').member?(val[1])
          name += "|time"
          style = TIME_OVERRIDE
        else
          style = SPECIAL_OVERRIDE
        end
      end
    elsif token.qualname == "Punctuation" && (val == "~~~" || val == "```")
      name += "|code"
      style = CODE_OVERRIDE
    end

    @escape_sequences ||= {}
    @escape_sequences[name] ||=
    EscapeSequence.new(style)
  end
end
