require "./src/shell2batch/converter"

# Test Makefile conversion
makefile_content = <<-MAKEFILE
CC = gcc
TARGET = hello
SOURCES = hello.c

all: hello

hello: hello.c
	$(CC) -o $(TARGET) $(SOURCES)

clean:
	rm -f $(TARGET)
MAKEFILE

puts "Original Makefile:"
puts makefile_content
puts "\n" + "="*50 + "\n"

# Convert the Makefile
batch_output = Shell2Batch::Converter.convert(makefile_content, :makefile)
puts "Converted Batch File:"
puts batch_output
