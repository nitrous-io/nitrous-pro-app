#!/bin/bash
script=$1
process_id=$2
app_path=$3
archive_path=$4

logger -t nitrous-pro-updater "Script: $script"
logger -t nitrous-pro-updater "PID: $process_id"
logger -t nitrous-pro-updater "App Path: $app_path"
logger -t nitrous-pro-updater "Archive Path: $archive_path"
logger -t nitrous-pro-updater "Script: $script"

$script "$process_id" "$app_path" "$archive_path" 2>&1 | logger -t nitrous-pro-updater
