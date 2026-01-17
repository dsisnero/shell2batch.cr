require "./spec_helper"

module Shell2Batch
  describe "Complex Makefile Features" do
    it "expands wildcard function in variable assignments" do
      content = <<-MAKEFILE
        SOURCES = $(wildcard src/*.c)
      MAKEFILE

      converter = MakefileConverter.new(content)
      output = converter.convert(content)

      # $(wildcard src/*.c) should be converted to batch-style comment
      output.should contain("rem SOURCES")
      output.should contain("dir /b")
    end

    it "expands patsubst function in variable assignments" do
      content = <<-MAKEFILE
        SRC_DIR = src
        OBJ_DIR = obj
        SOURCES = main.c utils.c
        OBJECTS = $(patsubst $(SRC_DIR)/%.c,$(OBJ_DIR)/%.o,$(SOURCES))
      MAKEFILE

      converter = MakefileConverter.new(content)
      output = converter.convert(content)

      # Should convert patsubst to batch function
      output.should contain("rem OBJECTS")
      output.should contain(":build_objects")
      output.should contain("for /f")
    end

    it "handles pattern rules with automatic variables" do
      content = <<-MAKEFILE
        CC = gcc
        CFLAGS = -Wall

        obj/%.o: src/%.c
	$(CC) $(CFLAGS) -c $< -o $@
      MAKEFILE

      converter = MakefileConverter.new(content)
      output = converter.convert(content)

      # Pattern rule should be converted to batch function
      output.should contain(":compile_c_to_o")
      output.should contain("%CC% %CFLAGS% -c %src% -o %obj%")
    end

    it "handles mkdir -p command in Makefile rules" do
      content = <<-MAKEFILE
        OBJ_DIR = obj

        prepare:
	@mkdir -p $(OBJ_DIR)
      MAKEFILE

      converter = MakefileConverter.new(content)
      output = converter.convert(content)

      # @mkdir -p should convert to @mkdir (with @ for suppression)
      output.should contain("@mkdir")
      output.should contain("%OBJ_DIR%")
    end

    it "correctly expands automatic variables $@ and $^ in commands" do
      content = <<-MAKEFILE
        TARGET = myapp
        OBJECTS = main.o utils.o

        $(TARGET): $(OBJECTS)
	$(CC) -o $@ $^
      MAKEFILE

      converter = MakefileConverter.new(content)
      output = converter.convert(content)

      # $@ should expand to target name (myapp)
      # $^ should expand to all dependencies (main.o utils.o)
      output.should contain("-o myapp main.o utils.o")
    end
  end
end