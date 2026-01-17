require "./src/shell2batch/makefile_converter"

content = "# Simple Makefile example\nCC = gcc\nTARGET = hello\nSOURCES = hello.c\n\nall: $(TARGET)\n\n$(TARGET): $(SOURCES)\n\t$(CC) -o $(TARGET) $(SOURCES)\n\nclean:\n\trm -f $(TARGET)"

puts "Content to parse:"
puts content
puts "---"

converter = Shell2Batch::MakefileConverter.new(content)
ast = converter.parse(content)

puts "Variables: #{ast.variables.size}"
ast.variables.each do |var|
  puts "  #{var.name} = #{var.value}"
end

puts "Rules: #{ast.rules.size}"
ast.rules.each do |rule|
  puts "  #{rule.target}: #{rule.dependencies.join(", ")}"
  puts "    Commands: #{rule.commands.size}"
end
