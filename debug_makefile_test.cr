require "./src/shell2batch/converter"

content = "# Simple Makefile example\nCC = gcc\nTARGET = hello\nSOURCES = hello.c\n\nall: $(TARGET)\n\n$(TARGET): $(SOURCES)\n\t$(CC) -o $(TARGET) $(SOURCES)\n\nclean:\n\trm -f $(TARGET)"

puts "Input Makefile:"
puts content
puts "\n" + "="*50 + "\n"

output = Shell2Batch::Converter.convert(content, :makefile)
puts "Output Batch:"
puts output
