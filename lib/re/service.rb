#
# Spawning and connecting to the DRb service
#

$uripath = "#{ENV["HOME"]}/.re"
$uri = "drbunix:#{$uripath}"

def connect_to_server = DRbObject.new_with_uri($uri)

def with_connection(local:)
  count = 1
  loop do
    begin
      $factory = f = local ? Factory.new : connect_to_server
      yield f
    rescue DRb::DRbConnError => e
      p e
      if count > 1
        if count > 20
          $stderr.puts 'Exiting'
          exit(1)
        end
        sleep(0.5)
        $stderr.puts "Failed to open connection to server. Trying to start (#{count})"
      end
      count += 1
      start_server(foreground: false)
    end
  end
end

def start_service
  $factory = Factory.new
  begin
    DRb.start_service($uri, $factory)
  rescue Errno::EADDRINUSE
    fname = $uripath
    begin
      UNIXSocket.new(fname)
      $stderr.puts "Another server is listening on #{fname}. Exiting"
      exit 1
    rescue Errno::ECONNREFUSED
      File.unlink(fname)
    end
    retry
  end

  $stderr.reopen $stdout

  Thread.abort_on_exception = true
  Thread.new do
    loop do
      sleep(60)
      $factory.store_buffers
    end
  end

  DRb.thread.join
end

def start_server(foreground: false)
  if !foreground
    pid = fork do
      IO.new(0).close
      IO.new(1).close
      IO.new(2).close

      $stdin.reopen('/dev/null', 'r')
      $stdout.reopen('/dev/null', 'a')
      $stderr.reopen('/dev/null', 'a')
      $stdin = STDIN
      $stdout = STDOUT
      $stderr = STDERR

      $0 = 're-server'
      start_service
    end
    Process.detach(pid)
  else
    start_service
  end
end
