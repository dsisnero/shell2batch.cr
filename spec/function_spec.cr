require "./spec_helper"

describe Shell2Batch::ShellConverter do
  describe "shell function support" do
    it "converts a simple function with parameters" do
      script = <<-SCRIPT
        greet() {
          echo "Hello, $1"
        }
        greet "World"
      SCRIPT

      converter = Shell2Batch::ShellConverter.new
      result = converter.convert(script)

      expected = <<-BATCH
        call :greet World
        goto :eof
        :greet
        echo Hello, %1
        exit /b 0
      BATCH

      # Normalize line endings for comparison
      result_lines = result.lines.reject(&.empty?)
      expected_lines = expected.lines.reject(&.empty?)

      result_lines.should eq(expected_lines)
    end

    it "converts function with multiple parameters" do
      script = <<-SCRIPT
        add() {
          echo "Result: $(($1 + $2))"
        }
        add 5 10
      SCRIPT

      converter = Shell2Batch::ShellConverter.new
      result = converter.convert(script)

      # Should contain the function call and subroutine
      result.should contain("call :add 5 10")
      result.should contain(":add")
      result.should contain("echo Result: (%1 + %2)")
    end

    it "converts function with return statement" do
      script = <<-SCRIPT
        check_file() {
          if [ -f "$1" ]; then
            return 0
          else
            return 1
          fi
        }
        check_file "test.txt"
      SCRIPT

      converter = Shell2Batch::ShellConverter.new
      result = converter.convert(script)

      # Should contain return statements converted to exit /b
      result.should contain("exit /b 0")
      result.should contain("exit /b 1")
      result.should contain("call :check_file test.txt")
    end

    it "converts function with alternative syntax" do
      script = <<-SCRIPT
        function hello {
          echo "Hello from function"
        }
        hello
      SCRIPT

      converter = Shell2Batch::ShellConverter.new
      result = converter.convert(script)

      result.should contain("call :hello")
      result.should contain(":hello")
      result.should contain("echo Hello from function")
    end

    it "converts function with mixed syntax" do
      script = <<-SCRIPT
        function goodbye() {
          echo "Goodbye, $1"
        }
        goodbye "Friend"
      SCRIPT

      converter = Shell2Batch::ShellConverter.new
      result = converter.convert(script)

      result.should contain("call :goodbye Friend")
      result.should contain(":goodbye")
      result.should contain("echo Goodbye, %1")
    end

    it "handles multiple functions" do
      script = <<-SCRIPT
        func1() {
          echo "Function 1: $1"
        }
        func2() {
          echo "Function 2: $1"
        }
        func1 "test1"
        func2 "test2"
      SCRIPT

      converter = Shell2Batch::ShellConverter.new
      result = converter.convert(script)

      result.should contain("call :func1 test1")
      result.should contain("call :func2 test2")
      result.should contain(":func1")
      result.should contain(":func2")
    end

    it "handles function with complex body" do
      script = <<-SCRIPT
        setup() {
          echo "Setting up..."
          mkdir -p "$1"
          cd "$1"
          touch "config.txt"
        }
        setup "my_project"
      SCRIPT

      converter = Shell2Batch::ShellConverter.new
      result = converter.convert(script)

      result.should contain("call :setup my_project")
      result.should contain(":setup")
      result.should contain("echo Setting up...")
      result.should contain("mkdir")
      result.should contain("cd")
      result.should contain("copy /B")
    end
  end
end