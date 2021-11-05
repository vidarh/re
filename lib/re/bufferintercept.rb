# Temporary hack to replace DRB

class BufferIntercept
  @@log = nil

  def log
    @@log ||= File.open(File.expand_path("~/.re-oplog-#{Process.pid}.txt"),"w")
  end

  def initialize(buffer)
    @buffer = buffer
    @name   = buffer.name
  end

  def method_missing(*args,&block)
    log.puts(@name+"| "+args.inspect)
    log.flush
    @buffer.send(*args,&block)
  end
end
