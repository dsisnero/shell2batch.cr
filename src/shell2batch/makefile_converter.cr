require "./base_converter"
require "./command_mappings"
require "./common_utils"
require "./shell_converter"

module Shell2Batch
  # AST classes for Makefile parsing
  class MakefileAST
    property variables : Array(MakefileVariable)
    property rules : Array(MakefileRule)
    property directives : Array(MakefileDirective)

    def initialize
      @variables = [] of MakefileVariable
      @rules = [] of MakefileRule
      @directives = [] of MakefileDirective
    end
  end

  class MakefileVariable
    property name : String
    property value : String
    property operator : String

    def initialize(@name : String, @value : String, @operator : String = "=")
    end
  end

  class MakefileRule
    property target : String
    property dependencies : Array(String)
    property commands : Array(String)
    property phony : Bool

    def initialize(@target : String, @dependencies : Array(String) = [] of String, @commands : Array(String) = [] of String, @phony : Bool = false)
    end
  end

  class MakefileDirective
    property type : Symbol
    property arguments : Array(String)

    def initialize(@type : Symbol, @arguments : Array(String) = [] of String)
    end
  end

  # Makefile converter implementation
  class MakefileConverter < BaseConverter
    def initialize(@input : String)
      super()
    end

    def convert(content : String) : String
      ast = parse(content)
      convert_ast(ast)
    end

    private def parse(content : String) : MakefileAST
      ast = MakefileAST.new
      lines = content.lines
      current_rule : MakefileRule? = nil

      lines.each_with_index do |line, index|
        line = line.chomp

        # Skip empty lines
        next if line.strip.empty?

        # Skip comments
        next if line.strip.starts_with?("#")

        # Handle variable assignments
        if line =~ /^\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*([:+?]?=)\s*(.*)$/
          name = $1
          operator = $2
          value = $3
          ast.variables << MakefileVariable.new(name, value, operator)
          current_rule = nil
          next
        end

        # Handle rules (target: dependencies)
        if line =~ /^\s*([a-zA-Z0-9%._$()]+)\s*:(.*)$/
          target = $1
          deps_str = $2.strip
          dependencies = deps_str.empty? ? [] of String : deps_str.split.map(&.strip)

          # Check if this is a phony target
          phony = target == ".PHONY"

          current_rule = MakefileRule.new(target, dependencies, [] of String, phony)
          ast.rules << current_rule unless phony
          next
        end

        # Handle commands (tab-indented or space-indented lines)
        if current_rule && (line.starts_with?("\t") || (line =~ /^\s+/ && line.strip.size > 0))
          command = line.strip
          current_rule.commands << command unless command.empty?
        else
          current_rule = nil
        end
      end

      ast
    end

    private def convert_ast(ast : MakefileAST) : String
      output = [] of String

      # Add batch header
      output << "@echo off"
      output << ""

      # Convert variables
      ast.variables.each do |var|
        output << convert_variable(var)
      end
      output << "" if ast.variables.any?

      # Convert rules
      ast.rules.each do |rule|
        output << convert_rule(rule)
      end

      # Add main entry point
      if ast.rules.any? { |rule| rule.target == "all" }
        output << ""
        output << ":main"
        output << "call :all"
        output << "goto :eof"
      end

      output.join("\r\n")
    end

    private def convert_variable(var : MakefileVariable) : String
      "set #{var.name}=#{expand_makefile_variables(var.value)}"
    end

    private def convert_rule(rule : MakefileRule) : String
      output = [] of String

      # Rule label - expand variables in target name
      expanded_target = expand_makefile_variables(rule.target)
      output << ":#{expanded_target}"

      # Handle dependencies - expand variables in dependency names
      if rule.dependencies.any?
        rule.dependencies.each do |dep|
          expanded_dep = expand_makefile_variables(dep)
          output << "call :#{expanded_dep}"
        end
      end

      # Convert commands
      rule.commands.each do |command|
        converted = convert_command(command)
        output << converted unless converted.empty?
      end

      output << "goto :eof"
      output.join("\r\n")
    end

    private def convert_command(command : String) : String
      # Handle automatic variables
      command = expand_automatic_variables(command)

      # Expand Makefile variables
      command = expand_makefile_variables(command)

      # Convert shell commands to batch
      convert_shell_command(command)
    end

    private def expand_automatic_variables(command : String) : String
      # Basic automatic variable expansion
      # Note: This is simplified - in a real implementation, we'd need context
      command
        .gsub("$@", "%target%")
        .gsub("$<", "%first_dep%")
        .gsub("$^", "%all_deps%")
    end

    private def expand_makefile_variables(text : String) : String
      # Simple variable expansion - replace $(VAR) with %VAR%
      text.gsub(/\$\(([a-zA-Z_][a-zA-Z0-9_]*)\)/) { "%#{$1}%" }
    end

    private def convert_shell_command(command : String) : String
      # For now, delegate to shell converter logic
      # In a real implementation, we'd use command mappings
      shell_converter = ShellConverter.new
      shell_converter.convert_line(command)
    end
  end
end
