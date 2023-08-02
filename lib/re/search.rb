#
# # Search/Find support
#
#
module Search

  def mark!; @mark = cursor; end

  def find_forward
    row = cursor.row
    col = cursor.col
    max = buffer.lines_count
    while (row < max) && (line = buffer.lines(row))
      if i = line[col .. -1].index(@search)
        move(row, col+i)
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
    @search = str || @search || ""

    update = -> do
      render
      # FIXME: Render the expected cursor.
      prompt("Find: #{@search}_")
    end

    update.call
    mark!

    @ctrl.raw do
      loop do
        cmd,char = @ctrl.handle_input
        case cmd
        when :ctrl_c, :esc
          @search = ""
          @message = "Search terminated."
          break
        when :backspace
          @search.slice!(-1)
          find_forward
        when :enter
          @message = "Search paused. To cont. press ^f; To cancel ^f + ^c"
          break
        when :ctrl_k
          @search = ""
        when :ctrl_f
          if !find_next
            @message = "Wrapped around; ^f to restart search"
            break
          end
        when :char
          if char =~ /\A[[:print:]]+\Z/
            @search += char
            find_forward
          end
        #else
        #  @message = [cmd, *char].inspect
        end
        update.call
      end
    end
  end

end
