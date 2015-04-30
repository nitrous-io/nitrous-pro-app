#!/bin/bash
process_id=$1
app_path=$2
archive_path=$3

set -e

tmp_path=/tmp/nitrous-desktop-update
backup_path="$app_path".previous

echo "Waiting for $process_id to die"
while kill -0 $process_id > /dev/null 2>&1; do
  sleep 0.1
done

echo "Beginning update"
mkdir -p "$tmp_path"
rm -rf "$tmp_path"/*

unzip "$archive_path" -d "$tmp_path"
if [ -a $app_path  ]; then
  mv -f "$app_path" "$backup_path"
fi
mv -f "$tmp_path"'/Nitrous.app' "$app_path"

if [ -a $backup_path  ]; then
  rm -rf "$backup_path"
fi
rm -f "$archive_path"
rm -rf "$tmp_path"

echo "Update complete! Launching $app_path"
open "$app_path"
