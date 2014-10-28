ATOM_SHELL_VERSION=0.18.2

all: build

setup:
	script/setup

clean:
	rm -rf build/

build:
	script/build $(ATOM_SHELL_VERSION)

run: build
	script/run $(ATOM_SHELL_VERSION)

.PHONY: setup build
