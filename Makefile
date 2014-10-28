ATOM_SHELL_VERSION=0.18.2

all: build

setup: build-fsevents
	script/setup $(ATOM_SHELL_VERSION)

clean:
	rm -rf build/

build:
	script/build

build-dev:
	script/build development

run: build-dev
	script/run $(ATOM_SHELL_VERSION)

watch: build-dev
	bundle exec guard start

build-fsevents:
	script/build-fsevents $(ATOM_SHELL_VERSION)

.PHONY: setup clean build build-dev run watch build-fsevents
