require "regex"
require "./base_converter"
require "./shell_converter"
require "./makefile_converter"
require "./command_mappings"
require "./common_utils"

module Shell2Batch
  # Main converter that handles file type detection and delegates to appropriate converter
  class Converter
    def self.convert(content : String, file_type : Symbol? = nil) : String
      # If file type not specified, try to detect it
      detected_type = file_type || CommonUtils.detect_file_type_by_content(content)

      case detected_type
      when :shell
        ShellConverter.new.convert(content)
      when :makefile
        MakefileConverter.new(content).convert(content)
      else
        # Default to shell converter for unknown types
        ShellConverter.new.convert(content)
      end
    end

    # Backward compatibility - delegate to ShellConverter
    def self.run(script : String)
      ShellConverter.new.run(script)
    end
  end

  # Backward compatibility - main convert method
  def self.convert(script : String)
    Converter.convert(script)
  end
end
