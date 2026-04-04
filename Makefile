.PHONY: all run test build install clean

all: build

run:
	dart bin/tka.dart $(ARGS)

test:
	dart test

build:
	dart pub get
	mkdir -p build
	dart compile exe bin/tka.dart -o build/tka

install: build
	mkdir -p $(HOME)/.local/bin
	cp build/tka $(HOME)/.local/bin/tka

clean:
	rm -rf build/
