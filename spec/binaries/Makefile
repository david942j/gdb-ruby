source=source.cpp
FLAGS=
PIE_FLAGS=-pie -fPIC
NOPIE_FLAGS=-no-pie
TARGETS=amd64
.PHONY: clean
all: ${TARGETS}

amd64: ${source}
	g++ -m64 ${source} -o amd64.elf ${FLAGS} ${NOPIE_FLAGS}
	g++ -m64 ${source} -o amd64.pie.elf ${FLAGS} ${PIE_FLAGS}
	g++ -m64 ${source} -o amd64.pie.strip.elf ${FLAGS} ${PIE_FLAGS}
	strip -s amd64.pie.strip.elf

clean:
	rm -f *.elf
