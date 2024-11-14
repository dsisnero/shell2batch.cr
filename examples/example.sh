#!/bin/bash

# This is a demo script showing shell2batch capabilities
# It will be converted to Windows batch commands

# Directory operations
echo "Creating directories..."
mkdir -p test/nested/folders
cd test

# File operations
touch example.txt
echo "Hello World" > example.txt
cp example.txt backup.txt
cp -r nested copied_folder
mv backup.txt moved.txt

# Symbolic links
ln -s example.txt link_to_example
ln -s nested/ link_to_folder
ln original.txt hard_link.txt

# Variable operations
export TEST_VAR="Hello"
echo "Variable value is: $TEST_VAR"
echo "Script directory is: $(dirname $0)"
unset TEST_VAR

# Downloading and extracting
curl -L -o downloaded.zip https://example.com/file.zip
unzip downloaded.zip

# Cleanup operations
rm -f example.txt
rm -rf nested
ls -l

# Clear screen and exit
clear
cd ..
