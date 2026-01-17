require "./spec_helper"

describe Shell2Batch do
  it "can convert a script" do
    script = <<-SCRIPT
                set -x

                export FILE1=file1
                export FILE2=file2

                #this is some test code
                cp ${FILE1} $FILE2
                cp -r ${DIR1} $DIR2

                #another
                mv file2 file3

                export MY_DIR=directory

                #flags are supported
                rm -Rf ${MY_DIR}

                unset MY_DIR

                touch ./file3

                #provide custom windows command for specific shell command
                complex_bash_command --flag1 value2 # shell2batch: complex_windows_command /flag10 windows_value
              SCRIPT
    converted = Shell2Batch.convert(script)
    expected = <<-CONVERTED
                    @echo off
                    @echo on

                    set FILE1=file1
                    set FILE2=file2

                    @REM this is some test code
                    copy %FILE1% %FILE2%
                    xcopy /E %DIR1% %DIR2%

                    @REM another
                    move file2 file3

                    set MY_DIR=directory

                    @REM flags are supported
                    rmdir /S /Q %MY_DIR%

                    set MY_DIR=

                    copy /B .\\file3+,, .\\file3

                    @REM provide custom windows command for specific shell command
                    complex_windows_command /flag10 windows_value
                  CONVERTED
    # Strip leading spaces from each line of expected output
    expected_lines = expected.lines.map(&.strip)
    expected_result = expected_lines.join("\r\n") + "\r\n"
    converted.should eq expected_result
  end

  describe "file type detection" do
    it "detects shell scripts by shebang" do
      content = "#!/bin/bash\necho 'hello'"
      Shell2Batch::CommonUtils.detect_file_type_by_content(content).should eq :shell
    end

    it "detects Makefiles by target syntax" do
      content = "all:\n\techo 'hello'"
      Shell2Batch::CommonUtils.detect_file_type_by_content(content).should eq :makefile
    end

    it "detects Makefiles by variable syntax" do
      content = "VAR = value\nall:\n\techo $(VAR)"
      Shell2Batch::CommonUtils.detect_file_type_by_content(content).should eq :makefile
    end
  end
end
