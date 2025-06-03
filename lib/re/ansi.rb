module ANSI
  @@sgr = {
    reset: 0,
    normal: 0,
    bold: 1
  }

  def self.csi(code, *n)
    "\e[#{n.collect(&:to_i).join(";")}#{code.to_s}"
  end

  def self.sgr(*n)
    n = n.collect { |c| (c.is_a?(Symbol) ? @@sgr[c] : nil) || c }
    if block_given?
      csi('m', *n) + yield + csi('m', 0)
    else
      csi('m', *n)
    end
  end

  def self.cup(row, col)
    csi('H', row + 1, col + 1)
  end

  def self.ed n = 0
    csi('J', n)
  end

  def self.el n = 0
    csi('K', n)
  end

  def self.cls
    ed(2)
  end

  def self.clear_screen
    STDOUT.print ANSI.cls
  end

  def self.move_cursor(row, col)
    STDOUT.print cup(row, col)
  end
end
