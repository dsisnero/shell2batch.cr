require "regex"

class String
  def split_at(idx : Int32)
    {self[0...idx], self[idx..-1]}
  end
end

module Shell2Batch
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
        buffer << "%" + value
      when "@"
        buffer << "%*"
      else
        buffer << "%" + value + "%"
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
      
      # Remove trailing % if it exists (fix for echo commands)
      result = replace_full_vars(arguments)
      result = replace_partial_vars(result)
      result.ends_with?("%") ? result[0...-1] : result
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

        windows_command, flags_mappings, pre_arguments, post_arguments, modify_path_separator = case shell_command
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
                                                                                                      return "call :download \"#{url}\" \"#{output_file}\""
                                                                                                    end
                                                                                                  end
                                                                                                  # Default fallback if -o isn't found
                                                                                                  {"call :download", flag_mappings, pre_arguments, post_arguments, true}
                                                                                                when "unzip"
                                                                                                  {"unzip", flag_mappings, pre_arguments, post_arguments, true}
                                                                                                when "./playwright-cli"
                                                                                                  {"playwright-cli", flag_mappings, pre_arguments, post_arguments, true}
                                                                                                when "mv"
                                                                                                  {"move", flag_mappings, pre_arguments, post_arguments, true}
                                                                                                when "ls"
                                                                                                  # Ignore all flags for ls, just convert to dir
                                                                                                  {"dir", [] of Tuple(String, String), [] of String, [] of String, true}
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
                                                                                                  {"findstr", flag_mappings, pre_arguments, post_arguments, false}
                                                                                                when "pwd"
                                                                                                  {"cd", flag_mappings, pre_arguments, post_arguments, false}
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
                                                                                                      # Don't pass the arguments through normal processing
                                                                                                      return "#{cmd} #{link} #{target}"
                                                                                                    else
                                                                                                      return "REM Error: ln -s requires both target and link name"
                                                                                                    end
                                                                                                  else
                                                                                                    # Hard link handling
                                                                                                    args = arguments.strip
                                                                                                    if args.includes?(" ")
                                                                                                      target, link = args.split(" ", 2)
                                                                                                      return "mklink /H #{link} #{target}"
                                                                                                    else
                                                                                                      return "REM Error: ln requires both target and link name"
                                                                                                    end
                                                                                                  end
                                                                                                else
                                                                                                  {shell_command, flag_mappings, pre_arguments, post_arguments, false}
                                                                                                end

        # Modify paths
        if modify_path_separator
          # Don't modify URLs
          if !arguments.includes?("http://") && !arguments.includes?("https://")
            arguments = arguments.gsub("/", "\\")
          end
        end
        windows_command = windows_command.gsub("/", "\\")

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
    def run(script : String) : String
      lines = script.split('\n')
      windows_batch = [] of String

      # Add warning about admin privileges
      windows_batch << "@REM This script contains mklink commands that require administrator privileges"
      windows_batch << "@REM Please run this batch file as administrator"
      windows_batch << ""

      lines.each do |line|
        line = line.strip
        line_string = line.dup

        converted_line = if line_string.size == 0
                           line_string
                         else
                           convert_line(line_string)
                         end

        windows_batch << converted_line
      end

      download_function = <<-BATCH
REM Function to download a file using bitsadmin
:download
setlocal
set "URL=%~1"
set "OUTPUT=%~2"
bitsadmin /transfer myDownloadJob /download /priority normal "%URL%" "%OUTPUT%"
endlocal
goto :eof

BATCH

      download_function + windows_batch.join("\n")
    end
  end
end
