#!/bin/bash
script_dir=`dirname "$0"`
"$script_dir"/nitrous-unison "$@" 2> /dev/null
