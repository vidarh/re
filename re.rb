#!/usr/bin/env ruby

# Bundler doesn't behave very well when
# the current working dir is "unexpected"
def bundler
   pwd = Dir.pwd
   Dir.chdir(File.dirname(__FILE__))
   require 'bundler'
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
require_relative 'lib/re/buffer'
require_relative 'lib/re/view'
require_relative 'lib/re/cursor'
require_relative 'lib/re/history'
require_relative 'lib/re/modes'
require_relative 'lib/re/controller'
require_relative 'lib/re/indent'
require_relative 'lib/re/editor'
require_relative 'lib/re/server'


if __FILE__ == $0

  if ARGV.first == "--server"

    $factory = f = Factory.new
    DRb.start_service($uri, f)

    Thread.abort_on_exception = true
    Thread.new do
      loop do
        sleep(5)
        f.store_buffers
      end
    end

    #$SAFE = 1   # disable eval() and friends

    # Wait for the drb server thread to finish before exiting.
    DRb.thread.join
  else
    DRb.start_service
    first = true
    loop do
      begin
        $factory = f = DRbObject.new_with_uri($uri)

        at_exit do
          profile = RubyProf.stop
          STDERR.puts "Writing profile"
          File.open(File.expand_path("~/.re-profile.html"),"w") do |f|
            printer = RubyProf::CallStackPrinter.new(profile)
            printer.print(f, {})
          end
        end

        RubyProf.start rescue nil

        if ARGV[0] == "--list-buffers"
          puts f.list_buffers
        elsif ARGV[0] == "--buffer"
          $editor =Editor.new(buffer: f.new_buffer(ARGV[1].to_i,""), factory: f)
          $editor.run
        else
          $editor = Editor.new(filename: ARGV[0], factory: f)
          $editor.run
        end
        break
      rescue DRb::DRbConnError => e
        p e
        if !first
          sleep(0.1)
          STDERR.puts "Failed to open connection to server. Trying to start"
        end
        first = false
        cmd = ["ruby",__FILE__,"--server", "2>/dev/null", ">/dev/null","&"].join(" ")
        p cmd
        system(cmd)
      rescue SystemExit
        raise
      rescue Exception => e
        puts ANSI.cls
        binding.pry
      end
    end
  end
end
