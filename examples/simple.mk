# Simple Makefile example
CC = gcc
TARGET = hello
SOURCES = hello.c

all: $(TARGET)

$(TARGET): $(SOURCES)
	$(CC) -o $(TARGET) $(SOURCES)

clean:
	rm -f $(TARGET)