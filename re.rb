#!/usr/bin/env ruby

$: << File.expand_path('./stub')
$: << File.expand_path(File.dirname(__FILE__))

require 'logger'
# FIXME: Not the right place
$log = Logger.new(File.expand_path('~/.re.log'))

class IOToLog
  def initialize(log)
    @log = log
  end

  def write(*args)
    @log.debug(caller[0..2].join(' / '))
    @log.debug(args.join)
  end

  def flush = nil
  def sync=(val)
    nil
  end
end

# Backwards compat
Fixnum = Integer

class File
  def self.exists?(f)
    exist?(f)
  end
end

def bundler
  pwd = Dir.pwd
  begin
    Dir.chdir(File.dirname(__FILE__))
  rescue Errno::ENOENT
    #Dir.chdir(File.expand_path("~"))
  end

  require 'bundler/setup'
#  Bundler.require(:default)

## FIXME: This is horrifying
#$: << "vendor/bundle//ruby/2.7.0/gems/rouge-4.0.0/lib/"
  Dir.chdir(pwd)
end

bundler

#require 'pry'
#binding.pry

require 'io/console'
require 'drb/drb'
require 'drb/unix'
require 'drb/observer'

require 'fcntl'
require 'rouge'
require 'pry'

require 'toml-rb'

#end

require_relative 'lib/re/monkeys'
require_relative 'lib/re/ansi'
require_relative 'lib/re/view'
require_relative 'lib/re/modes'
require_relative 'lib/re/indent'
require_relative 'lib/re/editor'
require_relative 'lib/re/server'
require_relative 'lib/re/macros'
require_relative 'lib/re/themes/base16_modified'
require_relative 'lib/re/rouge/lexer'
require 'rouge/gtk_theme_loader'

if __FILE__ == $0
  require 'slop'

  opts = Slop.parse do |o|
    o.bool    '-h', '--help', 'This help'
    o.bool    '--list-buffers', 'List buffers'
    o.bool    '--list-themes', 'List registered themes'
    o.string  '--run', 'Run the following editor function and exit'
    o.integer '--buffer', 'Open buffer with the given number'
    o.bool    '--get', 'Get the contents of the buffer and exit'
    o.integer '--kill-buffer', 'Kill buffer with the given number'
    o.bool    '--server', 'Start as a server. Usually started automatically'
    o.bool    '--foreground', 'If starting as a server, remain in foreground'
    o.bool    '--treeserver', 'Start as new test server'
    o.bool    '--readonly', 'Start as client, but do not start the controller at all'
    o.separator ''
    o.separator 'debug options:'
    o.bool    '--args', 'Output the parsed args'
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
    start_server(foreground: opts.foreground?)
    exit(0)
  end

  # FIXME: For callbacks. Really shouldn't be necessary.
  DRb.start_service if !opts.local?

  if opts.profile?
    at_exit do
      profile = RubyProf.stop
      STDERR.puts 'Writing profile'
      File.open(File.expand_path('~/.re-profile.html'),'w') do |f|
        printer = RubyProf::CallStackPrinter.new(profile)
        printer.print(f, {})
      end
    end
    RubyProf.start rescue nil
  end

  first = true
  loop do
    begin
      with_connection(local: opts.local?) do |f|

        # FIXME: For now this is to force testing of the DrB connection
        list = f.list_buffers

        if opts.list_buffers?
          puts list
          exit(0)
        elsif opts.list_themes?
          puts Rouge::Theme.registry.keys.sort_by{_1.downcase}.join("\n")
          exit(0)
        elsif opts[:kill_buffer]
          f.kill_buffer(opts[:kill_buffer])
          exit(0)
        end

        if opts[:buffer]
          $buffer = f.new_buffer(opts[:buffer],'')
        end

        if opts[:get]
          if !$buffer
            # FIXME: Add way to reference 'special' buffer names w/out expand_path
            $fname = File.expand_path(opts.arguments[0])
            $buffer = f.find_buffer($fname)
          else
            $fname = opts[:buffer]
          end
          if !$buffer
            STDERR.puts "No such buffer: #{$fname}"
            exit(1)
          end

          p $buffer.__drburi
          puts $buffer.lines(0..-1).join("\n")
          exit(0)
        end

        if $buffer
          $editor = Editor.new(buffer: $buffer, factory: f, intercept: opts.intercept?, readonly: opts[:readonly])
        else
          $editor = Editor.new(filename: opts.arguments[0], factory: f, intercept: opts.intercept?, readonly: opts[:readonly])
        end

        $> = IOToLog.new($log)

        if opts[:run]
          p $editor.send(opts[:run])
          break
        end


        $editor.run
        Termcontroller::Controller.quit
        break
      end
    rescue SystemExit
      raise
    rescue Exception => e
      $editor.pry(e)
    end
  end
end
