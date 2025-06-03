#
# Try to detect a filename or URL under the cursor, taking
# into account heuristics such as <url>, schemes, "bare"
# domain names (very limited), Markdown [text](url) etc.
#

require 'uri'

# FIXME: Separate this out of Re. This file should not
# have dependencies on Re.
#
def detect_file_or_url(line, col)

  # *First* we try to rely on URI's very extensive
  # regex:
  start = line.rindex(URI.regexp(["https", "http", "mailto", "ftp"]), col)

  start = line.rindex(/[<)(\[']/, col) if !start
  start = line.rindex(/www\./, col) if !start

  return if !start

  if line[start] == "["
    start = line.index("](")
    return if !start
    start += 1
  end

  if line[start] == "<" || line[start] == "("
    start += 1
  end

  stop = line.index(/[>)' \t]/, start)
  stop = line.length if !stop

  stop-=1
  fname = line[start..stop].split(":")
  if fname.length > 1
    if fname != "file"
      return fname.join(":"), :url
    end
    fname.shift
  end
  return nil if !fname || !fname.first
  return fname.first, :file
end

