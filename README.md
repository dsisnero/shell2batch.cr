# shell2bat

## Overview
A Crystal library that converts shell scripts to Windows batch files. While not every shell script can be automatically converted, this library handles most common scenarios and provides ways to customize the conversion process.

Key features:
- Automatic command conversion
- Administrative privilege handling
- Symbolic link support
- Control flow conversion
- Variable substitution
- Custom conversion hints

A Crystal port of https://github.com/sagiegurari/shell2batch

## Installation

```bash
# Build from source
git clone https://github.com/dsisnero/shell2batch.git
cd shell2batch
shards build --release --static
```

The executable will be in the `bin` directory.

## Command Reference

### File Operations
| Shell Command | Windows Equivalent | Notes |
|--------------|-------------------|--------|
| `cp file1 file2` | `copy file1 file2` | Simple file copy |
| `cp -r dir1 dir2` | `xcopy dir1 dir2 /E` | Recursive directory copy |
| `mv file1 file2` | `move file1 file2` | Move/rename |
| `rm file` | `del file` | Delete file |
| `rm -rf dir` | `rmdir /S /Q dir` | Recursive directory delete |
| `mkdir -p dir` | `mkdir dir` | Create directory |
| `touch file` | `copy /B file+,, file` | Create/update file |

### Symbolic Links
| Shell Command | Windows Equivalent | Notes |
|--------------|-------------------|--------|
| `ln -s target link` | `mklink link target` | File symlink |
| `ln -s target/ link` | `mklink /D link target` | Directory symlink |
| `ln target link` | `mklink /H link target` | Hard link |

### Administrative Operations
| Shell Command | Windows Equivalent | Notes |
|--------------|-------------------|--------|
| `sudo command` | `runas /user:Administrator "command"` | Run as admin |
| `sudo cp` | `runas /user:Administrator "copy"` | Admin file operations |

### Variables
| Shell Syntax | Batch Syntax | Notes |
|--------------|-------------|--------|
| `export VAR=value` | `set VAR=value` | Set variable |
| `$VAR` | `%VAR%` | Variable expansion |
| `${VAR}` | `%VAR%` | Variable expansion |
| `$(dirname $0)` | `%~dp0` | Script directory |

## Usage

### Command Line

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

### Running Tests
```bash
crystal spec
```

### Adding New Command Conversions
To add support for a new shell command, modify `src/shell2batch/converter.cr` and add a case to the command matching:

```crystal
when "new_command"
  {"windows_command", flag_mappings, pre_arguments, post_arguments, modify_path}
```

### Custom Conversions
You can provide custom Windows commands for specific lines using the `# shell2batch:` prefix:

```bash
complex_command --flag1 value1 # shell2batch: windows_command /flag1 value1
```

## Examples

### Basic Script
```bash
#!/bin/bash
echo "Creating directories..."
mkdir -p test/nested/folders
cd test
touch example.txt
echo "Hello World" > example.txt
```

Converts to:
```batch
@echo off
echo Creating directories...
mkdir test\nested\folders
cd test
copy /B example.txt+,, example.txt
echo Hello World > example.txt
```

### Administrative Operations
```bash
#!/bin/bash
sudo cp -r /src /dest
ln -s target link_name
```

Converts to:
```batch
@echo off
NET SESSION >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process '%~dpnx0' -Verb RunAs"
    exit /b
)
runas /user:Administrator "xcopy /E \src \dest"
mklink link_name target
```

### Control Flow
```bash
#!/bin/bash
if [ -d "$DIR" ]; then
    echo "Directory exists"
elif [ -f "$FILE" ]; then
    echo "File exists"
else
    echo "Neither exists"
fi
```

Converts to:
```batch
@echo off
if exist "%DIR%\" (
    echo Directory exists
) else if exist "%FILE%" (
    echo File exists
) else (
    echo Neither exists
)
```

## Contributing

1. Fork it (<https://github.com/dsisnero/shell2batch/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [dsisnero](https://github.com/dsisnero) - creator and maintainer
