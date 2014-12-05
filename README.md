Nitrous Pro Desktop App
=======================

### Dependencies

* Xcode Command Line Tools or Xcode (OS X only) (call `xcode-select` to force install)
* wget (available via brew)
* bundler
* npm (available via brew)

### Setup

```
bundle install
make setup
```

### Develop

```
make watch
```

### Release

This requires codesign certs.

```
make build-prod
```

- - - - -
Copyright (c) 2014 Nitrous, Inc. All Rights Reserved.
