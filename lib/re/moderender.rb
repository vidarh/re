#
# # Render ranges of text lines
#
# Goals:
# * Caching happens on server.
# * Background thread does re-render for major changes.
# * Client-side re-render either might not be needed at all(?)
#   or only happens for individual lines.
# * This should be independent of the editor, and extracted
#   (with modes and themes) as its own gem
#
# Current:
# * Caching happens in client
# * Background thread is triggered on buffer reload or ^L.
# * Caching is buggy.
#
# Cache hierarchy:
# * @viewcache holds the raw text lines. If line == @viewcache[lineno],
#   then the line has not changed
# * @rendercache holds rendered ANSI views of the line.
# * @statecache holds a serialized version of the Rouge internal
#   state, allowing re-rendering on a line by line basis (TBC:
#   whether to keep it for every line or in chunks)
#
class ModeRender
  attr_accessor :mode, :buffer

  def initialize debug=nil
    @debug = debug
    reset!
  end

  def reset!
    @viewcache   = Hash.new { '' }
    @rendercache = Hash.new { AnsiTerm::String.new }
    @statecache ||= Hash.new { {} }
  end

  def mode_render(i,l)
    @rendercache[i] = @mode.call(l) rescue l
  end

  def dirty?(i,l)
    @viewcache[i] != l
  end

  def cached(i)
    @rendercache[i]
  end

  # FIXME: Instead of doing this on line by line
  # basis, do it by block, and use state cache.
  # Must update state cache until they matches what was
  # there previously.
  #
  def render_line(i, l)
    return l if @mode.nil? || l.nil?
    return cached(i).dup if !dirty?(i,l)

    num = 0
    oi = i
    while l && num < 10
      # FIXME: This is not safe alongside render_all
      if i > 0 && @statecache[i-1]
        @mode.deserialize(@statecache[i-1])
      end

      mode_render(i,l)
      @viewcache[i] = l

      si = @statecache[i]
      s = @mode.serialize
      if s == si
        break
      else
        @statecache[i] = si
        i+=1
        # FIXME: This is *very* slow; should operate
        # on the range currently being rendered,
        # and only call @buffer.lines() if outside that
        # range.
        l = num.to_i #@lines[i-@r.first] || @buffer.lines(i)
      end
      num += 1
    end
    @rendercache[oi].dup
  end

  # FIXME: Want to run this server-side.
  #
  # If maxy is set, trigger a refresh once
  # when the rendering has gone past maxy.
  #
  def render_all(maxy=nil)
    return if !@mode

    refresh = true
    Thread.new do
      buffer.lines(0..-1).each_with_index do |l,i|
        @viewcache[i] = l
        mode_render(i,l)
        @statecache[i]  = @mode&.serialize

        # Prevent the main thread from freezing
        # slowing to a crawl
        Thread.pass

        if maxy && i > maxy && refresh
          # FIXME: This is currently non-functional.
          # Use observable
          @editor&.refresh
          refresh = false
        end
      end
    end
  end

  def render(r)
    @lines = @buffer.lines(r)
    @r = r

    if @rendercache.empty?
      render_all(r.last)
    end

    r.map do |i|
      l = @lines[i-r.first] || nil
      [render_line(i, l), l, i]
    end
  end
end
