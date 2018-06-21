



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

  def set_buffer_contents(buffer, cursor,data, created_at = Time.now)
    buffer.created_at = created_at
    buffer.modify(cursor, 0..-1) do |_|
      lines_from_data(data)
    end
  end

  def reload(buffer,cursor)
    data = read_file_data(buffer.name)
    set_buffer_contents(buffer,cursor,data, Time.now)
  end

  def open(filename, data = "\n", created_at = Time.at(0))
    base = File.basename(filename)

    data = lines_from_data(data)  
    buffer = @server.new_buffer(filename, data, created_at)

    if base == "buffer-list"
      set_buffer_contents(buffer,Cursor.new(0,0), @server.list_buffers)
    end

    buffer
  end

end
