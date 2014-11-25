ENV=development
ATOM_SHELL_VERSION=0.19.1

all: build

setup:
	script/setup $(ATOM_SHELL_VERSION)

clean:
	rm -rf build/
	rm -rf rails/tmp

test:
	script/test $(ATOM_SHELL_VERSION)

build:
	script/build $(ENV) $(ATOM_SHELL_VERSION)

build-dev:
	script/build development $(ATOM_SHELL_VERSION)

build-prod:
	script/build production $(ATOM_SHELL_VERSION)

run: build
	script/run $(ENV) $(ATOM_SHELL_VERSION)

run-dev:
	script/run development $(ATOM_SHELL_VERSION)

run-prod:
	script/run production $(ATOM_SHELL_VERSION)

archive: build-prod
	script/archive

upload: archive
	script/upload

watch: build-dev
	watchy -w 'app,css,images,index.html.slim' -- make build-dev

.PHONY: setup clean build build-dev build-prod run watch test
