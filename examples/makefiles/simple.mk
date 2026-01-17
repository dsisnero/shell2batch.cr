# Simple Makefile example
# Demonstrates basic variable usage and rules

CC = gcc
CFLAGS = -Wall -O2
TARGET = hello
SOURCES = hello.c

all: $(TARGET)

$(TARGET): $(SOURCES)
	$(CC) $(CFLAGS) -o $(TARGET) $(SOURCES)

clean:
	rm -f $(TARGET)

.PHONY: all clean