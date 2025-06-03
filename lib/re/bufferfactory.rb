class BufferFactory
  def initialize server
    @server = server
  end

  def lines_from_data(data)
    if data.empty?
      ['']
    else
      line_sep = data["\r\n"] || "\n"
      data.split(line_sep)
    end
  end

  def read_file_data(filename)
    if filename && File.exist?(filename)
      File.read(filename)
    else
      ''
    end
  end

  def set_buffer_contents(buffer, cursor, data, created_at = Time.now)
    # p [:replacing, buffer, created_at]
    buffer.created_at = created_at
    buffer.replace_contents(cursor, lines_from_data(data))
  end

  def reload(buffer, cursor)
    # p [:reloading, buffer]
    data = read_file_data(buffer.name)
    set_buffer_contents(buffer, cursor, data, DateTime.now)
  end

  def get_buffer(buf)
    @server.new_buffer(buf.to_i, '')
  end

  def open(filename, data = "\n", created_at = Time.at(0))
    base = File.basename(filename)

    data = lines_from_data(data)
    buffer = @server.new_buffer(filename, data, created_at)

    if base == 'buffer-list'
      set_buffer_contents(buffer, Cursor.new(0, 0), @server.list_buffers)
    end

    buffer
  end
end
