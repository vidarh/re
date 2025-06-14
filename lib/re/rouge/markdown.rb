# -*- coding: utf-8 -*- #
# frozen_string_literal: true

module Rouge
  module Lexers
    class Markdown < RegexLexer
      title 'Markdown'
      desc 'Markdown, a light-weight markup language for authors'

      tag 'markdown'
      aliases 'md', 'mkd'
      filenames '*.markdown', '*.md', '*.mkd'
      mimetypes 'text/x-markdown'

      def html
        @html ||= HTML.new(options)
      end

      start { html.reset! }

      # edot = /\\.|[^\\\n]/
      edot = /\\.|[^\\]/

      state :em do
        rule /[*]/, Generic::Emph, :pop!
        rule /./, Generic::Emph
      end

      state :strong do
        rule /[*][*]/, Generic::Strong, :pop!
        rule edot, Generic::Strong
      end

      state :strd do
        rule /^#/, Error, :pop!
        rule /"/, Literal::String::Double, :pop!
        rule /[^"]+/, Literal::String::Double
      end

      # rule /[*]#{edot}*?[*]/, Generic::Emph, :em
      state :root do
        # YAML frontmatter
        rule(/\A(---\s*\n.*?\n?)^(---\s*$\n?)/m) { delegate YAML }

        rule /\\./, Str::Escape

        rule /^[\S ]+\n(?:---*)\n/, Generic::Heading
        rule /^[\S ]+\n(?:===*)\n/, Generic::Subheading

        rule /^#(?=[^#]).*?$/, Generic::Heading
        rule /^##*.*?$/, Generic::Subheading

        rule /^([ \t]*)(```)([^\n]*)/ do |m|
          token Text, m[1]
          token Punctuation, m[2]
          token Name::Label, m[3]
          name = m[3].strip
          sublexer = Lexer.find_fancy(name.empty? ? 'guess' : name, m[5], @options)
          sublexer ||= PlainText.new(@options.merge(:token => Str::Backtick))
          sublexer.reset!
          push do
            rule /^([ \t]*)(#{m[2]})/ do |m|
              pop!
              token Text, m[1]
              token Punctuation, m[2]
            end
            rule /^.*$/ do |m|
              delegate sublexer, m[1]
            end
          end
        end

        rule /^([ \t]*)(```|~~~)([^\n]*\n)((.*?)(\2))?/m do |m|
          name = m[3].strip
          sublexer = Lexer.find_fancy(name.empty? ? 'guess' : name, m[5], @options)
          sublexer ||= PlainText.new(@options.merge(:token => Str::Backtick))
          sublexer.reset!

          token Text, m[1]
          token Punctuation, m[2]
          token Name::Label, m[3]
          if m[5]
            delegate sublexer, m[5]
          end

          token Punctuation, m[6]
          if m[6]
          else
            push do
              rule /^([ \t]*)(#{m[2]})/ do |m|
                pop!
                token Text, m[1]
                token Punctuation, m[2]
              end
              rule /^.*\n/ do |m|
                delegate sublexer, m[1]
              end
            end
          end
        end

        rule /\n\n((    |\t).*?\n|\n)+/, Str::Backtick

        rule /"[^"]*"/, Literal::String::Double
        rule /"[^"]*/, Literal::String::Double, :strd
        rule /(`+)(?:#{edot}|\n)+?\1/, Str::Backtick
        rule /("+)(?:#{edot}|\n)+?\1/, Literal::String::Double

        # various uses of * are in order of precedence

        # line breaks
        rule /^(\s*[*]){3,}\s*$/, Punctuation
        rule /^(\s*[-]){3,}\s*$/, Punctuation

        # bulleted lists
        rule /^\s*[*+-](?=\s)/, Punctuation

        # numbered lists
        rule /^\s*\d+\./, Punctuation

        # blockquotes
        rule /^\s*>.*?$/, Generic::Traceback

        # link references
        # [foo]: bar "baz"
        rule %r(^
          (\s*) # leading whitespace
          (\[) (#{edot}+?) (\]) # the reference
          (\s*) (:) # colon
        )x do
          groups Text, Punctuation, Str::Symbol, Punctuation, Text, Punctuation

          push :title
          push :url
        end

        # links and images
        rule /(!?\[)(#{edot}*?)(\])/ do
          groups Punctuation, Name::Variable, Punctuation
          push :link
        end

        rule /[*][*]/, Generic::Strong, :strong
        # rule /[*][*]#{edot}*?[*][*]/, Generic::Strong, :strong
        rule /__#{edot}*?__/, Generic::Strong

        # rule /[*]#{edot}*?[*]/, Generic::Emph, :em
        rule /[*]/, Generic::Emph, :em
        rule /_#{edot}*?_/, Generic::Emph

        # Automatic links
        rule /<.*?@.+[.].+>/, Name::Variable
        rule %r[<(https?|mailto|ftp)://#{edot}*?>], Name::Variable

        rule /[^"\\`\[*\n&<]+/, Text

        # inline html
        rule(/&\S*;/) { delegate html }
        rule(/<#{edot}*?>/) { delegate html }
        rule /[&<]/, Text

        rule /\n/, Text
      end

      state :link do
        rule /(\[)(#{edot}*?)(\])/ do
          groups Punctuation, Str::Symbol, Punctuation
          pop!
        end

        rule /[(]/ do
          token Punctuation
          push :inline_title
          push :inline_url
        end

        rule /[ \t]+/, Text

        rule(//) { pop! }
      end

      state :url do
        rule /[ \t]+/, Text

        # the url
        rule /(<)(#{edot}*?)(>)/ do
          groups Name::Tag, Str::Other, Name::Tag
          pop!
        end

        rule /\S+/, Str::Other, :pop!
      end

      state :title do
        rule /"#{edot}*?"/, Name::Namespace
        rule /'#{edot}*?'/, Name::Namespace
        rule /[(]#{edot}*?[)]/, Name::Namespace
        rule /\s*(?=["'()])/, Text
        rule(//) { pop! }
      end

      state :inline_title do
        rule /[)]/, Punctuation, :pop!
        mixin :title
      end

      state :inline_url do
        rule /[^<\s)]+/, Str::Other, :pop!
        rule /\s+/m, Text
        mixin :url
      end
    end
  end
end
