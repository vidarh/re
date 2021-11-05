$uri="drbunix:#{ENV["HOME"]}/.re"

class Buffer
  include DRb::DRbUndumped
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
    @buffers ||= []
  end

  attr_reader :buffers

  def new_buffer(buf, str, created_at = 0)
    b   = @buffers[buf] if buf.is_a?(Fixnum)
    b ||= @buffers.find {|b| b.name == buf }

    if !b
      b = Buffer.new(@buffers.count,buf,str, created_at)
      @buffers << b
    end

    return b
  end

  def list_buffers
    @buffers.collect{|buf|
      [buf.buffer_id, buf.name].join(" ")
    }.join("\n")
  end

  def store_buffers
    puts "Storing buffers"
    FileWriter.write(@bufstore,JSON.generate(buffers.map(&:as_json)))
    puts "Stored."
  end
end
