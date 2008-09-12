require 'enumerator'
require 'strscan'
require 'sass/tree/node'
require 'sass/tree/value_node'
require 'sass/tree/rule_node'
require 'sass/tree/comment_node'
require 'sass/tree/attr_node'
require 'sass/tree/directive_node'
require 'sass/constant'
require 'sass/error'
require 'haml/shared'

module Sass
  # This is the class where all the parsing and processing of the Sass
  # template is done. It can be directly used by the user by creating a
  # new instance and calling <tt>render</tt> to render the template. For example:
  #
  #   template = File.load('stylesheets/sassy.sass')
  #   sass_engine = Sass::Engine.new(template)
  #   output = sass_engine.render
  #   puts output
  class Engine
    Line = Struct.new(:text, :tabs, :index, :filename, :children)
    Mixin = Struct.new(:args, :tree)

    # The character that begins a CSS attribute.
    ATTRIBUTE_CHAR  = ?:

    # The character that designates that
    # an attribute should be assigned to the result of constant arithmetic.
    SCRIPT_CHAR     = ?=

    # The character that designates the beginning of a comment,
    # either Sass or CSS.
    COMMENT_CHAR = ?/

    # The character that follows the general COMMENT_CHAR and designates a Sass comment,
    # which is not output as a CSS comment.
    SASS_COMMENT_CHAR = ?/

    # The character that follows the general COMMENT_CHAR and designates a CSS comment,
    # which is embedded in the CSS document.
    CSS_COMMENT_CHAR = ?*

    # The character used to denote a compiler directive.
    DIRECTIVE_CHAR = ?@

    # Designates a non-parsed rule.
    ESCAPE_CHAR    = ?\\

    # Designates block as mixin definition rather than CSS rules to output
    MIXIN_DEFINITION_CHAR = ?=

    # Includes named mixin declared using MIXIN_DEFINITION_CHAR
    MIXIN_INCLUDE_CHAR    = ?+

    # The regex that matches and extracts data from
    # attributes of the form <tt>:name attr</tt>.
    ATTRIBUTE = /^:([^\s=:]+)\s*(=?)(?:\s+|$)(.*)/

    # The regex that matches attributes of the form <tt>name: attr</tt>.
    ATTRIBUTE_ALTERNATE_MATCHER = /^[^\s:]+\s*[=:](\s|$)/

    # The regex that matches and extracts data from
    # attributes of the form <tt>name: attr</tt>.
    ATTRIBUTE_ALTERNATE = /^([^\s=:]+)(\s*=|:)(?:\s+|$)(.*)/

    # Creates a new instace of Sass::Engine that will compile the given
    # template string when <tt>render</tt> is called.
    # See README.rdoc for available options.
    #
    #--
    #
    # TODO: Add current options to REFRENCE. Remember :filename!
    #
    # When adding options, remember to add information about them
    # to README.rdoc!
    #++
    #
    def initialize(template, options={})
      @options = {
        :style => :nested,
        :load_paths => ['.']
      }.merge! options
      @template = template
      @constants = {"important" => "!important"}
      @mixins = {}
    end

    # Processes the template and returns the result as a string.
    def render
      begin
        render_to_tree.to_s
      rescue SyntaxError => err
        err.sass_line = @line unless err.sass_line
        unless err.sass_filename
          err.add_backtrace_entry(@options[:filename])
        end
        raise err
      end
    end

    alias_method :to_css, :render

    protected

    def constants
      @constants
    end

    def mixins
      @mixins
    end

    def render_to_tree
      root = Tree::Node.new(@options)
      append_children(root, tree(tabulate(@template)).first, true)
      root
    end

    private

    def tabulate(string)
      tab_str = nil
      first = true
      string.gsub(/\r|\n|\r\n|\r\n/, "\n").scan(/^.*?$/).enum_with_index.map do |line, index|
        index += 1
        next if line.strip.empty? || line =~ /^\/\//

        line_tab_str = line[/^\s*/]
        unless line_tab_str.empty?
          tab_str ||= line_tab_str

          raise SyntaxError.new("Indenting at the beginning of the document is illegal.", index) if first
          if tab_str.include?(?\s) && tab_str.include?(?\t)
            raise SyntaxError.new("Indentation can't use both tabs and spaces.", index)
          end
        end
        first &&= !tab_str.nil?
        next Line.new(line.strip, 0, index, @options[:filename], []) if tab_str.nil?

        line_tabs = line_tab_str.scan(tab_str).size
        raise SyntaxError.new(<<END.strip.gsub("\n", ' '), index) if tab_str * line_tabs != line_tab_str
Inconsistent indentation: #{Haml::Shared.human_indentation line_tab_str, true} used for indentation,
but the rest of the document was indented using #{Haml::Shared.human_indentation tab_str}.
END

        Line.new(line.strip, line_tabs, index, @options[:filename], [])
      end.compact
    end

    def tree(arr, i = 0)
      base = arr[i].tabs
      nodes = []
      while (line = arr[i]) && line.tabs >= base
        if line.tabs > base
          if line.tabs > base + 1
            raise SyntaxError.new("The line was indented #{line.tabs - base} levels deeper than the previous line.", line.index)
          end

          nodes.last.children, i = tree(arr, i)
        else
          nodes << line
          i += 1
        end
      end
      return nodes, i
    end

    def build_tree(line, root = false)
      @line = line.index
      node = parse_line(line, root)

      # Node is a symbol if it's non-outputting, like a constant assignment,
      # or an array if it's a group of nodes to add
      return node unless node.is_a? Tree::Node

      node.line = line.index
      node.filename = line.filename

      unless node.is_a?(Tree::CommentNode)
        append_children(node, line.children, false)
      else
        node.children = line.children
      end
      return node
    end

    def append_children(parent, children, root)
      continued_rule = nil
      children.each do |line|
        child = build_tree(line, root)

        if child.is_a?(Tree::RuleNode) && child.continued?
          raise SyntaxError.new("Rules can't end in commas.", child.line) unless child.children.empty?
          if continued_rule
            continued_rule.add_rules child
          else
            continued_rule = child
          end
          next
        end

        if continued_rule
          raise SyntaxError.new("Rules can't end in commas.", continued_rule.line) unless child.is_a?(Tree::RuleNode)
          continued_rule.add_rules child
          continued_rule.children = child.children
          continued_rule, child = nil, continued_rule
        end

        validate_and_append_child(parent, child, line, root)
      end

      raise SyntaxError.new("Rules can't end in commas.", continued_rule.line) if continued_rule

      parent
    end

    def validate_and_append_child(parent, child, line, root)
      unless root
        case child
        when :constant
          raise SyntaxError.new("Constants may only be declared at the root of a document.", line.index)
        when :mixin
          raise SyntaxError.new("Mixins may only be defined at the root of a document.", line.index)
        when Tree::DirectiveNode
          raise SyntaxError.new("Import directives may only be used at the root of a document.", line.index)
        end
      end

      case child
      when Array
        child.each {|c| validate_and_append_child(parent, c, line, root)}
      when Tree::Node
        parent << child
      end
    end

    def parse_line(line, root)
      case line.text[0]
      when ATTRIBUTE_CHAR
        parse_attribute(line.text, ATTRIBUTE)
      when Constant::CONSTANT_CHAR
        parse_constant(line)
      when COMMENT_CHAR
        parse_comment(line.text)
      when DIRECTIVE_CHAR
        parse_directive(line, root)
      when ESCAPE_CHAR
        Tree::RuleNode.new(line.text[1..-1], @options)
      when MIXIN_DEFINITION_CHAR
        parse_mixin_definition(line)
      when MIXIN_INCLUDE_CHAR
        if line.text[1].nil? || line.text[1] == ?\s
          Tree::RuleNode.new(line.text, @options)
        else
          parse_mixin_include(line, root)
        end
      else
        if line.text =~ ATTRIBUTE_ALTERNATE_MATCHER
          parse_attribute(line.text, ATTRIBUTE_ALTERNATE)
        else
          Tree::RuleNode.new(interpolate(line.text), @options)
        end
      end
    end

    def parse_attribute(line, attribute_regx)
      if @options[:attribute_syntax] == :normal &&
          attribute_regx == ATTRIBUTE_ALTERNATE
        raise SyntaxError.new("Illegal attribute syntax: can't use alternate syntax when :attribute_syntax => :normal is set.")
      elsif @options[:attribute_syntax] == :alternate &&
          attribute_regx == ATTRIBUTE
        raise SyntaxError.new("Illegal attribute syntax: can't use normal syntax when :attribute_syntax => :alternate is set.")
      end

      name, eq, value = line.scan(attribute_regx)[0]

      if name.nil? || value.nil?
        raise SyntaxError.new("Invalid attribute: \"#{line}\".", @line)
      end

      if eq.strip[0] == SCRIPT_CHAR
        value = Sass::Constant.resolve(value, @constants, @line)
      end

      Tree::AttrNode.new(interpolate(name), interpolate(value), @options)
    end

    def parse_constant(line)
      name, op, value = line.text.scan(Sass::Constant::MATCH)[0]
      raise SyntaxError.new("Illegal nesting: Nothing may be nested beneath constants.", @line + 1) unless line.children.empty?
      raise SyntaxError.new("Invalid constant: \"#{line.text}\".", @line) unless name && value

      constant = Sass::Constant.resolve(value, @constants, @line)
      if op == '||='
        @constants[name] ||= constant
      else
        @constants[name] = constant
      end

      :constant
    end

    def parse_comment(line)
      if line[1] == SASS_COMMENT_CHAR
        :comment
      elsif line[1] == CSS_COMMENT_CHAR
        Tree::CommentNode.new(line, @options)
      else
        Tree::RuleNode.new(line, @options)
      end
    end

    def parse_directive(line, root)
      directive, value = line.text[1..-1].split(/\s+/, 2)

      # If value begins with url( or ",
      # it's a CSS @import rule and we don't want to touch it.
      if directive == "import" && value !~ /^(url\(|")/
        raise SyntaxError.new("Illegal nesting: Nothing may be nested beneath import directives.", @line + 1) unless line.children.empty?
        import(value)
      elsif directive == "if"
        parse_if(line, root, value)
      elsif directive == "for"
        parse_for(line, root, value)
      elsif directive == "while"
        parse_while(line, root, value)
      else
        Tree::DirectiveNode.new(line.text, @options)
      end
    end

    def parse_if(line, root, text)
      if Sass::Constant.parse(text, @constants, line.index).to_bool
        append_children([], line.children, root)
      else
        []
      end
    end

    def parse_for(line, root, text)
      var, from_expr, to_name, to_expr = text.scan(/^([^\s]+)\s+from\s+(.+)\s+(to|through)\s+(.+)$/).first

      if var.nil? # scan failed, try to figure out why for error message
        if text !~ /^[^\s]+/
          expected = "constant name"
        elsif text !~ /^[^\s]+\s+from\s+.+/
          expected = "'from <expr>'"
        else
          expected = "'to <expr>' or 'through <expr>'"
        end
        raise SyntaxError.new("Invalid for directive '@for #{text}': expected #{expected}.", @line)
      end
      raise SyntaxError.new("Invalid constant \"#{var}\".", @line) unless var =~ Constant::VALIDATE

      from = Sass::Constant.parse(from_expr, @constants, @line).to_i
      to = Sass::Constant.parse(to_expr, @constants, @line).to_i
      range = Range.new(from, to, to_name == 'to')

      tree = []
      old_constants = @constants.dup
      for i in range
        @constants[var[1..-1]] = i.to_s
        append_children(tree, line.children, root)
      end
      @constants = old_constants
      tree
    end

    def parse_while(line, root, text)
      tree = []
      while Sass::Constant.parse(text, @constants, line.index).to_bool
        append_children(tree, line.children, root)
      end
      tree
    end

    def parse_mixin_definition(line)
      name, args = line.text.scan(/^=\s*([^(]+)(\([^)]*\))?$/).first
      raise SyntaxError.new("Invalid mixin \"#{line.text[1..-1]}\".", @line) if name.nil?
      default_arg_found = false
      required_arg_count = 0
      args = (args || "()")[1...-1].split(",", -1).map {|a| a.strip}.map do |arg|
        raise SyntaxError.new("Mixin arguments can't be empty.", @line) if arg.empty? || arg == "!"
        unless arg[0] == Constant::CONSTANT_CHAR
          raise SyntaxError.new("Mixin argument \"#{arg}\" must begin with an exclamation point (!).", @line)
        end
        arg, default = arg.split(/\s*=\s*/, 2)
        required_arg_count += 1 unless default
        default_arg_found ||= default
        raise SyntaxError.new("Invalid constant \"#{arg}\".", @line) unless arg =~ Constant::VALIDATE
        raise SyntaxError.new("Required arguments must not follow optional arguments \"#{arg}\".", @line) if default_arg_found && !default
        default = Sass::Constant.resolve(default, @constants, @line) if default
        { :name => arg[1..-1], :default_value => default }
      end
      mixin = @mixins[name] = Mixin.new(args, line.children)
      :mixin
    end

    def parse_mixin_include(line, root)
      name, args = line.text.scan(/^\+\s*([^(]+)(\([^)]*\))?$/).first
      raise SyntaxError.new("Illegal nesting: Nothing may be nested beneath mixin directives.", @line + 1) unless line.children.empty?
      raise SyntaxError.new("Invalid mixin include \"#{line.text}\".", @line) if name.nil?
      raise SyntaxError.new("Undefined mixin '#{name}'.", @line) unless mixin = @mixins[name]

      args = (args || "()")[1...-1].split(",", -1).map {|a| a.strip}
      args.each {|a| raise SyntaxError.new("Mixin arguments can't be empty.", @line) if a.empty?}
      raise SyntaxError.new(<<END.gsub("\n", "")) if mixin.args.size < args.size
Mixin #{name} takes #{mixin.args.size} argument#{'s' if mixin.args.size != 1}
 but #{args.size} #{args.size == 1 ? 'was' : 'were'} passed.
END

      old_constants = @constants.dup
      mixin.args.zip(args).inject(@constants) do |constants, (arg, value)|
        constants[arg[:name]] = if value
          Sass::Constant.resolve(value, old_constants, @line)
        else
          arg[:default_value]
        end
        raise SyntaxError.new("Mixin #{name} is missing parameter ##{mixin.args.index(arg)+1} (#{arg[:name]}).") unless constants[arg[:name]]
        constants
      end

      tree = append_children([], mixin.tree, root)
      @constants = old_constants
      tree
    end

    def interpolate(text)
      scan = StringScanner.new(text)
      str = ''

      while scan.scan(/(.*?)(\\*)\#\{/)
        escapes = scan[2].size
        str << scan.matched[0...-2 - escapes]
        if escapes % 2 == 1
          str << '#{'
        else
          str << Sass::Constant.resolve(balance(scan, ?{, ?}, 1)[0][0...-1], @constants, @line)
        end
      end

      str + scan.rest
    end

    def balance(*args)
      res = Haml::Shared.balance(*args)
      return res if res
      raise SyntaxError.new("Unbalanced brackets.", @line)
    end

    def import_paths
      paths = @options[:load_paths] || []
      paths.unshift(File.dirname(@options[:filename])) if @options[:filename]
      paths
    end

    def import(files)
      nodes = []

      files.split(/,\s*/).each do |filename|
        engine = nil

        begin
          filename = self.class.find_file_to_import(filename, import_paths)
        rescue Exception => e
          raise SyntaxError.new(e.message, @line)
        end

        if filename =~ /\.css$/
          nodes << Tree::DirectiveNode.new("@import url(#{filename})", @options)
        else
          File.open(filename) do |file|
            new_options = @options.dup
            new_options[:filename] = filename
            engine = Sass::Engine.new(file.read, new_options)
          end

          engine.constants.merge! @constants
          engine.mixins.merge! @mixins

          begin
            root = engine.render_to_tree
          rescue Sass::SyntaxError => err
            err.add_backtrace_entry(filename)
            raise err
          end
          nodes += root.children
          @constants = engine.constants
          @mixins = engine.mixins
        end
      end

      nodes
    end

    def self.find_file_to_import(filename, load_paths)
      was_sass = false
      original_filename = filename

      if filename[-5..-1] == ".sass"
        filename = filename[0...-5]
        was_sass = true
      elsif filename[-4..-1] == ".css"
        return filename
      end

      new_filename = find_full_path("#{filename}.sass", load_paths)

      if new_filename.nil?
        if was_sass
          raise Exception.new("File to import not found or unreadable: #{original_filename}.")
        else
          return filename + '.css'
        end
      else
        new_filename
      end
    end

    def self.find_full_path(filename, load_paths)
      load_paths.each do |path|
        segments = filename.split(File::SEPARATOR)
        segments.push "_#{segments.pop}"
        [segments.join(File::SEPARATOR), filename].each do |name|
          full_path = File.join(path, name)
          if File.readable?(full_path)
            return full_path
          end
        end
      end
      nil
    end
  end
end
