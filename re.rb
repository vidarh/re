#!/usr/bin/env ruby

# Bundler doesn't behave very well when
# the current working dir is "unexpected"
def bundler
    pwd = Dir.pwd
  begin
    Dir.chdir(File.dirname(__FILE__))
  rescue Errno::ENOENT
    #Dir.chdir(File.expand_path("~"))
  end
   require 'bundler'
   #require_relative 'vendor/bundle/bundler/setup'
   Bundler.require(:default)
   Dir.chdir(pwd)
end

bundler

require 'io/console'
require 'drb/drb'
require 'drb/unix'
require 'drb/observer'

require_relative 'lib/re/monkeys'
require_relative 'lib/re/ansi'
#require_relative 'lib/re/buffer'
require_relative 'lib/re/view'
#require_relative 'lib/re/cursor'
#require_relative 'lib/re/history'
require_relative 'lib/re/modes'
require_relative 'lib/re/indent'
require_relative 'lib/re/editor'
require_relative 'lib/re/server'
require_relative 'lib/re/macros'
require_relative 'lib/re/themes/base16_modified'
require_relative 'lib/re/rouge/lexer'
require_relative 'lib/re/themes/loader'

require 'fcntl'

if __FILE__ == $0

  opts = Slop.parse do |o|
    o.bool    '-h', '--help', "This help"
    o.bool    '--list-buffers', 'List buffers'
    o.bool    '--list-themes', 'List registered themes'
    o.string  '--run', 'Run the following editor function and exit'
    o.integer '--buffer', 'Open buffer with the given number'
    o.integer '--kill-buffer', 'Kill buffer with the given number'
    o.bool    '--server', 'Start as a server. Usually started automatically'
    o.bool    '--treeserver', 'Start as new test server'
    o.bool    '--readonly', 'Start as client, but do not start the controller at all'
    o.separator ''
    o.separator 'debug options:'
    o.bool    '--args', "Output the parsed args"
    o.bool    '--local',  'Run without server'
    o.bool    '--profile', 'Enable Rubyprof profiling dumped to ~/.re-profile.html on exit'
    o.bool    '--intercept',  'Log operations to the server to ~/.re-oplog-[client pid].txt'
  end

  if opts.help?
    puts opts
    exit(0)
  end

  if opts.args?
    p opts
    p ARGV
    exit(0)
  end

  if opts.server?

    # Daemonize by double-fork and becoming sesson leader.
    raise 'First fork failed' if (pid = fork) == -1
    exit unless pid.nil?
    Process.setsid
    raise 'Second fork failed' if (pid = fork) == -1
    exit unless pid.nil?

    STDIN.reopen '/dev/null'
    STDOUT.reopen '/dev/null', 'a'

    $factory = f = Factory.new

    begin
      DRb.start_service($uri, f)
    rescue Errno::EADDRINUSE
      fname = "#{ENV["HOME"]}/.re"
      begin
        UNIXSocket.new(fname)
        STDERR.puts "Another server is listening on #{fname}. Exiting"
        exit 1
      rescue Errno::ECONNREFUSED
        File.unlink(fname)
      end
      retry
    end

    STDERR.reopen STDOUT

    Thread.abort_on_exception = true
    Thread.new do
      loop do
        sleep(60)
        f.store_buffers
      end
    end

    DRb.thread.join
    exit(0)
  end

  DRb.start_service if !opts.local?

  if opts.profile?
    at_exit do
      profile = RubyProf.stop
      STDERR.puts "Writing profile"
      File.open(File.expand_path("~/.re-profile.html"),"w") do |f|
        printer = RubyProf::CallStackPrinter.new(profile)
        printer.print(f, {})
      end
    end
    RubyProf.start rescue nil
  end

  first = true
  loop do
    begin
      $factory = f = opts.local? ? Factory.new : DRbObject.new_with_uri($uri)

      if opts.list_buffers?
        puts f.list_buffers
        exit(0)
      elsif opts.list_themes?
        puts Rouge::Theme.registry.keys.sort.join("\n")
        exit(0)
      elsif opts[:kill_buffer]
        f.kill_buffer(opts[:kill_buffer])
        exit(0)
      end

      if opts[:buffer]
        $editor = Editor.new(buffer: f.new_buffer(opts[:buffer],""), factory: f, intercept: opts.intercept?, readonly: opts[:readonly])
      else
        $editor = Editor.new(filename: opts.arguments[0], factory: f, intercept: opts.intercept?, readonly: opts[:readonly])
      end

      if opts[:run]
        p $editor.send(opts[:run])
        break
      end

      $editor.run
      break
    rescue DRb::DRbConnError => e
      p e
      if !first
        sleep(0.1)
        STDERR.puts "Failed to open connection to server. Trying to start"
      end
      first = false
      cmd = ["ruby",__FILE__,"--server"].join(" ")
      system(cmd)
    rescue SystemExit
      raise
    rescue Exception => e
      $editor.pry(e)
    end
  end
end
