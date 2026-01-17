@echo off
set CC=gcc
set CFLAGS=-Wall -O2 -I./include
set LDFLAGS=-L./lib -lm
set TARGET=myapp

:compile_c_to_o
rem Compile .c file to .o file
rem Usage: call :compile_c_to_o source.c [target.o]
set src=%~1
if "%~2"=="" (
  set obj=%~n1.o
) else (
  set obj=%~2
)
if not exist obj mkdir obj
%CC% %CFLAGS% -c %src% -o %obj%
goto :eof

:build_objects
rem Build all object files from source files
if not exist src (
  echo Error: src directory not found
  exit /b 1
)
for /f %%f in ('dir /b src\*.c 2^>nul') do (
  if not exist obj\%%~nf.o (
    call :compile_c_to_o src\%%f obj\%%~nf.o
  ) else (
    rem Check if source is newer than object
    rem This is a simplified timestamp check
    if src\%%f obj\%%~nf.o (
      call :compile_c_to_o src\%%f obj\%%~nf.o
    )
  )
)
goto :eof

:myapp
call :build_objects
%CC% %CFLAGS% -o %TARGET% obj\*.o %LDFLAGS%
goto :eof

:all
call :myapp
goto :eof

:clean
if exist %TARGET% del /Q %TARGET%
if exist obj\*.o del /Q obj\*.o
if exist obj rmdir /S /Q obj
goto :eof

:distclean
call :clean
if exist *.log del /Q *.log
if exist *.out del /Q *.out
goto :eof

:main
call :all
goto :eof