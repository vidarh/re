
class History
  def initialize
    @snapshots = []
    @current = -1
  end

  def save(data, advance = true)
    snapshots[@current+1] = data
    @current += 1 if advance
  end

  def can_undo?
    !undo_snapshot.nil?
  end

  def undo
    undo_snapshot.tap { @current -= 1 }
  end

  def can_redo?
    !redo_snapshot.nil?
  end

  def redo
    redo_snapshot.tap { @current += 1 }
  end

  def undo_snapshot
    snapshots[current] if current >= 0
  end

  private

  attr_reader :snapshots, :current

  def redo_snapshot
    snapshots[current + 2]
  end
end
