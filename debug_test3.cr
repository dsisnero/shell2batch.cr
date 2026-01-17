require "./src/shell2batch/converter"

# Test with only comments
script1 = %(
  #this is some test code
  #another comment
)

# Test with one command
script2 = %(
  #comment
  cp file1 file2
)

# Test with multiple commands
script3 = %(
  #comment
  cp file1 file2
  mv file2 file3
)

converter = Shell2Batch::ShellConverter.new

puts "Script 1 (only comments):"
output1 = converter.run(script1)
puts output1.inspect

puts "\nScript 2 (one command):"
output2 = converter.run(script2)
puts output2.inspect

puts "\nScript 3 (multiple commands):"
output3 = converter.run(script3)
puts output3.inspect
