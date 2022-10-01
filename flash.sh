#!/bin/bash

file="zig-out/bin/$1.uf2"
device="$2"

if [ ! -f "$file" ]; then
  echo "flash <file> [<device>]" >&2
  exit 1
fi

if [ -z "$device" ]; then
  device=/dev/rp2040upl1
fi

while [ ! -b "$device" ]; do
  echo "$(date '+%H:%M:%S') please connect $device"
  sleep 1
done

mcopy -i "$device" "$file" ::/

