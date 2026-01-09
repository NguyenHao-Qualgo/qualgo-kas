#!/bin/sh

echo ">>> [load-modules] Running!"

MOD_DIR="/lib/modules/$(uname -r)"

find "$MOD_DIR" -name '*.ko' | while read -r module; do
  echo "Loading module $module"
  insmod "$module" || echo "Failed to load $module"
done
