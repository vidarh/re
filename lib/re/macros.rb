# coding: utf-8
# frozen-string-literals: true

# FIXME: Ugly hack

class Editor
  eval(File.read(File.expand_path('~/.config/re/macros.rb'))) rescue nil
end
