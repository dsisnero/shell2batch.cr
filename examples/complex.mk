# Complex Makefile with conditionals and functions
ifeq ($(OS),Windows_NT)
    RM = del /Q
    MKDIR = mkdir
else
    RM = rm -rf
    MKDIR = mkdir -p
endif

SOURCES = $(wildcard src/*.c)
OBJECTS = $(SOURCES:.c=.o)
TARGET = app
BUILD_DIR = build

all: $(BUILD_DIR) $(TARGET)

$(BUILD_DIR):
	$(MKDIR) $(BUILD_DIR)

$(TARGET): $(OBJECTS)
	$(CC) -o $(BUILD_DIR)/$@ $^

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $(BUILD_DIR)/$@

clean:
	$(RM) $(BUILD_DIR)

.PHONY: all clean