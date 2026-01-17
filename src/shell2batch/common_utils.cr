module Shell2Batch
  # Common utilities shared across all converters
  module CommonUtils
    # File type detection
    def self.detect_file_type(filename : String, content : String? = nil) : Symbol
      # Check by extension first
      case File.extname(filename).downcase
      when ".sh", ".bash"
        :shell
      when ".mk", ".make"
        :makefile
      when ""
        # Check for common filenames
        case filename.downcase
        when "makefile"
          :makefile
        else
          # Check content for shebang or Makefile patterns
          if content
            detect_file_type_by_content(content)
          else
            :unknown
          end
        end
      else
        :unknown
      end
    end

    def self.detect_file_type_by_content(content : String) : Symbol
      lines = content.lines.first(10) # Check first 10 lines

      # Check for shell shebang
      if lines.any? { |line| line =~ /^#!\/.*\/(bash|sh|zsh)/ }
        return :shell
      end

      # Check for Makefile patterns
      if lines.any? { |line| line =~ /^[a-zA-Z0-9_-]+\s*:/ } ||
         lines.any? { |line| line =~ /^\s*[a-zA-Z_][a-zA-Z0-9_]*\s*=/ }
        return :makefile
      end

      :unknown
    end

    # Path utilities
    def self.convert_path_separators(path : String) : String
      # Don't modify URLs
      if path.includes?("http://") || path.includes?("https://")
        path
      else
        path.gsub("/", "\\")
      end
    end

    def self.is_url?(path : String) : Bool
      path.starts_with?("http://") || path.starts_with?("https://")
    end

    # String utilities
    def self.split_command_line(line : String) : Tuple(String, String)
      if index = line.index(" ")
        {line[0...index], line[index..-1].strip}
      else
        {line, ""}
      end
    end

    def self.build_command(windows_command : String, windows_arguments : String) : String
      if windows_arguments.empty?
        windows_command
      else
        "#{windows_command} #{windows_arguments}"
      end
    end

    # Comment handling
    def self.convert_comment(line : String, prefix : String = "# shell2batch:") : String
      if line.includes?(prefix)
        index = line.index!(prefix).to_i + prefix.size
        line[index..].strip
      elsif line.starts_with?("#")
        "@REM #{line[1..]}"
      else
        line
      end
    end

    # Variable expansion helpers
    def self.expand_variables(text : String) : String
      # Handle $(dirname $0) special case
      if text.includes?("$(dirname $0)")
        text = text.gsub("$(dirname $0)", "%~dp0")
      end

      # Handle ${VAR} syntax
      text = expand_full_vars(text)

      # Handle $VAR syntax
      text = expand_partial_vars(text)

      text
    end

    private def self.expand_full_vars(text : String) : String
      parts = text.split("${")
      buffer = [] of String

      buffer << parts.shift

      parts.each do |part|
        b4, f, after = part.partition("}")
        found = !(f.empty?)

        if found
          buffer << convert_var_syntax(b4)
        else
          buffer << b4
        end

        buffer << after if after.size > 0
      end

      buffer.join("")
    end

    private def self.expand_partial_vars(text : String) : String
      parts = text.split("$")
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

        buffer << convert_var_syntax(before)
        buffer << after if after.size > 0
      end

      buffer.join("")
    end

    private def self.convert_var_syntax(value : String) : String
      case value
      when "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"
        "%" + value
      when "@"
        "%*"
      else
        "%" + value + (value.match(/^[a-zA-Z]/) ? "%" : "")
      end
    end
  end
end
