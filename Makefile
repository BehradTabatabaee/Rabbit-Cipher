CC = aarch64-linux-gnu-g++
AS = aarch64-linux-gnu-as
CFLAGS = -O3 -Wall -Wextra
QEMU = qemu-aarch64

all: rabbit

rabbit: main.o rabbit.o
	$(CC) -static -o $@ $^

main.o: main.cpp
	$(CC) $(CFLAGS) -c -o $@ $<

rabbit.o: rabbit.s
	$(AS) -o $@ $<

run: rabbit
	$(QEMU) ./rabbit

clean:
	rm -f *.o rabbit