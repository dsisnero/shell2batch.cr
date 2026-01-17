# Makefile demonstrating automatic variables

program: main.o utils.o
	$(CC) $^ -o $@  # $^ = all dependencies, $@ = target name

main.o: main.c
	$(CC) -c $< -o $@  # $< = first dependency

utils.o: utils.c utils.h
	$(CC) -c $< -o $@  # $< = first dependency (utils.c)

clean:
	rm -f program *.o

.PHONY: clean