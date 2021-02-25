#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

# Set `EXPAND` to first script argument, or 0 if not provided.
EXPAND="${1:-0}"

echo "SOURCE_IMAGE: $SOURCE_IMAGE"
echo "EXPAND: $EXPAND"

# Determine the current size of the partition.
PARTED_OUT=$(parted -s "${SOURCE_IMAGE}" unit MiB print)
SIZE_BEFORE=$(echo -e "${PARTED_OUT}" | grep -e '^ 2' | xargs echo -n \
| cut -d" " -f 4 | tr -d MiB)

# Find the end of the root partition. This assumes there are two partitions.
ROOT_END=$(echo -e "${PARTED_OUT}" | grep -e '^ 2' | xargs echo -n \
| cut -d" " -f 3 | tr -d MiB)

ROOT_END_NEW=$(($ROOT_END + $EXPAND))

parted -s "${SOURCE_IMAGE}" unit MiB print free

# Expand the image slightly more than required for the new partition.
qemu-img resize -f raw $SOURCE_IMAGE "+$((EXPAND + 1))M"

parted -s "${SOURCE_IMAGE}" unit MiB print free

# Resize the second partition to fill the free space.
parted -s "${SOURCE_IMAGE}" resizepart 2 "${ROOT_END_NEW}MiB"

parted -s "${SOURCE_IMAGE}" unit MiB print free

# Check the partition is optimally aligned.
parted -s "${SOURCE_IMAGE}" align-check opt 2

# Determine the new size of the partition.
SIZE_AFTER=$(parted -s "${SOURCE_IMAGE}" unit MiB print | grep -e '^ 2' \
| xargs echo -n | cut -d" " -f 4 | tr -d MiB)

SIZE_DIFFERENCE=$(($SIZE_AFTER - $SIZE_BEFORE))
if [ "$SIZE_DIFFERENCE" != "$EXPAND" ]; then
    echo "Expand error, SIZE_BEFORE: $SIZE_BEFORE, SIZE_AFTER: $SIZE_AFTER, SIZE_DIFFERENCE: $SIZE_DIFFERENCE"
    exit 1
fi
