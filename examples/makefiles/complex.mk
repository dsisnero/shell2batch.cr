# Complex Makefile example
# Demonstrates multiple targets, dependencies, and variables

CC = gcc
CFLAGS = -Wall -O2 -I./include
LDFLAGS = -L./lib -lm
TARGET = myapp
SRC_DIR = src
OBJ_DIR = obj
SOURCES = $(wildcard $(SRC_DIR)/*.c)
OBJECTS = $(patsubst $(SRC_DIR)/%.c,$(OBJ_DIR)/%.o,$(SOURCES))

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(OBJ_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(TARGET) $(OBJECTS)
	rm -rf $(OBJ_DIR)

distclean: clean
	rm -f *.log *.out

.PHONY: all clean distclean