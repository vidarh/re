# # ViewModel
#
# The model that represents the actual file data is Buffer
#
# However, the model may not pecisely reflect how the data
# should be presented. The most basic example is that
# tab characters are represented as a variable number of
# characters on screen.
#
# The ViewModel's job is to be an intermediary, translating
# operations on the *visible* part of the buffer into operations
# on the Buffer.
#
# This includes cursor movement and editing operations.
#
# Currently the ViewModel is very crude, as most operations
# still bypasses it and goes directly to the Buffer.
#
# The ViewModel will also act as an intermediary to do a first
# pass parse of the lines to be displayed.
#
class ViewModel
  TABCHAR = "\u2504"

  def initialize editor
    @editor = editor
  end

  def buffer
    @editor.buffer
  end

  def row
    @editor.cursor.row
  end

  def cursor_x(row,col)
    return 0 if col < 1
    l = @editor.buffer.lines(row)
    pos = 0
    (0..(col-1)).each do |i|
      if l[i].to_s == "\t"
        @editor.message = i.to_s
        pos += 4-(pos % 4)
      else
        pos += 1
      end
    end
    return pos
  end

  def right(offset = 1)
    old = @editor.cursor
    c = old.col
    r = old.row
    l = @editor.view.update_line(r)
    return old if !l
    if l[c].to_s == TABCHAR
      c += 1
      max = c + (4 - c % 4)
      while l[c].to_s == TABCHAR and c <= max
        c += 1
      end
      return Cursor.new(r,c)
    else
      if c >= l.length
        return old if r+1 >= buffer.lines_count
        Cursor.new(r+1,0)
      else
        return Cursor.new(r,c+offset)
      end
    end
  end

  def left(offset = 1)
    c = @editor.cursor
    col = c.col
    row = c.row

    l = @editor.view.update_line(row)
    if col > 0
      col -= 1
      min = col - col % 4
      while col > min and l[col].to_s == TABCHAR
        col -= 1
      end
      return Cursor.new(row, col)
    end

    return c if row == 0
    Cursor.new(row - 1, buffer.line_length(row - 1))
  end
end
