# coding: utf-8

class KeyBindings
  def self.load_map(name)
    TomlRB.load_file(File.expand_path(name), symbolize_keys: true)
  end

  def self.user_map
    load_map('~/.config/re/keymap.toml')
  rescue
    STDERR.puts 'WARNING: No user config found in ~/.config/re/keymap.toml'
  end

  def self.global_map
    load_map(File.dirname(__FILE__) + '/keymap.toml')
  end

  global_keys = global_map # rescue {keys: {}}
  user_keys = user_map || {} # rescue {keys: {}}

  @@map = global_keys[:keys].merge(user_keys[:keys] || {})

  def self.map
    @@map
  end
end
