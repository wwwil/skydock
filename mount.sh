#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

# We can do this the easy way, or the hard way...
if [ -e /dev/loop0 ]; then
	# Mount the image as a loop device
	LOOP_DEV=$(losetup --show --find --partscan $IMG_FILE)
else
	# Oh I see you've chosen the hard way...
	# Mount host /dev to /tmp/dev
	mkdir -p /tmp/dev
	mount -t devtmpfs none /tmp/dev
	# Use mknod to manually create loop devices
	mknod -m 0660 "/tmp/dev/loop0" b 7 0
	# Mount the image as a loop device
	LOOP_DEV=$(losetup --show --partscan "/tmp/dev/loop0" $IMG_FILE)
fi
# Make the LOOP_DEV env var available to other scripts
export LOOP_DEV

# Wait a second or mount may fail
sleep 1

# Get list of partitions, drop the first line, as this is our
# LOOP_DEV itself, we only what the child partitions
PARTITIONS=$(lsblk --raw --output "MAJ:MIN" --noheadings ${LOOP_DEV} | tail -n +2)

# Manually use mknod to create nodes for partitons on loop device
# Testing indicates this is required when running in a container,
# even if the containter is run --pivileged
COUNTER=1
for i in $PARTITIONS; do
    MAJ=$(echo $i | cut -d: -f1)
    MIN=$(echo $i | cut -d: -f2)
    if [ ! -e "${LOOP_DEV}p${COUNTER}" ]; then mknod ${LOOP_DEV}p${COUNTER} b $MAJ $MIN; fi
    COUNTER=$((COUNTER + 1))
done

# Make mount point, mount image and make the ROOTFS_DIR env var available to
# other scripts
export ROOTFS_DIR=/mnt/raspbian
mkdir -p $ROOTFS_DIR
mount -o rw ${LOOP_DEV}p2 $ROOTFS_DIR
mount -o rw ${LOOP_DEV}p1 ${ROOTFS_DIR}/boot

# Create bind mounts for system directories
mount --bind /dev /mnt/raspbian/dev/
mount --bind /sys /mnt/raspbian/sys/
mount --bind /proc /mnt/raspbian/proc/
mount --bind /dev/pts /mnt/raspbian/dev/pts

# List the contents of mount point to verify mount was successful
echo "CONTENTS OF /:"
ls ${ROOTFS_DIR}
echo "CONTENTS OF /boot:"
ls ${ROOTFS_DIR}/boot
