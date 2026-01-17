module Shell2Batch
  # Converter specifically for shell scripts
  class ShellConverter < BaseConverter
    @functions = {} of String => String

    def convert(content : String) : String
      parse_functions(content)
      run(content, true)
    end

    def convert_line(line : String) : String
      if line.includes?(SHELL2BATCH_PREFIX)
        index = line.index!(SHELL2BATCH_PREFIX).to_i + SHELL2BATCH_PREFIX.size
        windows_command = line[index..].strip
      elsif line.starts_with?("#")
        windows_command = "@REM #{line[1..]}"
      else
        shell_command, arguments = if index = line.index(" ")
                                     {line[0...index], line[index..-1]}
                                   else
                                     {line, ""}
                                   end

        arguments = arguments.strip

        # Check if this is a function call
        if @functions.has_key?(shell_command)
          # Strip quotes from arguments for function calls
          stripped_args = arguments.split(' ').map { |arg| strip_quotes(arg) }.join(' ')
          return "call :#{shell_command} #{stripped_args}"
        end

        # Try to find a command mapping first
        mapping = CommandMappings.find(shell_command)

        if mapping
          # Use the mapping for simple commands
          windows_command = mapping.windows_command
          flag_mappings = mapping.flag_mappings
          pre_arguments = mapping.pre_arguments
          post_arguments = mapping.post_arguments
          modify_path_separator = mapping.modify_path_separator
        else
          # Handle complex commands with specific handlers
          command_tuple = case shell_command
                          when "cp"
                            handle_cp(arguments)
                          when "rm"
                            handle_rm(arguments)
                          when "ln"
                            handle_ln(arguments)
                          when "curl"
                            handle_curl(arguments)
                          when "unzip"
                            handle_unzip(arguments)
                          when "sudo"
                            handle_sudo(arguments)
                          when "echo"
                            handle_echo(arguments)
                          when "cd"
                            handle_cd(arguments)
                          when "ls"
                            handle_ls(arguments)
                          when "touch"
                            handle_touch(arguments)
                          when "sleep"
                            handle_sleep(arguments)
                          when "md5sum"
                            handle_hash_command(arguments, "MD5")
                          when "sha1sum"
                            handle_hash_command(arguments, "SHA1")
                          when "sha256sum"
                            handle_hash_command(arguments, "SHA256")
                          else
                            # Default case - no special handling
                            {shell_command, [] of Tuple(String, String), [] of String, [] of String, false}
                          end

          windows_command = command_tuple[0].to_s
          flag_mappings = command_tuple[1].as(Array(Tuple(String, String)))
          pre_arguments = command_tuple[2].as(Array(String))
          post_arguments = command_tuple[3].as(Array(String))
          modify_path_separator = command_tuple[4]
        end

        # Modify paths
        if modify_path_separator
          arguments = convert_path_separators(arguments)
        end
        windows_command = convert_path_separators(windows_command)

        # Special handling for ln commands - reorder arguments for mklink
        # ln -s target link_name → mklink link_name target
        if shell_command == "ln" && arguments =~ /-s/
          clean_args = arguments.gsub(/-s\s*/, "").strip
          args_parts = clean_args.split
          if args_parts.size >= 2
            # Reorder arguments: target becomes link, link_name becomes target
            reordered_args = [args_parts[1], args_parts[0]] + args_parts[2..-1]
            arguments = reordered_args.join(" ")
          end
        end

        # Special handling for touch command - needs filename+,, filename format
        if shell_command == "touch"
          windows_command = "copy /B"
          windows_arguments = "#{arguments}+,, #{arguments}"
          return windows_command + " " + windows_arguments
        end

        # For commands that use post_arguments or construct complete commands, we should clear the original arguments
        # to avoid duplicating them
        should_clear_original_args = (post_arguments.size > 0 || shell_command.in?(["sleep"])) && shell_command.in?(["ln", "unzip", "curl", "sudo", "touch", "md5sum", "sha1sum", "sha256sum", "sleep"])

        windows_arguments = should_clear_original_args ? "" : arguments.dup

        # Add pre arguments
        if pre_arguments.size > 0
          windows_arguments = add_arguments(windows_arguments, pre_arguments, true)
        end

        # Replace flags
        if flag_mappings.size > 0
          windows_arguments = replace_flags(windows_arguments, flag_mappings)
        end

        # Replace vars
        windows_arguments = replace_vars(windows_arguments) if windows_arguments.size > 0

        windows_command = replace_vars(windows_command)

        # Add post arguments
        windows_arguments = if post_arguments.size > 0
                              add_arguments(windows_arguments, post_arguments, false)
                            else
                              windows_arguments
                            end

        windows_command = if windows_arguments.size > 0
                            command = String::Builder.new(windows_command)
                            command << " "
                            # Strip quotes from arguments for certain commands
                            if shell_command == "echo"
                              # Strip quotes from the entire arguments string
                              command << strip_quotes(windows_arguments)
                            else
                              command << windows_arguments
                            end
                            command.to_s
                          else
                            windows_command
                          end
        windows_command
      end
    end

    # Parse shell functions from the script content
    private def parse_functions(content : String)
      lines = content.lines
      i = 0
      while i < lines.size
        line = lines[i].strip

        # Check for function definition patterns
        if match = line.match(/^\s*(\w+)\s*\(\s*\)\s*\{$/) || line.match(/^\s*function\s+(\w+)\s*\{$/) || line.match(/^\s*function\s+(\w+)\s*\(\s*\)\s*\{$/)
          func_name = match[1]
          body, new_index = extract_function_body(lines, i)
          @functions[func_name] = body
          i = new_index
        else
          i += 1
        end
      end
    end

    # Extract function body by tracking balanced braces
    private def extract_function_body(lines : Array(String), start_index : Int32) : Tuple(String, Int32)
      body_lines = [] of String
      brace_count = 1 # Start with 1 for the opening brace we already found
      i = start_index + 1

      while i < lines.size
        line = lines[i].strip

        # Count opening and closing braces
        brace_count += line.count('{') - line.count('}')

        if brace_count == 0
          # Found the closing brace for our function
          break
        else
          body_lines << line unless line.empty?
          i += 1
        end
      end

      {body_lines.join("\n"), i}
    end

    # Check if a line is a function definition
    private def is_function_definition?(line : String) : Bool
      !!(line =~ /^\s*(\w+)\s*\(\s*\)\s*\{$/ ||
        line =~ /^\s*function\s+(\w+)\s*\{$/ ||
        line =~ /^\s*function\s+(\w+)\s*\(\s*\)\s*\{$/)
    end

    # Convert a shell function to a batch subroutine
    private def convert_function(name : String, body : String) : String
      # Convert the function body using existing logic
      converted_body = run(body, false)

      # Replace shell parameters ($1, $2, etc.) with batch parameters (%1, %2, etc.)
      converted_body = converted_body.gsub(/\$(\d+)/, "%\\1")

      # Handle shell arithmetic $(( ... )) -> ( ... )
      converted_body = converted_body.gsub(/\$\(\((.+?)\)\)/, "(\\1)")

      # Handle return statements
      converted_body = converted_body.gsub(/return\s+(\d+)/, "exit /b \\1")

      # Build the batch subroutine
      result = String::Builder.new
      result << ":#{name}\n"
      result << converted_body
      result << "\nexit /b 0" # Default return if no explicit return
      result.to_s
    end

    # Converts the provided shell script and returns the windows batch script text.
    private def convert_shell_condition(condition : String) : String
      # Convert shell conditions to batch equivalents
      case condition
      when /^-d\s+(.+)$/
        "exist \"#{$1}\\\""
      when /^-f\s+(.+)$/
        "exist \"#{$1}\""
      when /^-z\s+(.+)$/
        "\"#{$1}\"==\"\""
      when /(.+)\s+=\s+(.+)/
        "\"#{$1}\"==\"#{$2}\""
      when /(.+)\s+!=\s+(.+)/
        "not \"#{$1}\"==\"#{$2}\""
      else
        condition
      end
    end

    private def convert_if_statement(lines : Array(String), current_index : Int32) : Tuple(String, Int32)
      result = [] of String
      index = current_index

      while index < lines.size
        line = lines[index].strip

        case line
        when /^if\s+\[\s+(.+)\s+\];\s+then$/
          condition = convert_shell_condition($1)
          result << "if #{condition} ("
        when /^elif\s+\[\s+(.+)\s+\];\s+then$/
          condition = convert_shell_condition($1)
          result << ") else if #{condition} ("
        when "else"
          result << ") else ("
        when "fi"
          result << ")"
          break
        else
          result << "  #{convert_line(line)}" unless line.empty?
        end

        index += 1
      end

      {result.join("\n"), index}
    end

    def run(script : String, is_main_script : Bool = true) : String
      lines = script.split('\n')
      windows_batch = [] of String

      # Add admin check if script contains sudo or mklink commands
      needs_admin = script.includes?("sudo") || script.includes?("mklink")
      if needs_admin && is_main_script
        windows_batch << "@echo off"
        windows_batch << "NET SESSION >nul 2>&1"
        windows_batch << "if %ERRORLEVEL% neq 0 ("
        windows_batch << "    echo Requesting administrative privileges..."
        windows_batch << "    powershell -Command \"Start-Process '%~dpnx0' -Verb RunAs\""
        windows_batch << "    exit /b"
        windows_batch << ")"
        windows_batch << "@REM Script continues with admin privileges"
      else
        # Only add @echo off if script contains multiple actual commands (not just comments)
        command_lines = script.split('\n').select { |line|
          line = line.strip
          !line.empty? && !line.starts_with?("#")
        }
        # Don't add @echo off for simple multi-line scripts (preserve test expectations)
        # windows_batch << "@echo off" if command_lines.size > 1
      end

      i = 0
      while i < lines.size
        line = lines[i]
        stripped_line = line.strip

        if stripped_line.empty?
          windows_batch << ""
        elsif stripped_line.starts_with?("if [")
          converted, new_index = convert_if_statement(lines, i)
          windows_batch << converted
          i = new_index
        elsif is_function_definition?(stripped_line) && is_main_script
          # Skip function definitions during main script processing
          # They're already parsed and will be converted later
          _, new_index = extract_function_body(lines, i)
          i = new_index
        else
          windows_batch << convert_line(stripped_line)
        end

        i += 1
      end

      # Only add download function if curl command was used
      download_function = if script.includes?("curl") && is_main_script
                            <<-BATCH
        REM Function to download a file using bitsadmin
        :download
        setlocal
        set "URL=%~1"
        set "OUTPUT=%~2"
        bitsadmin /transfer myDownloadJob /download /priority normal "%URL%" "%OUTPUT%"
        endlocal
        goto :eof

        BATCH
                          else
                            ""
                          end

      # Handle empty script case
      filtered_batch = windows_batch.reject(&.empty?)
      return "" if filtered_batch.empty?

      # Handle single line vs multi-line outputs differently
      result = if filtered_batch.size == 1
                 filtered_batch.first
               else
                 batch_text = filtered_batch.join("\r\n")
                 batch_text += "\r\n" unless batch_text.ends_with?("\r\n")
                 batch_text
               end

      # Add download function if needed
      result += "\r\n" + download_function unless download_function.empty?

      # Add converted functions at the end (only for main script)
      if is_main_script && !@functions.empty?
        result += "\r\ngoto :eof\r\n" # Prevent fall-through to subroutines
        @functions.each do |name, body|
          result += "\r\n" + convert_function(name, body) + "\r\n"
        end
      end

      result += "\r\n" unless result.ends_with?("\r\n") || filtered_batch.size == 1
      result
    end

    # Handler methods for complex commands
    private def handle_cp(arguments : String) : Tuple(String, Array(Tuple(String, String)), Array(String), Array(String), Bool)
      # Check for recursive flag - only match if it's a standalone flag
      if arguments =~ /(^|\s)-[rR](\s|$)/
        {"xcopy", [{"-[rR]", "/E"}], [] of String, [] of String, true}
      else
        {"copy", [] of Tuple(String, String), [] of String, [] of String, true}
      end
    end

    private def handle_rm(arguments : String) : Tuple(String, Array(Tuple(String, String)), Array(String), Array(String), Bool)
      # Check for recursive flag
      if arguments =~ /-([rR][fF]|[fF][rR])/
        {"rmdir", [{"-([rR][fF]|[fF][rR]) ", "/S /Q "}], [] of String, [] of String, true}
      elsif arguments =~ /-[rR]+/
        {"rmdir", [{"-[rR]+ ", "/S "}], [] of String, [] of String, true}
      elsif arguments =~ /-[fF]/
        {"del", [{"-[fF] ", "/Q "}], [] of String, [] of String, true}
      else
        {"del", [] of Tuple(String, String), [] of String, [] of String, true}
      end
    end

    private def handle_ln(arguments : String) : Tuple(String, Array(Tuple(String, String)), Array(String), Array(String), Bool)
      # Check for symbolic vs hard link
      if arguments =~ /-s/
        {"mklink", [] of Tuple(String, String), [] of String, [] of String, false}
      elsif arguments =~ /-d/
        {"mklink /D", [] of Tuple(String, String), [] of String, [] of String, false}
      else
        {"mklink /H", [] of Tuple(String, String), [] of String, [] of String, false}
      end
    end

    private def handle_curl(arguments : String) : Tuple(String, Array(Tuple(String, String)), Array(String), Array(String), Bool)
      {"call :download", [] of Tuple(String, String), [] of String, [] of String, true}
    end

    private def handle_unzip(arguments : String) : Tuple(String, Array(Tuple(String, String)), Array(String), Array(String), Bool)
      {"powershell -command \"Expand-Archive", [] of Tuple(String, String), [] of String, ["-Force\""], false}
    end

    private def handle_sudo(arguments : String) : Tuple(String, Array(Tuple(String, String)), Array(String), Array(String), Bool)
      {"runas /user:Administrator", [] of Tuple(String, String), [] of String, ["\""], false}
    end

    private def handle_echo(arguments : String) : Tuple(String, Array(Tuple(String, String)), Array(String), Array(String), Bool)
      {"echo", [] of Tuple(String, String), [] of String, [] of String, false}
    end

    private def handle_cd(arguments : String) : Tuple(String, Array(Tuple(String, String)), Array(String), Array(String), Bool)
      {"cd", [] of Tuple(String, String), [] of String, [] of String, true}
    end

    private def handle_ls(arguments : String) : Tuple(String, Array(Tuple(String, String)), Array(String), Array(String), Bool)
      {"dir", [] of Tuple(String, String), [] of String, [] of String, true}
    end

    private def handle_touch(arguments : String) : Tuple(String, Array(Tuple(String, String)), Array(String), Array(String), Bool)
      # For touch, we need to duplicate the filename: copy /B filename+,, filename
      # We'll handle this by using pre_arguments to add the filename with +,, suffix
      # and post_arguments to add the filename again
      {"copy /B", [] of Tuple(String, String), ["#{arguments}+,,"], [arguments], true}
    end

    # Handler for sleep command - convert seconds to timeout format
    private def handle_sleep(arguments : String) : Tuple(String, Array(Tuple(String, String)), Array(String), Array(String), Bool)
      # Extract and validate sleep duration
      duration = extract_sleep_duration(arguments)

      # Return command with empty arguments to prevent duplication
      {"timeout /t #{duration}", [] of Tuple(String, String), [] of String, [] of String, false}
    end

    private def extract_sleep_duration(arguments : String) : String
      # Handle various sleep formats
      case arguments.strip
      when /^(\d+)$/
        $1 # "10" → "10"
      when /^(\d+)s$/
        $1 # "10s" → "10"
      when /^(\d+)m$/
        ($1.to_i * 60).to_s # "1m" → "60"
      when /^(\d+)h$/
        ($1.to_i * 3600).to_s # "1h" → "3600"
      when /^(\d+\.\d+)$/
        # Windows timeout only supports integers, so round down
        $1.split('.')[0] # "0.5" → "0"
      when /^(\d+\.\d+)s$/
        $1.split('.')[0] # "0.5s" → "0"
      when ""
        "1" # Default for sleep with no arguments
      else
        "1" # Default fallback for malformed arguments
      end
    end

    # Handler for md5sum/sha1sum/sha256sum commands
    private def handle_hash_command(arguments : String, hash_type : String) : Tuple(String, Array(Tuple(String, String)), Array(String), Array(String), Bool)
      {"certutil -hashfile", [] of Tuple(String, String), [hash_type], [arguments], true}
    end
  end
end
