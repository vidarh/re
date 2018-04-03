
INDENT=2

$ilex = Rouge::Lexers::Ruby.new
$block_start = Set[*%w{if else elsif while class def rescue begin do}]

def is_block_start(fp)
  return false if !fp
  return false if !fp[0].name == :Keyword
  return $block_start.member?(fp[1])
end

# FIXME: This is Ruby specific
def calc_indent(pos, prev, cur)
  prev = $ilex.lex(prev).to_a
  while fp = prev.shift
    break if fp[0].name != :Text
  end
  lp = prev.last
  if is_block_start(fp)
    pos += INDENT
  elsif lp && (lp[1] == "{" || lp[1] == "|" || lp[1] == "do")
    #prev[-1] == "{" || prev[-1] == "|"
    pos += INDENT
  end
  if cur.match(/^[ \t]*(end|else|elsif|rescue|\})([ \t]+.+)?/)
    pos -= INDENT
  end
  pos = 0 if pos < 0
  return pos
end
