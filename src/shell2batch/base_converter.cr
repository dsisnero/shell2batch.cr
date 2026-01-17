module Shell2Batch
  # Base converter class that provides common functionality
  # for all converter types (shell, makefile, etc.)
  abstract class BaseConverter
    SHELL2BATCH_PREFIX = "# shell2batch:"

    # Abstract method that must be implemented by subclasses
    abstract def convert(content : String) : String

    # Common utility methods for all converters

    def replace_flags(arguments : String, flags_mappings : Array(Tuple(String, String))) : String
      windows_arguments = arguments.dup

      flags_mappings.each do |shell_flag, windows_flag|
        # Skip empty shell flags to avoid matching everything
        next if shell_flag.empty?

        shell_regex = Regex.new(shell_flag)

        if shell_regex.match(windows_arguments)
          windows_arguments = windows_arguments.sub(shell_regex, windows_flag)
        end
      end

      windows_arguments
    end

    def convert_var(value : String, buffer : Array(String))
      case value
      when "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"
        buffer << "%" + value # Numeric params don't need trailing %
      when "@"
        buffer << "%*"
      else
        # Always add trailing % for named variables
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

      result = replace_full_vars(arguments)
      result = replace_partial_vars(result)
      result
    end

    def add_arguments(arguments : String, additional_arguments : Array(String), pre : Bool) : String
      windows_arguments = String::Builder.new

      if pre
        additional_arguments.each_with_index do |additional_argument, index|
          windows_arguments << " " if index > 0
          windows_arguments << additional_argument.strip
        end
        if arguments.size > 0
          windows_arguments << " " if additional_arguments.size > 0
          windows_arguments << arguments
        end
      else
        if arguments.size > 0
          windows_arguments << arguments
        end
        additional_arguments.each_with_index do |additional_argument, index|
          windows_arguments << " " if arguments.size > 0 || index > 0
          windows_arguments << additional_argument.strip
        end
      end

      windows_arguments.to_s.lstrip
    end

    # Path separator conversion helper
    def convert_path_separators(path : String) : String
      # Don't modify URLs
      if path.includes?("http://") || path.includes?("https://")
        path
      else
        path.gsub("/", "\\")
      end
    end

    # Comment conversion helper
    def convert_comment(line : String) : String
      if line.includes?(SHELL2BATCH_PREFIX)
        index = line.index!(SHELL2BATCH_PREFIX).to_i + SHELL2BATCH_PREFIX.size
        line[index..].strip
      elsif line.starts_with?("#")
        "@REM #{line[1..]}"
      else
        line
      end
    end
  end
end
