$uri="drbunix:#{ENV["HOME"]}/.re"

class Buffer
  include DRb::DRbUndumped
  include DRb::DRbObservable
end

class Editor
  include DRb::DRbUndumped
end

class TermBuffer
  include DRb::DRbUndumped
end

require 'json'

class Factory
  def initialize
    @bufstore = File.expand_path("~/.re-buffers")
    @m = Mutex.new

    puts "Loading buffers from #{@bufstore}"

    begin
      File.open(@bufstore,"r") do |f|
        @buffers = JSON.load(f)
      end
    rescue Exception => e
      p e
    end

    @buffers.each_with_index do |buf,id|
      buf.buffer_id = id
    end

    @buffers ||= []
  end

  attr_reader :buffers

  def find_buffer(buf)
    b   = @buffers[buf] if buf.is_a?(Fixnum)
    b ||= @buffers.compact.find {|b| b.name == buf }
    b
  end

  # FIXME: Warn if not saved
  def kill_buffer(buf)
    # FIXME: Is this a problem? Don't want to mess up
    # buffer ids.
    if @buffers[buf]
      @buffers[buf] = nil
    else
      raise RuntimeError.new("No such buffer '#{buf}'")
    end
  end

  def new_buffer(buf, str, created_at = 0)
    b = find_buffer(buf)

    if !b
      b = Buffer.new(@buffers.count,buf,str, created_at)
      @buffers << b
    end

    return b
  end

  def list_buffers
    @buffers.compact.collect{|buf|
      [buf.buffer_id, buf.name].join(" ")
    }.join("\n")
  end

  def store_buffers
    puts "Storing buffers"

    FileWriter.write(@bufstore,JSON.generate(buffers.compact.map(&:as_json)))
    puts "Stored."
  end
end
