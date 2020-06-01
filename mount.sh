#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

IMG_FILE=$1

# Find a free loop device to use.
LOOP_DEV=$(losetup --find)
# If the device file does not exist then use `mknod` to create it.
if [ ! -e $LOOP_DEV ]; then
    mknod -m 0660 $LOOP_DEV b 7 0
fi
# Mount the image as a loop device.
LOOP_DEV=$(losetup --show --partscan $LOOP_DEV $IMG_FILE)
# Make the LOOP_DEV environment variable available to other scripts.
export LOOP_DEV

# Wait a second or mount may fail.
sleep 1

# Get a list of partitions in the image.
PARTITIONS=$(lsblk --raw --output "MAJ:MIN" --noheadings ${LOOP_DEV} | tail -n +2)

# Manually use `mknod` to create nodes for partitions on the loop device.
COUNTER=1
for i in $PARTITIONS; do
    MAJ=$(echo $i | cut -d: -f1)
    MIN=$(echo $i | cut -d: -f2)
    if [ ! -e "${LOOP_DEV}p${COUNTER}" ]; then mknod ${LOOP_DEV}p${COUNTER} b $MAJ $MIN; fi
    COUNTER=$((COUNTER + 1))
done

# If we previously expanded the root partition we must also expand the file
# system. This must be done after loop device creation but before mounting.
if [ $EXPAND -gt "0" ]; then
    e2fsck -fp -B 512 ${LOOP_DEV}p2
    resize2fs ${LOOP_DEV}p2
fi

# Make mount point, mount image, and make the ROOTFS_DIR environment variable
# available to other scripts.
export ROOTFS_DIR=/mnt/rootfs
mkdir -p $ROOTFS_DIR
mount -o rw ${LOOP_DEV}p2 $ROOTFS_DIR
mount -o rw ${LOOP_DEV}p1 ${ROOTFS_DIR}/boot

# Create bind mounts for system directories.
mount --bind /dev ${ROOTFS_DIR}/dev/
mount --bind /sys ${ROOTFS_DIR}/sys/
mount --bind /proc ${ROOTFS_DIR}/proc/
mount --bind /dev/pts ${ROOTFS_DIR}/dev/pts

# List the contents of mount point to verify mount was successful.
echo "CONTENTS OF /:"
ls ${ROOTFS_DIR}
echo "CONTENTS OF /boot:"
ls ${ROOTFS_DIR}/boot
