module Shell2Batch
  # Structured command mapping system
  struct CommandMapping
    property shell_command : String
    property windows_command : String
    property flag_mappings : Array(Tuple(String, String))
    property pre_arguments : Array(String)
    property post_arguments : Array(String)
    property modify_path_separator : Bool
    property makefile_support : Bool

    def initialize(
      @shell_command : String,
      @windows_command : String,
      @flag_mappings : Array(Tuple(String, String)) = [] of Tuple(String, String),
      @pre_arguments : Array(String) = [] of String,
      @post_arguments : Array(String) = [] of String,
      @modify_path_separator : Bool = false,
      @makefile_support : Bool = false,
    )
    end
  end

  # Command mapping database
  class CommandMappings
    @@mappings = [] of CommandMapping

    def self.add(mapping : CommandMapping)
      @@mappings << mapping
    end

    def self.find(shell_command : String) : CommandMapping?
      @@mappings.find { |m| m.shell_command == shell_command }
    end

    def self.all : Array(CommandMapping)
      @@mappings
    end

    # Initialize with common shell command mappings
    def self.initialize_mappings
      # File operations - only simple mappings here
      add CommandMapping.new("mv", "move", modify_path_separator: true)
      add CommandMapping.new("mkdir", "mkdir", [{"-[pP]", ""}], modify_path_separator: true)

      # Directory operations
      add CommandMapping.new("pwd", "chdir")

      # Text processing
      add CommandMapping.new("grep", "find")
      add CommandMapping.new("clear", "cls")

      # Environment variables
      add CommandMapping.new("export", "set")
      # unset handled by special handler in shell_converter.cr

      # System
      add CommandMapping.new("set", "@echo", [{"-x", "on"}, {"\\+x", "off"}])

      # Special commands
      add CommandMapping.new("trap", "REM trap command not supported in batch")

      # Makefile-specific commands (will be used by MakefileConverter)
      add CommandMapping.new("make", "nmake", makefile_support: true)

      # Additional bash commands
      add CommandMapping.new("cat", "type", modify_path_separator: true)
      add CommandMapping.new("head", "more", [{"-n", "/t"}], modify_path_separator: true)
      add CommandMapping.new("tail", "more", [{"-n", "/t"}], ["+1"], modify_path_separator: true)
      add CommandMapping.new("wc", "find", [{"-l", "/c"}, {"-w", "/c"}, {"-c", "/c"}], modify_path_separator: true)
      add CommandMapping.new("sort", "sort", modify_path_separator: true)
      add CommandMapping.new("uniq", "sort", [{"-u", ""}], modify_path_separator: true)
      add CommandMapping.new("diff", "fc", modify_path_separator: true)
      add CommandMapping.new("find", "dir", [{"-name", "/s"}, {"-type", "/a"}], modify_path_separator: true)
      add CommandMapping.new("chmod", "attrib", [{"\\+x", "+R"}, {"-x", "-R"}], modify_path_separator: true)
      add CommandMapping.new("chown", "REM chown not supported in batch")
      add CommandMapping.new("which", "where", modify_path_separator: true)
      add CommandMapping.new("date", "echo %DATE% %TIME%")
      add CommandMapping.new("time", "echo %TIME%")
      add CommandMapping.new("whoami", "echo %USERNAME%")
      add CommandMapping.new("hostname", "echo %COMPUTERNAME%")
      add CommandMapping.new("env", "set")
      add CommandMapping.new("alias", "doskey", modify_path_separator: true)
      add CommandMapping.new("history", "doskey /history")
      add CommandMapping.new("kill", "taskkill", [{"-9", "/F"}, {"-TERM", "/F"}], modify_path_separator: true)
      add CommandMapping.new("ps", "tasklist", modify_path_separator: true)
      # Sleep command handled by specific handler
      add CommandMapping.new("wait", "REM wait not supported in batch")
      add CommandMapping.new("source", "call", modify_path_separator: true)
      add CommandMapping.new("tee", "REM tee not supported in batch")
      add CommandMapping.new("xargs", "REM xargs not supported in batch")
      add CommandMapping.new("sed", "REM sed not supported in batch")
      add CommandMapping.new("awk", "REM awk not supported in batch")
      add CommandMapping.new("cut", "REM cut not supported in batch")
      add CommandMapping.new("tr", "REM tr not supported in batch")
      add CommandMapping.new("base64", "REM base64 not supported in batch")
      # Hash commands handled by specific handlers - no mapping needed
    end
  end

  # Initialize mappings on module load
  CommandMappings.initialize_mappings
end
