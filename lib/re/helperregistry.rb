# # Helper program integration
#
# A principle of Re is to rely on helpers for as many things
# as possible. That means avoiding building functionality which
# either can be handled better by an existing program or by writing
# a separate tool.
#
# "Better" is of course subjective, however this class encapsulates
# means of doing things which has been farmed out to other programs
# or small scripts.
#
# Where there's a sensible XDG standard, we should use that, e.g.
# to open URLs, xdg-open is being used.
#
# Part of the motivation for splitting them out is to eventually
# make them configurable and/or allow people to override them with
# code to make Re do it internally cleanly.
#
# It's a class rather than a module with the intent of allowing
# you to e.g. load different sets of configs in the future.
#

require 'shellwords'

class HelperRegistry
  # This is because Bundler is a piece of shit.
  # It pollutes the environments in ways that makes
  # spawning a Ruby program from Ruby wildly unreliable
  # unless you clear out as much as possible
  def start(cmd)
    dir =
      spawn(
        { 'HOME' => ENV['HOME'],
          'DISPLAY' => ENV['DISPLAY'],
          'LANG' => ENV['LANG'],
          'PATH' => ENV['PATH'] },
        cmd,
        {
          unsetenv_others: true,
          chdir: File.expand_path('~')
        }
      )
  end

  def select_section(buffer)
    `select-section #{buffer}`
  end

  def select_buffer
    `select-buffer 2>/dev/null`
  end

  def url_open(url)
    `xdg-open #{url}`.strip
  end

  def select_file
    `filesel 2>/dev/null`
  end

  def select_syntax_theme
    `select-rouge-theme 2>/dev/null`.strip
  end

  def open_new_window(buffer)
    cmd = "term 2>>/tmp/relog.txt e #{bufferarg(buffer)}"
    $log.debug("open_new_window: #{cmd}")
    start(cmd)
  end

  def split_vertical(buffer)
    system("split-vertical 2>>/tmp/relog.txt term re #{bufferarg(buffer)}")
  end

  def split_vertical_term
    system('split-vertical term')
  end

  def split_horizontal(buffer_id)
    system("split-horizontal 2>>/tmp/relog.txt term re --buffer #{buffer_id}")
  end

  def split_horizontal_term(cmd = '')
    system("split-horizontal term -e #{cmd}")
  end

  private

  def bufferarg(buffer)
    if buffer.is_a?(Integer)
      buffer = "--buffer #{buffer}"
    else
      buffer = buffer.shellescape
    end
    buffer
  end
end
