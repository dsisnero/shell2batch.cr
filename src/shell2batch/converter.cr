require "regex"

class String
  def split_at(idx : Int32)
    {self[0...idx], self[idx..-1]}
  end
end

module Shell2Batch

  def self.convert(script : String)
    Converter.run(script)
  end
  
  class Converter
    SHELL2BATCH_PREFIX = "# shell2batch:"

    def self.run(script : String)
      conv = new()
      conv.run(script)
    end

    def replace_flags(arguments : String, flags_mappings : Array(Tuple(String, String))) : String
      windows_arguments = arguments.dup

      flags_mappings.each do |shell_flag, windows_flag|
        shell_regex = Regex.new(shell_flag)

        if shell_regex.match(windows_arguments)
          windows_arguments = windows_arguments.sub(shell_regex, windows_flag)
          # shell_regex.replace(windows_arguments, windows_flag).to_s
        end
      end

      windows_arguments
    end

    def convert_var(value : String, buffer : Array(String))
      case value
      when "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"
        buffer << "%" + value  # Numeric params don't need trailing %
      when "@"
        buffer << "%*"
      else
        buffer << "%" + value + "%"  # Named vars need both % markers
      end
    end

    def replace_full_vars(arguments : String) : String
      parts = arguments.split("${")
      buffer = [] of String

      buffer << parts.shift

      parts.each do |part|
        b4, f, after = part.partition("}")
        found = !(f.empty?)

        if found
          convert_var(b4, buffer)
        else
          buffer << b4
        end

        buffer << after if after.size > 0
      end

      buffer.join("")
    end

    def replace_partial_vars(arguments : String) : String
      parts = arguments.split("$")
      buffer = [] of String

      buffer << parts.shift

      parts.each do |part|
        index = part.index(" ")
        before, after =
          if index
            {part[0...index], part[index..-1]}
          else
            {part, ""}
          end

        convert_var(before, buffer)
        buffer << after if after.size > 0
      end

      buffer.join("")
    end

    def replace_vars(arguments : String) : String
      # Special case for $(dirname $0)
      if arguments.includes?("$(dirname $0)")
        return arguments.gsub("$(dirname $0)", "%~dp0")
      end
      
      result = replace_full_vars(arguments)
      result = replace_partial_vars(result)
      
      # Only remove trailing % for echo commands
      if arguments.starts_with?("echo ")
        result.ends_with?("%") ? result[0...-1] : result
      else
        result
      end
    end

    def add_arguments(arguments : String, additional_arguments : Array(String), pre : Bool) : String
      windows_arguments = pre ? String::Builder.new : String::Builder.new(arguments.dup)

      additional_arguments.each do |additional_argument|
        windows_arguments << additional_argument
      end

      if pre
        if arguments.size > 0
          windows_arguments << " "
        end

        windows_arguments << arguments
      end

      windows_arguments.to_s.lstrip
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

        flag_mappings = [] of Tuple(String, String)
        pre_arguments = [] of String
        post_arguments = [] of String
        modify_path_separator = false

        command_tuple = case shell_command
                                                                                                when "trap"
                                                                                                  {"REM trap command not supported in batch", flag_mappings, pre_arguments, post_arguments, false}
                                                                                                when "cd"
                                                                                                  if arguments.includes?("$(dirname $0)")
                                                                                                    {"cd /d %~dp0", flag_mappings, pre_arguments, post_arguments, false}
                                                                                                  else
                                                                                                    {"cd", flag_mappings, pre_arguments, post_arguments, true}
                                                                                                  end
                                                                                                when "cp"
                                                                                                  # Determine whether to use xcopy or copy based on the -r flag.
                                                                                                  win_cmd = if /(^|\s)-[^ ]*[rR]/.match(arguments)
                                                                                                              "xcopy"
                                                                                                            else
                                                                                                              "copy"
                                                                                                            end

                                                                                                  flg_mappings = win_cmd == "xcopy" ? [{"-[rR]", "/E"}] : [] of Tuple(String, String)
                                                                                                  {win_cmd, flg_mappings, [] of String, [] of String, true}
                                                                                                when "curl"
                                                                                                  if arguments.includes?("-o")
                                                                                                    # Extract output file and URL from curl command
                                                                                                    args = arguments.split
                                                                                                    output_index = args.index("-o")
                                                                                                    if output_index && args.size > output_index + 2
                                                                                                      output_file = args[output_index + 1]
                                                                                                      url = args[output_index + 2]
                                                                                                      {"call :download", [] of Tuple(String, String), [] of String, ["\"#{url}\"", "\"#{output_file}\""], false}
                                                                                                    else
                                                                                                      {"call :download", flag_mappings, pre_arguments, post_arguments, true}
                                                                                                    end
                                                                                                  else
                                                                                                    {"call :download", flag_mappings, pre_arguments, post_arguments, true}
                                                                                                  end
                                                                                                when "unzip"
                                                                                                  # Convert to PowerShell Expand-Archive
                                                                                                  args = arguments.strip
                                                                                                  if args.includes?(" ")
                                                                                                    file, dest = args.split(" ", 2)
                                                                                                    {"powershell -command \"Expand-Archive", [] of Tuple(String, String), [] of String, ["-Path '#{file}'", "-DestinationPath '#{dest}'", "-Force\""], false}
                                                                                                  else
                                                                                                    {"powershell -command \"Expand-Archive", [] of Tuple(String, String), [] of String, ["-Path '#{args}'", "-Force\""], false}
                                                                                                  end
                                                                                                when "./playwright-cli"
                                                                                                  {"playwright-cli", flag_mappings, pre_arguments, post_arguments, true}
                                                                                                when "mv"
                                                                                                  {"move", flag_mappings, pre_arguments, post_arguments, true}
                                                                                                when "ls"
                                                                                                  # Extract any path argument after the flags
                                                                                                  path = arguments.split(/\s+-[a-zA-Z]+/).last?.try(&.strip)
                                                                                                  {"dir", [] of Tuple(String, String), [] of String, path ? [path] : [] of String, true}
                                                                                                when "rm"
                                                                                                  # Determine whether to use rmdir or del based on flags.
                                                                                                  win_cmd = if /-[a-zA-Z]*[rR][a-zA-Z]* /.match(arguments)
                                                                                                              "rmdir"
                                                                                                            else
                                                                                                              "del"
                                                                                                            end

                                                                                                  if win_cmd == "rmdir"
                                                                                                    flg_mappings = [{"-([rR][fF]|[fF][rR]) ", "/S /Q "}, {"-[rR]+ ", "/S "}]
                                                                                                  else
                                                                                                    flg_mappings = [{"-[fF] ", "/Q "}]
                                                                                                  end

                                                                                                  {win_cmd, flg_mappings, pre_arguments, post_arguments, true}
                                                                                                when "mkdir"
                                                                                                  {"mkdir", [{"-[pP]", ""}], pre_arguments, post_arguments, true}
                                                                                                when "clear"
                                                                                                  {"cls", flag_mappings, pre_arguments, post_arguments, false}
                                                                                                when "grep"
                                                                                                  {"find", flag_mappings, pre_arguments, post_arguments, false}
                                                                                                when "pwd"
                                                                                                  {"chdir", flag_mappings, pre_arguments, post_arguments, false}
                                                                                                when "export"
                                                                                                  {"set", flag_mappings, pre_arguments, post_arguments, false}
                                                                                                when "unset"
                                                                                                  {"set", flag_mappings, pre_arguments, Array{"="}, false}
                                                                                                when "touch"
                                                                                                  file_arg = arguments.gsub("/", "\\") + "+,,"
                                                                                                  {"copy", flag_mappings, ["/B ", file_arg.dup], post_arguments, true}
                                                                                                when "set"
                                                                                                  {"@echo", [{"-x", "on"}, {"\\+x", "off"}], pre_arguments, post_arguments, false}
                                                                                                when "ln"
                                                                                                  if /-[a-zA-Z]*s[a-zA-Z]* /.match(arguments) || arguments.starts_with?("-s")
                                                                                                    args = arguments.gsub(/-[a-zA-Z]*s[a-zA-Z]* /, "").strip
                                                                                                    if args.includes?(" ")
                                                                                                      target, link = args.split(" ", 2)
                                                                                                      # Add /D flag if target ends with \ or / indicating a directory
                                                                                                      is_dir = target.ends_with?("/") || target.ends_with?("\\")
                                                                                                      target = target.rstrip("/\\")  # Remove trailing slashes
                                                                                                      cmd = is_dir ? "mklink /D" : "mklink"
                                                                                                      {cmd, [] of Tuple(String, String), [] of String, [link, target], false}
                                                                                                    else
                                                                                                      {"REM Error: ln -s requires both target and link name", [] of Tuple(String, String), [] of String, [] of String, false}
                                                                                                    end
                                                                                                  else
                                                                                                    # Hard link handling
                                                                                                    args = arguments.strip
                                                                                                    if args.includes?(" ")
                                                                                                      target, link = args.split(" ", 2)
                                                                                                      {"mklink /H", [] of Tuple(String, String), [] of String, [link, target], false}
                                                                                                    else
                                                                                                      {"REM Error: ln requires both target and link name", [] of Tuple(String, String), [] of String, [] of String, false}
                                                                                                    end
                                                                                                  end
                                                                                                when "sudo"
                                                                                                  # Extract the actual command after sudo
                                                                                                  cmd = arguments.strip
                                                                                                  if cmd.starts_with?("install") || cmd.starts_with?("cp") || cmd.starts_with?("rm")
                                                                                                    # For file operations, use runas
                                                                                                    {"runas /user:Administrator", flag_mappings, pre_arguments, ["\"#{cmd}\""], false}
                                                                                                  else
                                                                                                    # For other commands, just remove sudo and let Windows UAC handle it
                                                                                                    convert_line(cmd)
                                                                                                  end
                                                                                                when "echo"
                                                                                                  # Handle redirection and variable expansion
                                                                                                  cleaned_args = arguments.strip
                                                                                                  if cleaned_args.includes?(">")
                                                                                                    command, file = cleaned_args.split(">", 2)
                                                                                                    command = command.gsub(/^"(.*)"$/, "\\1").strip
                                                                                                    command = replace_vars(command)
                                                                                                    {"echo", [] of Tuple(String, String), [] of String, ["#{command} > #{file.strip}"], false}
                                                                                                  else
                                                                                                    cleaned_args = cleaned_args.gsub(/^"(.*)"$/, "\\1")
                                                                                                    cleaned_args = replace_vars(cleaned_args)
                                                                                                    {"echo", [] of Tuple(String, String), [] of String, [cleaned_args], false}
                                                                                                  end
                                                                                                else
                                                                                                  {shell_command, flag_mappings, [] of String, [] of String, false}
                                                                                                end

        # Unpack the tuple ensuring Array(String) types
        windows_command = command_tuple[0].to_s
        flags_mappings = command_tuple[1].as(Array(Tuple(String,String)))
        pre_arguments = command_tuple[2].as(Array(String))
        post_arguments = command_tuple[3].as(Array(String))
        modify_path_separator = command_tuple[4]

        # Modify paths
        if modify_path_separator
          # Don't modify URLs
          if !arguments.includes?("http://") && !arguments.includes?("https://")
            arguments = arguments.gsub("/", "\\")
          end
        end
        windows_command = windows_command.to_s.gsub("/", "\\")

        windows_arguments = arguments.dup

        # Add pre arguments
        if pre_arguments.size > 0
          windows_arguments = add_arguments(windows_arguments, pre_arguments, true)
        end

        # Replace flags
        if flags_mappings.size > 0
          windows_arguments = replace_flags(arguments, flags_mappings)
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
                            command << windows_arguments
                            command.to_s
                          else
                            windows_command
                          end
        windows_command
      end
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

    def run(script : String) : String
      lines = script.split('\n')
      windows_batch = [] of String

      # Add admin check if script contains sudo or mklink commands
      needs_admin = script.includes?("sudo") || script.includes?("mklink")
      if needs_admin
        windows_batch << "@echo off"
        windows_batch << "NET SESSION >nul 2>&1"
        windows_batch << "if %ERRORLEVEL% neq 0 ("
        windows_batch << "    echo Requesting administrative privileges..."
        windows_batch << "    powershell -Command \"Start-Process '%~dpnx0' -Verb RunAs\""
        windows_batch << "    exit /b"
        windows_batch << ")"
        windows_batch << "@REM Script continues with admin privileges"
      else
        # Only add @echo off if script contains commands
        windows_batch << "@echo off" unless script.strip.empty?
      end

      i = 0
      while i < lines.size
        line = lines[i].strip
        
        if line.starts_with?("if [")
          converted, new_index = convert_if_statement(lines, i)
          windows_batch << converted
          i = new_index
        else
          windows_batch << convert_line(line) unless line.empty?
        end
        
        i += 1
      end

      # Only add download function if curl command was used
      download_function = if script.includes?("curl")
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

      # Join with Windows line endings and proper spacing
      result = windows_batch.reject(&.empty?).join("\r\n")
      result += "\r\n" + download_function unless download_function.empty?
      result += "\r\n" unless result.ends_with?("\r\n")
      result
    end
  end
end
