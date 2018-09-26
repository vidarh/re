# # Highlighter #
#
# Very basic old/deprecated support for highlighting code.
# The newer modes uses Rouge under the hood instead.
#
#
class Highlighter
  def wrap_match(pat, code, line)
    m = line.split(pat)
    Array(m).each_slice(2).collect do |text, tok|
      !tok ? 
      [text] :
      [text, code, tok, normal]
    end.flatten.compact.join
  end

  def self.fg(col,bold=false)
    "\e[3#{col}#{bold ?";1":""}m"
  end
  def self.bg(col, bold=false)
    "\e[4#{col}#{bold ?";1":""}m"
  end

  def normal; "\e[39;49m"; end
  def bg(col,bold=false); self.class.bg(col,bold); end
  def fg(col,bold=false); self.class.fg(col,bold); end


  FORMATTER = Rouge::Formatters::Terminal256.new(Rouge::Themes::ThankfulEyes.new)

  def format(lex)
    FORMATTER.format(lex)
  end

end
