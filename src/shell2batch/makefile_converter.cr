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
    @variables_hash = {} of String => String
    @targets = Set(String).new
    @functions = Set(String).new
    @complex_variable_functions = {} of String => String

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
          @variables_hash[name] = value
          current_rule = nil
          next
        end

        # Handle rules (target: dependencies) including pattern rules
        if line =~ /^\s*([a-zA-Z0-9%._$()\/]+)\s*:(.*)$/
          target = $1
          deps_str = $2.strip
          dependencies = deps_str.empty? ? [] of String : deps_str.split.map(&.strip)

          # Check if this is a phony target
          phony = target == ".PHONY"

          # Check if this is a pattern rule (contains %)
          pattern_rule = target.includes?("%")

          current_rule = MakefileRule.new(target, dependencies, [] of String, phony)
          unless phony
            ast.rules << current_rule
            # For pattern rules, we can't add to targets set directly
            # because the pattern needs to be matched against actual targets
            unless pattern_rule
              # Resolve target name and add to targets set
              resolved_target = resolve_variable(target, for_target: true)
              @targets.add(resolved_target)
            end
          end
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

      # Convert rules (excluding .PHONY which is handled separately)
      ast.rules.each do |rule|
        output << convert_rule(rule) unless rule.phony
      end

      # Add main entry point
      if ast.rules.any? { |rule| rule.target == "all" && !rule.phony }
        output << ""
        output << ":main"
        output << "call :all"
        output << "goto :eof"
      end

      output.join("\r\n")
    end

    private def convert_variable(var : MakefileVariable) : String
      # Check if this variable contains complex expressions
      if var.value.includes?("$(wildcard") || var.value.includes?("$(patsubst") || var.value =~ /\$\([a-zA-Z_][a-zA-Z0-9_]*:\./
        # This is a complex variable that needs batch-style handling
        return handle_complex_variable(var)
      else
        # Simple variable - just resolve nested variables
        resolved_value = resolve_variable(var.value)
        "set #{var.name}=#{resolved_value}"
      end
    end

    private def convert_rule(rule : MakefileRule) : String
      output = [] of String

      # Check if this is a pattern rule (contains %)
      if rule.target.includes?("%")
        # Convert pattern rule to a batch function
        return convert_pattern_rule(rule)
      end

      # Rule label - resolve variables in target name to actual values
      resolved_target = resolve_variable(rule.target, for_target: true)
      output << ":#{resolved_target}"

      # Handle dependencies - check if they're targets or files
      if rule.dependencies.any?
        rule.dependencies.each do |dep|
          # Check if this is a complex variable reference (e.g., $(OBJECTS))
          # Check the original dependency string before resolving
          if dep =~ /\$\(([a-zA-Z_][a-zA-Z0-9_]*)\)/
            var_name = $1
            # Check if we have a function for this complex variable
            if function_name = @complex_variable_functions[var_name]?
              # Call the build function for this complex variable
              output << "call :#{function_name}"
              next
            end
          end

          resolved_dep = resolve_variable(dep)

          # Split by spaces in case it's a list (e.g., "main.o utils.o")
          resolved_dep.split.each do |single_dep|
            # Check if this dependency is a known target
            if @targets.includes?(single_dep)
              # It's a target - call it
              output << "call :#{single_dep}"
            elsif single_dep.ends_with?(".o") && function_exists?("compile_c_to_o")
              # It's an object file and we have a compile function
              # Need to determine the corresponding source file
              # For now, assume .c file with same name
              source_file = single_dep.gsub(".o", ".c")
              output << "call :compile_c_to_o #{source_file} #{single_dep}"
            else
              # It's a file dependency - in Make, this would trigger the rule
              # if the file doesn't exist or is older than target
              # For batch, we could add a file existence check, but for now
              # we'll just note it as a dependency
              # output << "@REM Dependency: #{single_dep}"
            end
          end
        end
      end

      # Convert commands
      rule.commands.each do |command|
        converted = convert_command(command, resolved_target, rule.dependencies.map { |d| resolve_variable(d) })
        output << converted unless converted.empty?
      end

      # If this target depends on pattern-generated files, add build commands
      # For example, if target depends on $(OBJECTS) where OBJECTS uses patsubst
      add_pattern_build_commands(output, rule, resolved_target)

      output << "goto :eof"
      output.join("\r\n")
    end

    private def convert_command(command : String, target : String = "", dependencies : Array(String) = [] of String) : String
      # Handle @ prefix (suppresses command output in Make)
      suppress_output = command.starts_with?("@")
      if suppress_output
        command = command[1..].lstrip
      end

      # Handle automatic variables
      command = expand_automatic_variables(command, target, dependencies)

      # Expand Makefile variables (evaluate functions when possible)
      command = expand_makefile_variables(command, true)

      # Special handling for complex patterns
      # Handle $(patsubst ...) patterns
      command = command.gsub(/\$\(patsubst[^)]+\)/) do |match|
        # Check if this patsubst references a complex variable
        if match =~ /\$\(([a-zA-Z_][a-zA-Z0-9_]*)\)/
          var_name = $1
          # Check if this variable has a corresponding build function
          if function_name = @complex_variable_functions[var_name]?
            # Replace with the output pattern (obj/*.o)
            "obj\\*.o"
          else
            # Unknown variable - try to extract pattern
            if match =~ /,\s*\$\([^)]+\)\s*\)$/
              # Ends with variable reference - replace with generic pattern
              "obj\\*.o"
            else
              match
            end
          end
        else
          # Direct patsubst - replace with generic pattern
          "obj\\*.o"
        end
      end

      # Also handle simple variable references that should be functions
      # Handle both $(VAR) and %VAR% syntax
      command = command.gsub(/\$\(([a-zA-Z_][a-zA-Z0-9_]*)\)/) do |match|
        var_name = $1
        # Check if this variable has a corresponding build function
        if function_name = @complex_variable_functions[var_name]?
          # Replace with the output of the function (obj/*.o for now)
          "obj\\*.o"
        else
          match
        end
      end

      command = command.gsub(/%([a-zA-Z_][a-zA-Z0-9_]*)%/) do |match|
        var_name = $1
        # Check if this variable has a corresponding build function
        if function_name = @complex_variable_functions[var_name]?
          # Replace with the output of the function (obj/*.o for now)
          "obj\\*.o"
        else
          match
        end
      end

      # Convert shell commands to batch
      converted = convert_shell_command(command)

      # In batch, we use @ at beginning of line to suppress output
      if suppress_output && !converted.starts_with?("@")
        "@#{converted}"
      else
        converted
      end
    end

    private def expand_automatic_variables(command : String, target : String = "", dependencies : Array(String) = [] of String) : String
      # Automatic variable expansion with context
      result = command.dup

      # $@ - target name
      if target && result.includes?("$@")
        result = result.gsub("$@", target)
      end

      # $< - first dependency
      if dependencies.any? && result.includes?("$<")
        first_dep = dependencies.first
        result = result.gsub("$<", first_dep)
      end

      # $^ - all dependencies
      if dependencies.any? && result.includes?("$^")
        all_deps = dependencies.join(" ")
        result = result.gsub("$^", all_deps)
      end

      # $? - newer dependencies
      # $* - stem (for pattern rules)
      # $$ - literal $

      # Handle $$ for literal dollar sign
      result = result.gsub("$$", "$")

      result
    end

    private def expand_makefile_variables(text : String, evaluate_functions : Bool = false) : String
      # Expand Makefile variables and functions
      result = text.dup

      # Handle simple variables: $(VAR)
      result = result.gsub(/\$\(([a-zA-Z_][a-zA-Z0-9_]*)\)/) do |match|
        var_name = $1
        # If we have the variable value and we're evaluating functions, use it
        if evaluate_functions && (var_value = @variables_hash[var_name]?)
          var_value
        else
          "%#{var_name}%"
        end
      end

      # Handle functions: $(function args)
      # Try to evaluate them if evaluate_functions is true
      result = expand_makefile_functions(result, evaluate_functions)

      result
    end

    private def expand_makefile_functions(text : String, evaluate : Bool) : String
      result = text.dup

      # Keep expanding until no more function calls
      changed = true
      while changed
        changed = false
        original = result

        # Handle suffix replacement patterns: $(VAR:.c=.o)
        result = result.gsub(/\$\(([a-zA-Z_][a-zA-Z0-9_]*):\.([^=]+)=\.([^)]+)\)/) do |match|
          var_name = $1
          from_suffix = $2
          to_suffix = $3
          
          if evaluate && (source_value = @variables_hash[var_name]?)
            # Replace .c with .o in each file
            files = source_value.split
            transformed_files = files.map do |file|
              if file.ends_with?(".#{from_suffix}")
                file[0...-(".#{from_suffix}".size)] + ".#{to_suffix}"
              else
                file
              end
            end
            transformed_files.join(" ")
          else
            # Can't evaluate - return as variable reference
            "%#{var_name}%"
          end
        end

        # Handle patsubst function first (it may contain other functions)
        result = result.gsub(/\$\(patsubst\s+([^,]+),\s*([^,]+),\s*([^)]+)\)/) do |match|
          pattern = $1.strip
          replacement = $2.strip
          text_list = $3.strip
          if evaluate
            # First expand any nested functions in text_list
            expanded_list = expand_makefile_functions(text_list, evaluate)
            # Then evaluate patsubst
            evaluate_patsubst(pattern, replacement, expanded_list)
          else
            # Can't evaluate - return as-is
            match
          end
        end

        # Handle wildcard function
        result = result.gsub(/\$\(wildcard\s+([^)]+)\)/) do |match|
          pattern = $1.strip
          if evaluate
            # Try to actually evaluate the wildcard
            evaluate_wildcard(pattern)
          else
            # Convert to batch equivalent
            "dir /b #{pattern} 2>nul"
          end
        end

        changed = original != result
      end

      result
    end

    private def evaluate_wildcard(pattern : String) : String
      # Resolve any variables in the pattern
      resolved_pattern = resolve_variable(pattern)
      # For now, just convert to batch command
      # In a more advanced implementation, we could actually run the command
      # and get the file list at conversion time
      "dir /b #{resolved_pattern} 2>nul"
    end

    private def evaluate_patsubst(pattern : String, replacement : String, text_list : String) : String
      # Evaluate patsubst pattern

      # Check if text_list is a wildcard command
      if text_list.starts_with?("dir /b ") && text_list.ends_with?(" 2>nul")
        # It's a wildcard command - we can't evaluate it statically
        # Convert to a batch construct that does both wildcard and patsubst
        pattern_without_dir = text_list["dir /b ".size...-(" 2>nul".size)]
        return convert_wildcard_patsubst(pattern, replacement, pattern_without_dir)
      end

      # If pattern contains % and replacement contains %, it's a pattern substitution
      if pattern.includes?("%") && replacement.includes?("%")
        pattern_prefix = pattern.split("%").first
        pattern_suffix = pattern.split("%").last
        replacement_prefix = replacement.split("%").first
        replacement_suffix = replacement.split("%").last

        # Split the text list by spaces
        items = text_list.split
        transformed_items = items.map do |item|
          if item.starts_with?(pattern_prefix) && item.ends_with?(pattern_suffix)
            # Extract the stem
            stem = item[pattern_prefix.size...-pattern_suffix.size]
            "#{replacement_prefix}#{stem}#{replacement_suffix}"
          else
            item
          end
        end

        transformed_items.join(" ")
      else
        # Simple text replacement
        text_list.gsub(pattern, replacement)
      end
    end

    private def convert_wildcard_patsubst(pattern : String, replacement : String, wildcard_pattern : String) : String
      # Convert $(patsubst pattern,replacement,$(wildcard ...)) to batch
      # This creates a for loop that processes each file

      # Extract pattern parts
      if pattern.includes?("%") && replacement.includes?("%")
        pattern_prefix = pattern.split("%").first
        pattern_suffix = pattern.split("%").last
        replacement_prefix = replacement.split("%").first
        replacement_suffix = replacement.split("%").last

        # Create a batch for loop that does the transformation
        # Note: This is a complex batch construct that would need to be
        # used differently than a simple variable
        # For now, return a placeholder
        "FOR_PATSUBST_#{pattern}_#{replacement}_#{wildcard_pattern}"
      else
        # Simple replacement
        "dir /b #{wildcard_pattern} 2>nul"
      end
    end

    private def function_exists?(name : String) : Bool
      @functions.includes?(name)
    end

    private def add_pattern_build_commands(output : Array(String), rule : MakefileRule, target_name : String)
      # Check if this rule depends on pattern-generated files
      rule.dependencies.each do |dep|
        resolved_dep = resolve_variable(dep)
        # Check if this is the common pattern: $(patsubst ... $(wildcard ...))
        if resolved_dep =~ /\$\(patsubst.*\$\(wildcard/
          # Extract the pattern
          if match = resolved_dep.match(/\$\(patsubst\s+([^,]+),\s*([^,]+),\s*\$\(wildcard\s+([^)]+)\)\)/)
            src_pattern = match[1]  # e.g., "src/%.c"
            obj_pattern = match[2]  # e.g., "obj/%.o"
            wildcard_pattern = match[3]  # e.g., "src/*.c"

            # Generate build commands
            output << "rem Build object files"
            output << "if not exist obj mkdir obj"
            output << "for /f %%f in ('dir /b #{wildcard_pattern} 2^>nul') do ("
            output << "  %CC% %CFLAGS% -c src\\%%f -o obj\\%%~nf.o"
            output << ")"
          end
        end
      end
    end

    private def convert_pattern_rule(rule : MakefileRule) : String
      output = [] of String

      # Extract pattern from target (e.g., "obj/%.o" -> "%.o")
      target_pattern = rule.target

      # Extract pattern from first dependency if it has one
      dep_pattern = rule.dependencies.first? || ""

      # Create a generic pattern function
      # For obj/%.o: src/%.c pattern, create a compile function
      if target_pattern.ends_with?("%.o") && dep_pattern.ends_with?("%.c")
        function_name = "compile_c_to_o"
        @functions.add(function_name)
        output << ":#{function_name}"
        output << "rem Compile .c file to .o file"
        output << "rem Usage: call :#{function_name} source.c [target.o]"
        output << "set src=%~1"
        output << "if \"%~2\"==\"\" ("
        output << "  set obj=%~n1.o"
        output << ") else ("
        output << "  set obj=%~2"
        output << ")"

        # Convert the commands
        rule.commands.each do |command|
          # Handle @ prefix
          suppress_output = command.starts_with?("@")
          if suppress_output
            command = command[1..].lstrip
          end

          # Expand automatic variables for pattern rule context
          # $< becomes first dependency (src)
          # $@ becomes target (obj)
          command = command.gsub("$<", "%src%")
          command = command.gsub("$@", "%obj%")

          # Expand Makefile variables
          command = expand_makefile_variables(command, false)

          # Convert shell command
          converted = convert_shell_command(command)

          if suppress_output && !converted.starts_with?("@")
            output << "@#{converted}"
          else
            output << converted
          end
        end

        output << "goto :eof"
      else
        # Generic pattern rule - output as comment
        output << "@REM Pattern rule: #{rule.target}: #{rule.dependencies.join(" ")}"
        rule.commands.each do |cmd|
          output << "@REM   #{cmd}"
        end
      end

      output.join("\r\n")
    end

    private def resolve_variable(value : String, for_target : Bool = false) : String
      # Resolve variable references to their actual values
      result = value.dup

      # Also handle %VAR% format (in case expand_makefile_variables was called)
      result = result.gsub(/%([a-zA-Z_][a-zA-Z0-9_]*)%/) do |match|
        var_name = $1
        if var_value = @variables_hash[var_name]?
          var_value
        else
          "%#{var_name}%"
        end
      end

      # Replace $(VAR) with actual value if it exists
      result = result.gsub(/\$\(([a-zA-Z_][a-zA-Z0-9_]*)\)/) do |match|
        var_name = $1
        if var_value = @variables_hash[var_name]?
          var_value
        else
          "%#{var_name}%"
        end
      end

      # Convert common shell commands in variable values
      # This handles cases like RM = rm -rf in Makefiles
      result = convert_shell_commands_in_value(result)

      # If resolving for a target name and the result contains spaces,
      # take only the first part (e.g., "main.o utils.o" -> "main.o")
      if for_target && result.includes?(" ")
        result.split.first
      else
        result
      end
    end

    private def handle_complex_variable(var : MakefileVariable) : String
      # Handle complex variables with wildcard and patsubst functions
      value = var.value

      # Check for suffix replacement patterns: $(VAR:.c=.o)
      if value =~ /\$\(([a-zA-Z_][a-zA-Z0-9_]*):\.([^=]+)=\.([^)]+)\)/
        # This is a suffix replacement pattern like $(SOURCES:.c=.o)
        var_name = $1
        from_suffix = $2
        to_suffix = $3
        
        # Get the source variable value
        if source_value = @variables_hash[var_name]?
          # Check if source_value contains a function (like wildcard)
          if source_value =~ /\$\(wildcard/
            # It's a wildcard function - can't evaluate statically
            # Return a comment with batch equivalent
            if match = source_value.match(/\$\(wildcard\s+([^)]+)\)/)
              wildcard_pattern = match[1]
              return "rem #{var.name} - use: for /f %%f in ('dir /b #{wildcard_pattern} 2^>nul') do echo %%~nf.o"
            else
              return "rem #{var.name} = #{value} (complex expression - needs manual conversion)"
            end
          elsif source_value =~ /\$\(/
            # Some other function - can't evaluate statically
            return "rem #{var.name} = #{value} (complex expression - needs manual conversion)"
          else
            # Replace .c with .o in each file
            # Split by spaces and replace suffix
            files = source_value.split
            transformed_files = files.map do |file|
              if file.ends_with?(".#{from_suffix}")
                file[0...-(".#{from_suffix}".size)] + ".#{to_suffix}"
              else
                file
              end
            end
            
            # Return the transformed list
            return "set #{var.name}=#{transformed_files.join(" ")}"
          end
        else
          # Variable not found yet - might be defined later
          # Return a placeholder that will be resolved later
          return "set #{var.name}=%#{var_name}%"
        end
      end

      # Check for patsubst patterns
      if value =~ /\$\(patsubst/
        # Try to extract the pattern
        # Handle both direct wildcard and variable references
        if match = value.match(/\$\(patsubst\s+([^,]+),\s*([^,]+),\s*([^)]+)\)/)
          src_pattern = match[1]  # e.g., "src/%.c" or "$(SRC_DIR)/%.c"
          obj_pattern = match[2]  # e.g., "obj/%.o" or "$(OBJ_DIR)/%.o"
          source_var = match[3]   # e.g., "$(SOURCES)" or "$(wildcard ...)"

          # Check if source_var is a wildcard or another variable
          if source_var =~ /\$\(wildcard/
            # Extract wildcard pattern
            if wildcard_match = source_var.match(/\$\(wildcard\s+([^)]+)\)/)
              wildcard_pattern = wildcard_match[1]
            else
              wildcard_pattern = source_var
            end
          else
            # It's a variable reference - we need to trace it back
            # For now, assume it's a wildcard pattern
            wildcard_pattern = "src\\*.c"
          end

          # Resolve nested variables in patterns
          resolved_src_pattern = resolve_variable(src_pattern)
          resolved_obj_pattern = resolve_variable(obj_pattern)
          resolved_wildcard_pattern = resolve_variable(wildcard_pattern)

          # Generate a batch function that builds these files
          function_name = "build_#{var.name.downcase}"
          @functions.add(function_name)

          # Store this function name for later use
          @complex_variable_functions ||= {} of String => String
          @complex_variable_functions[var.name] = function_name

          # Return a comment and function definition instead of a variable assignment
          output = [] of String
          output << "rem #{var.name} - complex expression converted to function"
          output << "rem Original: #{var.name} = #{value}"
          output << ":#{function_name}"
          output << "rem Build #{var.name} files"
          output << "if not exist obj mkdir obj"
          output << "for /f %%f in ('dir /b #{resolved_wildcard_pattern} 2^>nul') do ("
          # Build the source and object file paths
          # Convert forward slashes to backslashes for batch
          source_path = resolved_wildcard_pattern.gsub("*.c", "%%f").gsub("/", "\\")
          object_path = resolved_obj_pattern.gsub("%.o", "%%~nf.o").gsub("/", "\\")
          output << "  call :compile_c_to_o #{source_path} #{object_path}"
          output << ")"
          output << "goto :eof"
          return output.join("\r\n")
        end
      end

      # Check for wildcard only
      if value =~ /\$\(wildcard[^)]+\)/
        # Extract the pattern - need to handle nested parentheses
        # Match from wildcard to the matching closing paren
        paren_count = 0
        in_pattern = false
        pattern = ""
        
        # Simple approach: find the matching closing paren
        # Start after "wildcard"
        if idx = value.index("wildcard")
          start_idx = idx + "wildcard".size
          # Skip whitespace
          while start_idx < value.size && value[start_idx].whitespace?
            start_idx += 1
          end
          
          # Now find matching closing paren
          paren_count = 0
          i = start_idx
          while i < value.size
            ch = value[i]
            if ch == '('
              paren_count += 1
            elsif ch == ')'
              if paren_count == 0
                # Found the closing paren for wildcard
                pattern = value[start_idx...i]
                break
              else
                paren_count -= 1
              end
            end
            i += 1
          end
          
          if !pattern.empty?
            # Resolve any variables in the pattern
            resolved_pattern = resolve_variable(pattern)
            # Store the evaluated wildcard command in variables_hash for later reference
            # This allows $(SOURCES) to be expanded to dir /b src/*.c 2>nul
            @variables_hash[var.name] = "dir /b #{resolved_pattern} 2>nul"
            # Return a batch command that lists files
            return "rem #{var.name} - use: dir /b #{resolved_pattern} 2>nul"
          end
        end
      end

      # Fallback - output as comment
      "rem #{var.name} = #{value} (complex expression - needs manual conversion)"
    end

    private def extract_variable_name_from_patsubst(command : String) : String?
      # Try to extract variable name from a patsubst expression
      if match = command.match(/\$\(([a-zA-Z_][a-zA-Z0-9_]*)\)/)
        match[1]
      else
        nil
      end
    end

    private def convert_shell_commands_in_value(value : String) : String
      # Convert shell commands that appear in variable values
      result = value.dup
      
      # Handle rm -rf -> rmdir /S /Q
      if result == "rm -rf"
        result = "rmdir /S /Q"
      elsif result == "mkdir -p"
        result = "mkdir"
      end
      
      # Also resolve variable references
      result = result.gsub(/\$\(([a-zA-Z_][a-zA-Z0-9_]*)\)/) do |match|
        var_name = $1
        if var_value = @variables_hash[var_name]?
          var_value
        else
          match
        end
      end
      
      result
    end

    private def convert_shell_command(command : String) : String
      # For now, delegate to shell converter logic
      # In a real implementation, we'd use command mappings
      shell_converter = ShellConverter.new
      shell_converter.convert_line(command)
    end
  end
end
