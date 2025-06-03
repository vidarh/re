
module Rouge
  module Themes
    class Modified < Base16
      name 'base16.modified'
      dark!

      style Generic::Strong, :bold => true
      style Generic::Emph, :italic => true, :fg => :red

      palette speech: '#44ff88'

      palette red: '#ff4444'

      palette base00: '#272822'
      palette base01: '#383830'
      palette base02: '#49483e'
      palette base03: '#75715e'
      palette base04: '#a59f85'
      palette base05: '#f8f8f2'
      palette base06: '#f5f4f1'
      palette base07: '#f9f8f5'
      palette base08: '#f92672'
      palette base09: '#fd971f'
      palette base0A: '#f4bf75'
      palette base0B: '#88e288' # Literal string
      palette base0C: '#a1efe4'
      palette base0D: '#66d9ef'
      palette base0E: '#ae81ff'
      palette base0F: '#cc6633'
    end
  end
end
