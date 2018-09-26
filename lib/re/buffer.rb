require 'drb/observer'

class Buffer

  include DRb::DRbObservable

  attr_reader :name, :buffer_id, :created_at
  attr_writer :created_at

  def initialize(id,name, lines, created_at = 0)
    @buffer_id   = id  # An id for this buffer unique for this session
    @name = name
    @history = History.new
    @lines   = lines
    @created_at = created_at.kind_of?(Numeric) ?  Time.at(created_at) : DateTime.parse(created_at) 
  end

  def as_json(options = { })
    {
      "json_class" => self.class.name,
      "data" => {
        "id"    => @buffer_id,
        "name"  => @name,
        "lines" => @lines,
        "created_at" => Time.at(created_at.to_i)
      }
    }
  end

  def to_json(*a)
    as_json.to_json(*a)
  end

  def self.json_create(o)
    d = o["data"]
    new(d["id"], d["name"], d["lines"], (d["created_at"] || d["modified_at"] || 0))
  end


  def lines_count
    @lines.size
  end

  def line_length(row)
    @lines[row]&.size || 0
  end

  def insert(cursor, char)
    modify(cursor, cursor.row) {|l| l.insert(cursor.col,char) }
  end

  def delete(cursor, from, to =nil)
    to ||= from
    modify(cursor, cursor.row) {|l| l[from..to] = ''; l }
  end

  def break_line(cursor)
    modify(cursor, cursor.row..cursor.row) do |l|
      [l[0][0...cursor.col], l[0][cursor.col..-1]]
    end
  end

  def join_lines(cursor,offset=0)
    row=cursor.row+offset
    modify(cursor, row..row+1) {|l| l.join }
  end

  def lines(r)
    @lines[r]
  end

  def can_undo?
    @history.can_undo?
  end

  def can_redo?
    @history.can_redo?
  end

  def undo(old_cursor)
    cursor, rowrange, rows = @history.undo_snapshot
    store_snapshot(old_cursor,rowrange, false)
    cursor, rowrange, rows = @history.undo
    @lines[rowrange] = rows
    cursor
  end

  def redo
    cursor, rowrange, rows = @history.redo
    @lines[rowrange] = rows
    cursor
  end

  def store_snapshot(cursor, rowrange, advance = true)
    @history.save([cursor, rowrange, @lines[rowrange]], advance)
  end

  def modify(cursor, rowrange)
    lines = @lines[rowrange].dup
    lines ||= ""
    new_lines = yield(lines)
    store_snapshot(cursor, rowrange, true)
    @lines[rowrange] = new_lines
    STDERR.puts "Notifying observers"
    changed
    p @observer_peers
    notify_observers(self)
  end
end
