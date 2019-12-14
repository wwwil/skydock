#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

# Set EXPAND to first argument, or 0 if not provided
EXPAND="${1:-0}"

echo "SOURCE_IMAGE: $SOURCE_IMAGE"
echo "EXPAND: $EXPAND"

# Convert from MiB to B
PART_EXPAND=$(($EXPAND * 1024 * 1024))
# Ensure the expansion aligns with 4096B (and therefore also 512B) sectors
PART_EXPAND=$(($PART_EXPAND / 4096))
PART_EXPAND=$((($PART_EXPAND + 1) * 4096))
# Convert to KiB for quicker dd
PART_EXPAND=$(($PART_EXPAND / 1024))

# Determine the current size of the partition
SIZE_BEFORE=$(parted -s "${SOURCE_IMAGE}" unit KiB print | grep -e '^ 2' \
| xargs echo -n | cut -d" " -f 4 | tr -d kiB)

# Find the end of the root partition
# This assumes there are two partitions
ROOT_END=$(parted -s "${SOURCE_IMAGE}" unit KiB print | grep -e '^ 2' \
| xargs echo -n | cut -d" " -f 3 | tr -d kiB)

ROOT_END_NEW=$(($ROOT_END + $PART_EXPAND - 1))

parted -s "${SOURCE_IMAGE}" unit KiB print free

dd bs=1K if=/dev/zero count=$PART_EXPAND >> $SOURCE_IMAGE

parted -s "${SOURCE_IMAGE}" unit KiB print free

# Resize the second partition to fill the free space
parted -s "${SOURCE_IMAGE}" resizepart 2 "${ROOT_END_NEW}KiB"

parted -s "${SOURCE_IMAGE}" unit KiB print free

# Determine the new size of the partition
SIZE_AFTER=$(parted -s "${SOURCE_IMAGE}" unit KiB print | grep -e '^ 2' \
| xargs echo -n | cut -d" " -f 4 | tr -d kiB)

SIZE_DIFFERENCE=$(($SIZE_AFTER - $SIZE_BEFORE))
if [ "$SIZE_DIFFERENCE" != "$PART_EXPAND" ]; then
    echo "Expand error, SIZE_BEFORE: $SIZE_BEFORE, SIZE_AFTER: $SIZE_AFTER, SIZE_DIFFERENCE: $SIZE_DIFFERENCE"
    exit 1
fi
