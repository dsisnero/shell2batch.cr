require "option_parser"
require "./shell2batch/converter"

module Shell2Batch
  VERSION = "0.1.0"
end

program_description = <<-DESCRIPTION
Converts shell scripts and Makefiles to Windows batch files using Shell2Batch.

Usage: shell2batch [options] <input_file>

Supported file types:
  - Shell scripts (.sh, .bash) with shebang detection
  - Makefiles (Makefile, .mk, .make)

Options:
DESCRIPTION

# Create an instance of OptionParser
parser = OptionParser.new
parser.banner = program_description

file_type = :auto
output_format = :batch

parser.on("-t TYPE", "--type=TYPE", "Specify input file type (shell, makefile, auto)") do |t|
  case t.downcase
  when "shell"
    file_type = :shell
  when "makefile", "make"
    file_type = :makefile
  when "auto"
    file_type = :auto
  else
    puts "Error: Unknown file type '#{t}'. Use 'shell', 'makefile', or 'auto'."
    exit(1)
  end
end

parser.on("-f FORMAT", "--format=FORMAT", "Specify output format (batch, powershell)") do |f|
  case f.downcase
  when "batch"
    output_format = :batch
  when "powershell", "ps1"
    output_format = :powershell
  else
    puts "Error: Unknown output format '#{f}'. Use 'batch' or 'powershell'."
    exit(1)
  end
end

parser.on("-h", "--help", "Show this help message") do
  puts parser
  exit
end

parser.on("-v", "--version", "Show version information") do
  puts "Shell2Batch v#{Shell2Batch::VERSION}"
  exit
end

# Parse the command-line arguments and modify ARGV
parser.parse(ARGV)

# Check if the script filename is provided as an argument
if ARGV.size != 1
  puts parser
  exit(1)
end

# Read the script filename from the remaining arguments
script_filename = ARGV[0]

# Check if the file exists
unless File.exists?(script_filename)
  puts "Error: The specified file '#{script_filename}' does not exist."
  exit(1)
end

# Read the content of the input file
file_content = File.read(script_filename)

# Auto-detect file type if not specified
if file_type == :auto
  file_type = Shell2Batch::CommonUtils.detect_file_type(script_filename, file_content)
  if file_type == :unknown
    puts "Warning: Could not auto-detect file type. Defaulting to shell script conversion."
    file_type = :shell
  end
end

# Convert the file to batch script
batch_script = Shell2Batch::Converter.convert(file_content, file_type)

# Print the resulting batch script
puts batch_script
