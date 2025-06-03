#
# # Search/Find support
#
#
module Search
  # FIXME: Refine. Point here is to handle
  # an "in progress" regexp and fall back to the raw string.
  # So e.g. a user typing 'foo\' and then 'foo\w' will
  # end up searching for 'foo' then 'foo\w' instead of getting an
  # error when typing the backslash.
  def self.safe_regexp(str)
    # Regexp.new(str,'i') rescue Regexp.new(str[0..-2],'i')
    Regexp.new(Regexp.escape(str), 'i')
  rescue
    str
  end

  def mark!; @mark = cursor; end

  def find_forward
    row = cursor.row
    col = cursor.col
    max = buffer.lines_count
    r = Search.safe_regexp(@search)
    while (row < max) && (line = buffer.lines(row))
      if i = line.index(r, col)
        move(row, i)
        mark!
        return true
      end
      row += 1
      col = 0
    end
    false
  end

  def find_next
    right
    if find_forward
      true
    else
      buffer_home
      mark!
      false
    end
  end

  def find(str = nil)
    @search = str || @search || ''

    update = -> do
      render
      # FIXME: Render the expected cursor.
      prompt("\e[0mFind: #{@search}\e[42m \e[m")
    end

    update.call
    mark!

    @ctrl.raw do
      # FIXME: is there a Ruby readline which
      # 1) lets you trap keys
      # 2) leaves rendering and keyboard input
      #    entirely in your hands?
      loop do
        cmd, char = @ctrl.handle_input
        case cmd
        when :ctrl_c, :esc
          @search = ''
          @message = 'Search terminated.'
          break
        when :backspace
          @search.slice!(-1)
          find_forward
        when :enter
          @message = 'Search paused. To cont. press ^f; To cancel ^f + ^c'
          break
        when :ctrl_k
          @search = ''
        when :ctrl_f
          if !find_next
            @message = 'Wrapped around; ^f to restart search'
            break
          end
        when :char
          if char =~ /\A[[:print:]]+\Z/
            @search += char
            find_forward
          end
          # else
          #  @message = [cmd, *char].inspect
        end
        update.call
      end
    end
  end
end
