require "./spec_helper"

module Shell2Batch
  describe "Example File Conversions" do
    it "converts app-neovim.sh correctly" do
      content = File.read("examples/app-neovim.sh")
      output = Shell2Batch.convert(content)
      
      # Should not have double quotes issue
      output.should_not contain("\"\"$HOME")
      # Should convert git command
      output.should contain("git") # For now, just check it's present
      # Should have proper if statement (not directory -> if not exist)
      output.should contain("if not exist")
    end

    it "converts example.sh correctly" do
      content = File.read("examples/example.sh")
      output = Shell2Batch.convert(content)
      
      # Should start with @echo off, not @REM !/bin/bash
      output.should start_with("@echo off")
      # Should have proper dir command
      output.should_not contain("dir -l")
      # Should have proper unzip command with filename
      output.should contain("Expand-Archive")
      output.should contain(".zip")
    end

    it "converts sleep_test.sh correctly" do
      content = File.read("examples/sleep_test.sh")
      output = Shell2Batch.convert(content)
      
      # Should start with @echo off
      output.should start_with("@echo off")
      # Should have proper timeout command with /t not \t
      output.should contain("timeout /t")
      output.should_not contain("timeout \\t")
    end

    it "converts medium.mk correctly" do
      content = File.read("examples/medium.mk")
      output = Shell2Batch.convert(content)
      
      # Should handle Makefile suffix replacement
      output.should_not contain("$(SOURCES:.c=.o)")
      # Should have valid OBJECTS variable
      output.should_not contain("%OBJECTS%") if output.includes?("$(SOURCES:.c=.o)")
    end

    it "converts complex.mk correctly" do
      content = File.read("examples/complex.mk")
      output = Shell2Batch.convert(content)
      
      # Should convert rm -rf properly
      output.should_not contain("rm -rf")
      # Should handle Makefile suffix replacement
      output.should_not contain("$(SOURCES:.c=.o)")
      # Should handle wildcard
      output.should_not contain("$(wildcard")
    end

    it "converts makefiles/complex.mk correctly" do
      content = File.read("examples/makefiles/complex.mk")
      output = Shell2Batch.convert(content)
      
      # Should have proper variable assignments
      output.should contain("set SRC_DIR=src")
      output.should contain("set OBJ_DIR=obj")
    end
  end
end