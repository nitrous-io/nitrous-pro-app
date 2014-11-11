#!/bin/bash
process_id=$1
app_path=$2
archive_path=$3

set -e

tmp_path=/tmp/nitrous-desktop-update
backup_path="$app_path".previous

while kill -0 $process_id > /dev/null 2>&1; do
  sleep 0.1
done

mkdir -p "$tmp_path"
rm -rf "$tmp_path"/*

unzip "$archive_path" -d "$tmp_path"
mv -f "$app_path" "$backup_path"
mv -f "$tmp_path"'/Nitrous' "$app_path"

rm -rf "$backup_path"
rm -f "$archive_path"
rm -rf "$tmp_path"

cd $app_path

"$app_path/nitrous"
