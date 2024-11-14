require "option_parser"
require "./shell2batch/converter"

module Shell2Batch
  VERSION = "0.1.0"
end


# TODO: Add your documentation as shown in the previous answer.

program_description = <<-DESCRIPTION
Converts a shell script to a batch script using Shell2Batch.

Usage: shell2batch [options] <script_file>
DESCRIPTION

# Define options for the command-line program
OptionParser.parse do |parser|
  parser.banner = program_description

  parser.on("-h", "--help", "Show this help message") do
    puts parser
    exit
  end
end

# Check if the script filename is provided as an argument
if ARGV.size != 1
  puts "Error: Please provide a single shell script filename as an argument."
  exit(1)
end

# Read the script filename from the command line
script_filename = ARGV[0]

# Check if the file exists
unless File.exists?(script_filename)
  puts "Error: The specified file '#{script_filename}' does not exist."
  exit(1)
end

# Read the content of the shell script
script_content = File.read(script_filename)

# Convert the shell script to a batch script
batch_script = Shell2Batch.convert(script_content)

# Print the resulting batch script
puts batch_script
