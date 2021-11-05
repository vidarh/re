class OpLog
  @@log = nil

  def log
    @@log ||= File.open(File.expand_path("~/.oplog-#{Process.pid}.txt"),"w")
  end

  def initialize(ob)
    @ob, @name = ob, (ob.respond_to?(:name) ? ob.name : ob.inspect)
  end

  def method_missing(*args,&block)
    log.puts(@name+"| "+args.inspect)
    @ob.send(*args,&block)
  end
end
