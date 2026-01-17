require "./src/shell2batch/converter"

converter = Shell2Batch::ShellConverter.new
output = converter.run("cp file1 file2")
puts "Output: " + output.inspect
