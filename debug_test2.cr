require "./src/shell2batch/converter"

script = %(
  #this is some test code
  cp file1 file2

  #another
  mv file2 file3
)

converter = Shell2Batch::ShellConverter.new
output = converter.run(script)
puts "Output: " + output.inspect

# Count actual commands
lines = script.split('\n')
command_lines = lines.select { |line|
  line = line.strip
  !line.empty? && !line.starts_with?("#")
}
puts "Command lines count: " + command_lines.size.to_s
puts "Command lines: " + command_lines.inspect
