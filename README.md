# shell2bat

## Overview
While it is not really possible to take every shell script and automatically convert it to a windows batch file, this library provides a way to convert simple basic shell commands to windows batch commands.<br>
<br>
It is possible to provide custom conversion hints by using the **# shell2batch:** prefix (see below example).

A crystal port of https://github.com/sagiegurari/shell2batch

## Installation

TODO: Write installation instructions here

## Usage

## Usage
Simply include the library and invoke the convert function as follows:

<!--{ "examples/example.rs" | lines: 3 | code: rust }-->
```crystal

require "shell2batch"

script = Shell2Batch.convert <<-SCRIPT
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
```
The script will now be converted
```crystal
script.should eq <<-CONVERTED
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

copy /B .\file3+,, .\file3

@REM provide custom windows command for specific shell command
complex_windows_command /flag10 windows_value
CONVERTED
````

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/dsisnero/shell2batch/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [dsisnero](https://github.com/dsisnero) - creator and maintainer
