class Cursor
  attr_reader :row, :col

  def initialize(row = 0, col = 0)
    @row = row
    @col = col
  end

  def up(buffer, offset = 1)
    Cursor.new(row - offset, col).clamp(buffer)
  end

  def down(buffer, offset = 1)
    Cursor.new(row + offset, col).clamp(buffer)
  end

  def move(buffer, row, col)
    Cursor.new(row, col).clamp(buffer)
  end

  def right(buffer, offset = 1)
    buffer.right(self,offset)
    #return Cursor.new(row, col + offset).clamp(buffer) unless end_of_line?(buffer)
    #return self if final_line?(buffer)
    #Cursor.new(row + 1, 0)
  end

  def clamp(buffer)
    @row = row.clamp(0, buffer.lines_count - 1)
    if !buffer.lines(row)
      @col = 0
    else
      @col = col.clamp(0, buffer.line_length(row))
    end
    self
  end

  def enter(buffer)
    down(buffer).line_home
  end

  def line_home
    Cursor.new(row, 0)
  end

  def line_end(buffer)
    Cursor.new(row, buffer.line_length(row))
  end

  def end_of_line?(buffer)
    if buffer.lines(row)
      col == buffer.line_length(row)
    else
      true
    end
  end

  def final_line?(buffer)
    row == buffer.lines_count - 1
  end

  def end_of_file?(buffer)
    final_line?(buffer) && end_of_line?(buffer)
  end

  def beginning_of_file?
    row == 0 && col == 0
  end
end
