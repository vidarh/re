# coding: utf-8

require_relative 'keymap'
require 'keyboard_map'
require 'io/console'

class Controller

  attr_reader :lastcmd,:lastkey,:lastchar
  attr_accessor :mode

  @@keybindings = KeyBindings.map
  @@con = IO.console

  # Pause *any* Controller instance
  @@pause = false
  def self.pause!
    old = @@pause
    @@pause = true
    @@con.cooked do
      yield
    end
  ensure
    @@pause = old
  end

  def paused?
    @mode == :pause || @@pause
  end

  def initialize(target)
    @target = target
    @buf = ""
    @commands = []
    @mode = :cooked

    @kb = KeyboardMap.new
    @@con = @con = IO.console
    raise if !@con
    @t = Thread.new { readloop }
    @m = Mutex.new
  end

  def readloop
    loop do
      if paused?
        sleep(0.1)
      elsif @mode == :cooked
        read_input
      else
        fill_buf
      end
    end
  end

  def pause
    old = @mode
    @mode = :pause
    yield
  ensure
    @mode = old
  end

  def fill_buf(timeout=0.1)
    if paused?
      sleep(0.1)
      Thread.pass
      return
    end
    @con.raw!
    return if !IO.select([$stdin],nil,nil,0.1)
    str = $stdin.read_nonblock(4096)
    str.force_encoding("utf-8")
    @buf << str
  rescue IO::WaitReadable
  end

  def getc(timeout=0.1)
    if !paused?
      while @buf.empty?
        fill_buf
      end
      @buf.slice!(0) if !paused? && @mode == :cooked
    else
      sleep(0.1)
      Thread.pass
      return nil
    end
  end

  def raw
    @mode = :raw
    yield
  ensure
    @mode = :cooked
  end

  def read_char
    sleep(0.001) if @buf.empty?
    @buf.slice!(0)
  end

  def get_command
    map = @@keybindings
    loop do
      c = nil
      char = getc
      return nil if !char

      c1 = Array(@kb.call(char)).first
      c = map[c1.to_sym] if c1

      if c.nil? && c1.kind_of?(String)
        return [:insert_char, c1]
      end

      if c.nil?
        if c1
          @lastchar = c1.to_sym
          return @lastchar
        else
          @lastchar = char.inspect
          return nil
        end
      end

      if c.kind_of?(Hash)
        map = c
      else
        @lastchar = c1.to_sym.to_s.split("_").join(" ")
        @lastchar += " (#{c.to_s})" if c.to_s != @lastchar
        return c
      end
    end
  end

  def do_command(c)
    return nil if !c
    if @target.respond_to?(Array(c).first)
      @lastcmd = c
      @target.instance_eval { send(*Array(c)) }
    else
      @lastchar = "Unbound: #{Array(c).first.inspect}"
    end
  end

  def read_input
    c = get_command
    if !c
      Thread.pass
      return
    end
    if Array(c).first == :insert_char
      # FIXME: Attempt to combine multiple :insert_char into one.
      #Probably should happen in get_command
      #while (c2 = get_command) && Array(c2).first == :insert_char
      #  c.last << c2.last
      #end
      #@commands << c
      #c = c2
      #return nil if !c
    end
#    p [:READ_INPUT,c, @commands]
#    @m.synchronize {
    @commands << c
#     }
    Thread.pass
  end

  def next_command
    if @commands.empty?
      sleep(0.01)
      Thread.pass
    else
#      p [:NEXT_COMMAND, @commands]
    end
    #@m.synchronize {
    @commands.shift
     #}
  end

  def handle_input(prefix="",timeout=0.1)
    if c = next_command
#      p [:NEXT, c]
      do_command(c)
    end
    return c
  end
end
