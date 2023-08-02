#
# # Theme loader
#
# Tries to load different types of themes
#

require 'nokogiri'

module ThemeLoader
  include Rouge::Token::Tokens

  THEME_PATHS=[
    "/usr/share/gtksourceview-3.0/styles/*.xml",
    "~/.config/re/themes/*.xml"
  ]

  # Mapping of GTK source view mappings.
  GTKMAPPING = {
    "def:string" => Literal::String,
    "def:constant" => Literal,
    "def:number" => Literal::Number,
    "def:variable" => Name::Variable,
    "def:keyword" => Keyword,
    "def:statement" => Keyword,
    "def:comment" => Comment,
    "def:type" => Name::Class,
    "def:identifier" => Name::Builtin,
    "def:emphasis" => Generic::Emph
  }

  def self.load!
    THEME_PATHS.each do |path|
      Dir[File.expand_path(path).to_s].each do |theme|
        ThemeLoader.load(theme)
      end
    end
  end

  class ReTheme < Rouge::CSSTheme
    def self.other_styles
      @other_styles ||= {}
    end

    def other_styles
      self.class.other_styles
    end
  end

  def self.load(theme)
    xml =  Nokogiri.XML(File.read(theme))
    theme = Class.new(ReTheme)
    name = xml.xpath("/style-scheme").attr("id").value
    theme.name(name)

    xml.xpath("//color").each do |c|
      theme.palette(c.attr("name").to_sym => c.attr("value").to_sym)
    end

    # Rouge barfs if we don't have a default style, so let's make sure
    text = xml.xpath("//style[@name='text']").first
    if text
      theme.style(Text,
        :fg => text.attr("foreground").to_sym,
        :bg => text.attr("background").to_sym
      )
    else
      theme.style(Text, :fg => "#ffffff", :underline => true)
    end

    xml.xpath("//style").each do |node|
      name = node.attr("name")

      rougetype = GTKMAPPING[name]
      fg = node.attr("foreground")
      fg = fg.to_sym if fg && fg[0] != '#'
      bg = node.attr("background")
      bg = bg.to_sym if bg && bg[0] != '#'
      opts = {}
      opts[:fg] = fg if fg
      opts[:bg] = bg if bg

      # FIXME: Whoops attributes appears to be switched?
      opts[:italic] = true if node.attr("italic").to_s == "true"
      opts[:bold] = true if node.attr("bold").to_s == "true"
      opts[:underline] = true if node.attr("underline")&.to_s == "true"

      if name.index(":") != nil
        theme.style(rougetype, opts)
      end
      theme.other_styles[name] = opts
    end
  end
end

ThemeLoader.load!
