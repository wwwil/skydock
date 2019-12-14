#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

# Set EXPAND to first argument, or 0 if not provided
EXPAND="${1:-0}"

# Determine the current size of the partition
SIZE_BEFORE=$(parted -s "${SOURCE_IMAGE}" unit Mib print | grep -e '^ 2' \
| xargs echo -n | cut -d" " -f 4 | tr -d MiB)

# Add EXPAND * 1M to the end of the image
dd bs=1M if=/dev/zero count=$EXPAND >> $SOURCE_IMAGE

# Resize the second partition to fill the free space
parted -s "${SOURCE_IMAGE}" resizepart 2 100%

# Determine the new size of the partition
SIZE_AFTER=$(parted -s "${SOURCE_IMAGE}" unit Mib print | grep -e '^ 2' \
| xargs echo -n | cut -d" " -f 4 | tr -d MiB)

SIZE_DIFFERENCE=$(($SIZE_AFTER - $SIZE_BEFORE))
# Expanding to 100% may actually expand the partition slightly more than the
# specified amount as the image file may have other empty space at the end. As
# long as the size difference isn't less than the specified amount then this
# check can pass.
if [ "$SIZE_DIFFERENCE" -lt "$EXPAND" ]; then
    echo "Expand error, SIZE_BEFORE: $SIZE_BEFORE, SIZE_AFTER: $SIZE_AFTER, SIZE_DIFFERENCE: $SIZE_DIFFERENCE"
    exit 1
fi
