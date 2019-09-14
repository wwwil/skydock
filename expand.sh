#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

# Set EXPAND to first argument, or 0 if not provided
EXPAND="${1:-0}"

# Add EXPAND * 1M to the end of the image
dd bs=1M if=/dev/zero count=$EXPAND >> $SOURCE_IMAGE

# Resize the second partition to fill the free space
parted -s "${SOURCE_IMAGE}" resizepart 2 100%
