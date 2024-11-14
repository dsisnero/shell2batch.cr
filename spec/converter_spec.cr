require "./spec_helper"
require "../src/shell2batch/converter"

module Shell2Batch
  describe Converter do
    it "add_arguments pre empty additional" do
      converter = Converter.new
      value = converter.add_arguments("test", [] of String, true)
      value.should eq "test"
    end

    it "add_arguments pre all empty" do
      converter = Converter.new
      value = converter.add_arguments("test", [] of String, true)
      value.should eq "test"
    end

    it "add_arguments pre additional values" do
      converter = Converter.new
      value = converter.add_arguments("test", [" 1", " 2", " 3"], true)
      value.should eq "1 2 3 test"
    end

    it "add_arguments pre empty args and additional values" do
      converter = Converter.new
      value = converter.add_arguments("", ["1", " 2", " 3"], true)
      value.should eq "1 2 3"
    end

    it "add_arguments post empty additional" do
      converter = Converter.new
      value = converter.add_arguments("test", [] of String, false)
      value.should eq "test"
    end

    it "add_arguments post all empty" do
      converter = Converter.new
      value = converter.add_arguments("test", [] of String, false)
      value.should eq "test"
    end

    it "add_arguments post additional values" do
      converter = Converter.new
      value = converter.add_arguments("test", [" 1", " 2", " 3"], false)
      value.should eq "test 1 2 3"
    end

    it "add_arguments post empty args and additional values" do
      converter = Converter.new
      value = converter.add_arguments("", ["1", " 2", " 3"], false)
      value.should eq "1 2 3"
    end

    it "replace_flags all empty" do
      converter = Converter.new
      value = converter.replace_flags("", [] of Tuple(String, String))
      value.should eq ""
    end

    it "replace_flags args empty replacement existing" do
      converter = Converter.new
      value = converter.replace_flags("", [{"linux", "windows"}])
      value.should eq ""
    end

    it "replace_flags args existing replacement empty" do
      converter = Converter.new
      value = converter.replace_flags("linux", [] of Tuple(String, String))
      value.should eq "linux"
    end

    it "replace_flags multiple" do
      converter = Converter.new
      value = converter.replace_flags(
        "linux1 LiNux2 somethingelse",
        [
          {"linux1", "windows1"},
          {"[lL]i[nN]ux[1-9]", "windowsX"},
          {"unknown", "bad"},
        ]
      )
      value.should eq "windows1 windowsX somethingelse"
    end

    it "replace_full_vars empty" do
      converter = Converter.new
      value = converter.replace_full_vars("")
      value.should eq ""
    end

    it "replace_full_vars not found" do
      converter = Converter.new
      value = converter.replace_full_vars("test 123")
      value.should eq "test 123"
    end

    it "replace_full_vars found" do
      converter = Converter.new
      value = converter.replace_full_vars("test ${myvar} 123")
      value.should eq "test %myvar% 123"

      value = converter.replace_full_vars("test ${myvar}")
      value.should eq "test %myvar%"

      value = converter.replace_full_vars("test ${myvar} ${myvar2} somethingelse ${myvar3}")
      value.should eq "test %myvar% %myvar2% somethingelse %myvar3%"
    end

    it "replace_partial_vars empty" do
      converter = Converter.new
      value = converter.replace_partial_vars("")
      value.should eq ""
    end

    it "replace_partial_vars not found" do
      converter = Converter.new
      value = converter.replace_partial_vars("test 123")
      value.should eq "test 123"
    end

    it "replace_partial_vars found" do
      converter = Converter.new
      value = converter.replace_partial_vars("test $myvar 123")
      value.should eq "test %myvar% 123"

      value = converter.replace_partial_vars("test $myvar")
      value.should eq "test %myvar%"

      value = converter.replace_partial_vars("test $myvar $myvar2 somethingelse $myvar3")
      value.should eq "test %myvar% %myvar2% somethingelse %myvar3%"
    end

    it "replace_vars empty" do
      converter = Converter.new
      value = converter.replace_vars("")
      value.should eq ""
    end

    it "replace_vars not found" do
      converter = Converter.new
      value = converter.replace_vars("test 123")
      value.should eq "test 123"
    end

    it "replace_vars full syntax" do
      converter = Converter.new
      value = converter.replace_vars("test ${myvar} 123")
      value.should eq "test %myvar% 123"

      value = converter.replace_vars("test ${myvar}")
      value.should eq "test %myvar%"

      value = converter.replace_vars("test ${myvar} ${myvar2} somethingelse ${myvar3}")
      value.should eq "test %myvar% %myvar2% somethingelse %myvar3%"
    end

    it "replace_vars partial syntax" do
      converter = Converter.new
      value = converter.replace_vars("test $myvar 123")
      value.should eq "test %myvar% 123"

      value = converter.replace_vars("test $myvar")
      value.should eq "test %myvar%"

      value = converter.replace_vars("test $myvar $myvar2 somethingelse $myvar3")
      value.should eq "test %myvar% %myvar2% somethingelse %myvar3%"
    end

    it "replace_vars mixed" do
      converter = Converter.new
      value = converter.replace_vars("test $myvar ${myvar2} 123")
      value.should eq "test %myvar% %myvar2% 123"

      value = converter.replace_vars("${somevar1} test $myvar")
      value.should eq "%somevar1% test %myvar%"

      value = converter.replace_vars("test $myvar ${myvar2} somethingelse $myvar3")
      value.should eq "test %myvar% %myvar2% somethingelse %myvar3%"
    end

    it "replace_params full" do
      converter = Converter.new
      value = converter.replace_full_vars("echo 0=${0} 1=${1} 2=${2} 3=${3} 4=${4} 5=${5} 6=${6} 7=${7} 8=${8} 9=${9}")
      value.should eq "echo 0=%0 1=%1 2=%2 3=%3 4=%4 5=%5 6=%6 7=%7 8=%8 9=%9"

      value = converter.replace_full_vars("echo ${@}")
      value.should eq "echo %*"
    end

    it "replace_params partial syntax" do
      converter = Converter.new
      value = converter.replace_partial_vars("echo 0=$0 1=$1 2=$2 3=$3 4=$4 5=$5 6=$6 7=$7 8=$8 9=$9")
      value.should eq "echo 0=%0 1=%1 2=%2 3=%3 4=%4 5=%5 6=%6 7=%7 8=%8 9=%9"

      value = converter.replace_partial_vars("echo $@")
      value.should eq "echo %*"
    end

    it "replace_params mixed" do
      converter = Converter.new
      value = converter.replace_vars("echo 0=$0 1=${1} 2=$2 3=${3} 4=$4 5=${5} 6=$6 7=${7} 8=$8 9=${9} ${somevar1} test $myvar")
      value.should eq "echo 0=%0 1=%1 2=%2 3=%3 4=%4 5=%5 6=%6 7=%7 8=%8 9=%9 %somevar1% test %myvar%"

      value = converter.replace_vars("echo $@ ${@}")
      value.should eq "echo %* %*"
    end

    it "run empty" do
      converter = Converter.new
      output = converter.run("")
      output.should eq ""
    end

    it "run comment" do
      converter = Converter.new
      output = converter.run("#comment")
      output.should eq "@REM comment"
    end

    it "run command" do
      converter = Converter.new
      output = converter.run("cp file1 file2")
      output.should eq "copy file1 file2"
    end

    it "run multi-line" do
      converter = Converter.new
      output = converter.run(%{
      #this is some test code
      cp file1 file2

      #another
      mv file2 file3
    })
      output.should eq %{
@REM this is some test code
copy file1 file2

@REM another
move file2 file3
}
    end

    it "convert line empty" do
      converter = Converter.new
      output = converter.convert_line("")
      output.should eq ""
    end

    it "convert line unhandled" do
      converter = Converter.new
      output = converter.convert_line("newcommand path/arg1 path/arg2")
      output.should eq "newcommand path/arg1 path/arg2"
    end

    it "convert line with hint" do
      converter = Converter.new
      output = converter.convert_line("test 123 abc # shell2batch: windows 123 windows abc")
      output.should eq "windows 123 windows abc"
    end

    it "convert line with hint trim" do
      converter = Converter.new
      output = converter.convert_line("test 123 abc # shell2batch:    windows 123 windows abc   ")
      output.should eq "windows 123 windows abc"
    end

    it "convert line with hint empty" do
      converter = Converter.new
      output = converter.convert_line("test 123 abc # shell2batch:")
      output.should eq ""
    end

    it "convert line with hint start of line" do
      converter = Converter.new
      output = converter.convert_line("# shell2batch: windows 123 windows abc")
      output.should eq "windows 123 windows abc"
    end

    it "convert line comment" do
      converter = Converter.new
      output = converter.convert_line("#test/test")
      output.should eq "@REM test/test"
    end

    it "convert line cp" do
      converter = Converter.new
      output = converter.convert_line("cp dir/file1 dir/file2")
      output.should eq "copy dir\\file1 dir\\file2"
    end

    it "convert line cp recursive" do
      converter = Converter.new
      output = converter.convert_line("cp -r directory/sub1 director/sub2")
      output.should eq "xcopy /E directory\\sub1 director\\sub2"
    end

    it "convert line cp file with dash" do
      converter = Converter.new
      output = converter.convert_line("cp file-r directory")
      output.should eq "copy file-r directory"
    end

    it "convert line mv" do
      converter = Converter.new
      output = converter.convert_line("mv dir/file1 dir/file2")
      output.should eq "move dir\\file1 dir\\file2"
    end

    it "convert line ls" do
      converter = Converter.new
      output = converter.convert_line("ls")
      output.should eq "dir"
    end

    it "convert line rm" do
      converter = Converter.new
      output = converter.convert_line("rm dir/file")
      output.should eq "del dir\\file"
    end

    it "convert line rm no prompt" do
      converter = Converter.new
      output = converter.convert_line("rm -f dir/file")
      output.should eq "del /Q dir\\file"
    end

    it "convert line rm with minus r in path" do
      converter = Converter.new
      output = converter.convert_line("rm ./dir-dir/.file")
      output.should eq "del .\\dir-dir\\.file"
    end

    it "convert line rm recursive" do
      converter = Converter.new
      output = converter.convert_line("rm -r dir/file")
      output.should eq "rmdir /S dir\\file"
    end

    it "convert line rm no prompt and recursive v1" do
      converter = Converter.new
      output = converter.convert_line("rm -rf dir/file")
      output.should eq "rmdir /S /Q dir\\file"
    end

    it "convert line rm no prompt and recursive v2" do
      converter = Converter.new
      output = converter.convert_line("rm -fr dir/file")
      output.should eq "rmdir /S /Q dir\\file"
    end

    it "convert line rm no prompt and recursive v3" do
      converter = Converter.new
      output = converter.convert_line("rm -Rf dir/file")
      output.should eq "rmdir /S /Q dir\\file"
    end

    it "convert line rm no prompt and recursive v4" do
      converter = Converter.new
      output = converter.convert_line("rm -fR dir/file")
      output.should eq "rmdir /S /Q dir\\file"
    end

    it "convert line mkdir" do
      converter = Converter.new
      output = converter.convert_line("mkdir dir1/dir2")
      output.should eq "mkdir dir1\\dir2"
    end

    it "convert line mkdir and parents" do
      converter = Converter.new
      output = converter.convert_line("mkdir -p dir1/dir2")
      output.should eq "mkdir  dir1\\dir2"
    end

    it "convert line clear" do
      converter = Converter.new
      output = converter.convert_line("clear")
      output.should eq "cls"
    end

    it "convert line grep" do
      converter = Converter.new
      output = converter.convert_line("grep")
      output.should eq "find"
    end

    it "convert line pwd" do
      converter = Converter.new
      output = converter.convert_line("pwd")
      output.should eq "chdir"
    end

    it "convert line export" do
      converter = Converter.new
      output = converter.convert_line("export A=B")
      output.should eq "set A=B"
    end

    it "convert line unset" do
      converter = Converter.new
      output = converter.convert_line("unset A")
      output.should eq "set A="
    end

    it "convert line touch" do
      converter = Converter.new
      output = converter.convert_line("touch ./dir/myfile.txt")
      output.should eq "copy /B .\\dir\\myfile.txt+,, .\\dir\\myfile.txt"
    end

    it "convert line set -x" do
      converter = Converter.new
      output = converter.convert_line("set -x")
      output.should eq "@echo on"
    end

    it "convert line set +x" do
      converter = Converter.new
      output = converter.convert_line("set +x")
      output.should eq "@echo off"
    end

    it "convert line var as command" do
      converter = Converter.new
      output = converter.convert_line("$MYVAR")
      output.should eq "%MYVAR%"
    end

    it "converts var as part of command" do
      converter = Converter.new
      output = converter.convert_line("./${MYVAR}.exe/something")
      output.should eq ".\\%MYVAR%.exe\\something"
    end

    it "convert line symlink file" do
      converter = Converter.new
      output = converter.convert_line("ln -s target link_name")
      output.should eq "mklink link_name target"
    end

    it "convert line symlink directory" do
      converter = Converter.new
      output = converter.convert_line("ln -s target/ link_name")
      output.should eq "mklink /D link_name target"
    end

    it "convert line hard link" do
      converter = Converter.new
      output = converter.convert_line("ln original.txt hard_link.txt")
      output.should eq "mklink /H hard_link.txt original.txt"
    end

    it "convert line invalid symlink" do
      converter = Converter.new
      output = converter.convert_line("ln -s target")
      output.should eq "REM Error: ln -s requires both target and link name"
    end

    it "convert line invalid hard link" do
      converter = Converter.new
      output = converter.convert_line("ln original.txt")
      output.should eq "REM Error: ln requires both target and link name"
    end
  end
end
