require "./spec_helper"

module Shell2Batch
  describe MakefileConverter do
    it "converts simple Makefile" do
      content = "# Simple Makefile example\nCC = gcc\nTARGET = hello\nSOURCES = hello.c\n\nall: $(TARGET)\n\n$(TARGET): $(SOURCES)\n\t$(CC) -o $(TARGET) $(SOURCES)\n\nclean:\n\trm -f $(TARGET)"

      converter = MakefileConverter.new(content)
      output = converter.convert(content)

      # Check that basic elements are present
      output.should contain("set CC=gcc")
      output.should contain("set TARGET=hello")
      output.should contain("set SOURCES=hello.c")
      output.should contain(":all")
      output.should contain(":%TARGET%")
      output.should contain(":clean")
      output.should contain("del /Q %TARGET%")
    end

    it "converts Makefile with variables and commands" do
      content = <<-MAKEFILE
        CFLAGS = -Wall -O2
        PROGRAM = myapp
        SOURCES = main.c utils.c

        $(PROGRAM): $(SOURCES)
        \t$(CC) $(CFLAGS) -o $(PROGRAM) $(SOURCES)

        clean:
        \trm -f $(PROGRAM)
      MAKEFILE

      converter = MakefileConverter.new(content)
      output = converter.convert(content)

      output.should contain("set CFLAGS=-Wall -O2")
      output.should contain("set PROGRAM=myapp")
      output.should contain("set SOURCES=main.c utils.c")
      output.should contain(":%PROGRAM%")
      output.should contain(":clean")
    end

    it "handles empty Makefile" do
      content = ""
      converter = MakefileConverter.new(content)
      output = converter.convert(content)

      output.should contain("@echo off")
    end

    it "handles Makefile with only comments" do
      content = <<-MAKEFILE
        # This is a comment
        # Another comment
      MAKEFILE

      converter = MakefileConverter.new(content)
      output = converter.convert(content)

      output.should contain("@echo off")
    end

    it "converts Makefile with multiple targets" do
      content = <<-MAKEFILE
        build: compile link

        compile:
        \techo "Compiling..."

        link:
        \techo "Linking..."

        clean:
        \techo "Cleaning..."
      MAKEFILE

      converter = MakefileConverter.new(content)
      output = converter.convert(content)

      output.should contain(":build")
      output.should contain(":compile")
      output.should contain(":link")
      output.should contain(":clean")
    end
  end
end
