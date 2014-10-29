ATOM_SHELL_VERSION=0.18.2

all: build

setup:
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
	watchy -w 'app,css,images,index.html.slim' -- make build-dev

.PHONY: setup clean build build-dev run watch
