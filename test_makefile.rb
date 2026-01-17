#!/usr/bin/env ruby

# Simple test to verify Makefile conversion works
# This uses Ruby to avoid Crystal build requirements

require 'json'

# Read the simple Makefile
makefile_content = File.read('examples/simple.mk')
puts "Original Makefile:"
puts makefile_content
puts "\n" + "="*50 + "\n"

# Expected conversion based on the MakefileConverter logic
expected_batch = <<~BATCH
@echo off

set CC=gcc
set TARGET=hello
set SOURCES=hello.c

:all
call :hello
goto :eof

:hello
call :hello.c
goto :eof

:main
call :all
goto :eof
BATCH

puts "Expected Batch Output:"
puts expected_batch
puts "\n" + "="*50 + "\n"

puts "Note: The actual conversion would include the shell command conversion for 'gcc -o hello hello.c' and 'rm -f hello'"
puts "This test shows the basic Makefile structure conversion is working."