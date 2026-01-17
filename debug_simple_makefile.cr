require "./src/shell2batch/makefile_converter"

# Test with minimal whitespace
content = <<-MAKEFILE
CFLAGS=-Wall -O2
PROGRAM=myapp
SOURCES=main.c utils.c

$(PROGRAM): $(SOURCES)
\t$(CC) $(CFLAGS) -o $(PROGRAM) $(SOURCES)

clean:
\trm -f $(PROGRAM)
MAKEFILE

puts "Input Makefile:"
puts content
puts "\n" + "="*50 + "\n"

converter = Shell2Batch::MakefileConverter.new(content)
output = converter.convert(content)
puts "Output Batch:"
puts output
