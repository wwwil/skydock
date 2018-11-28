#!/bin/bash

# Add a FAT32 data partion to a Rasbian .img file

set -e

IMG_FILE=$1

# These could be set by args
# Size should be in MiB
PART_SIZE=64
# Name will be converted to uppercase
PART_NAME=DATA
# Mount is relative to root of image
PART_MOUNT=/data

# Currently only FAT32 is supported
PART_TYPE=fat32

# Use parted to print the partition table
PARTED_OUT=$(parted -s "${IMG_FILE}" unit b print)
echo "PARTED OUTPUT: $PARTED_OUT"

# Find the end of the root partition
# This assumes there are two partitons
ROOT_END=$(echo "$PARTED_OUT" | grep -e '^ 2'| xargs echo -n \
| cut -d" " -f 3 | tr -d B)

# Determine where to start the new partition so that it is properly
# aligned to 4MiB erase blocks
BLOCK=$((4 * 1024 * 1024))
PART_START=$((($ROOT_END + 1) / $BLOCK))
PART_START=$((($PART_START + 1) * $BLOCK))

# Work out how much to expand the image to fit the new partition
PART_EXPAND=
# Convert PART_SIZE from MiB to B
PART_EXPAND=$(($PART_SIZE * 1024 * 1024))
# Add the free space gap required between the end of the previous
# partiton and the new one
PART_EXPAND=$(($PART_EXPAND + ($PART_START - $ROOT_END)))
# Ensure the expansion aligns with 512B sector
PART_EXPAND=$(($PART_EXPAND / 512))
PART_EXPAND=$((($PART_EXPAND + 1) * 512))
# Convert to MiB for quicker dd
PART_EXPAND=$(($PART_EXPAND / (1024 * 1024)))

# Print values
echo "ROOT_END: $ROOT_END"
echo "PART_START: $PART_START"
echo "PART_EXPAND: $PART_EXPAND"

# Expand the image with zeros using dd
dd if=/dev/zero bs=1M count=$PART_EXPAND >> $IMG_FILE

# Use parted to print the partition table
parted -s "${IMG_FILE}" unit b print free

# Create the partition in the new space
parted -a none -s "${IMG_FILE}" mkpart primary "${PART_TYPE}" "${PART_START}B" 100%

# Use parted to print the partition table
parted -s "${IMG_FILE}" unit b print free

# Check the partiton is optimally aligned
parted -s "${IMG_FILE}" align-check opt 3

# Mount the image as a loop device
LOOP_DEV=$(losetup --show --find --partscan $IMG_FILE)
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
# Make mount point and mount image
ROOTFS_DIR=/mnt/raspbian
mkdir -p $ROOTFS_DIR
mount -o rw ${LOOP_DEV}p2 $ROOTFS_DIR
mount -o rw ${LOOP_DEV}p1 ${ROOTFS_DIR}/boot

# Format the partiton
PART_NAME=$(echo $PART_NAME | tr a-z A-Z )
mkdosfs -n "${PART_NAME}" -F 32 -v "${LOOP_DEV}p3" > /dev/null

# Use parted to print the partition table
parted -s "${IMG_FILE}" unit b print free

# Create the mount point
mkdir /mnt/raspbian/$PART_MOUNT
mount -o rw ${LOOP_DEV}p2 ${ROOTFS_DIR}/${PART_MOUNT}

# List the contents of mount point to verify mount was successful
echo "CONTENTS OF /:"
ls ${ROOTFS_DIR}
echo "CONTENTS OF /boot:"
ls ${ROOTFS_DIR}/boot

# Add the partition mount to /etc/fstab
IMG_ID="$(dd if="${IMG_FILE}" skip=440 bs=1 count=4 2>/dev/null | xxd -e | cut -f 2 -d' ')"
echo "IMG_ID: $IMG_ID"
BOOT_PARTUUID="${IMG_ID}-01"
ROOT_PARTUUID="${IMG_ID}-02"
DATA_PARTUUID="${IMG_ID}-03"
sed -i "s/PARTUUID=[a-z0-9]*-01/PARTUUID=${BOOT_PARTUUID}/" "${ROOTFS_DIR}/etc/fstab"
sed -i "s/PARTUUID=[a-z0-9]*-02/PARTUUID=${ROOT_PARTUUID}/" "${ROOTFS_DIR}/etc/fstab"
echo "PARTUUID=${DATA_PARTUUID} ${PART_MOUNT} vfat defaults 0 1" >> "${ROOTFS_DIR}/etc/fstab"
echo "FSTAB:"
cat "${ROOTFS_DIR}/etc/fstab"

# Update cmdline.txt to use the new PARTUUID
sed -i "s/PARTUUID=[a-z0-9]*-02/PARTUUID=${ROOT_PARTUUID}/" "${ROOTFS_DIR}/boot/cmdline.txt"
# Remove the reference to the expand rootfs script as it can no longer be
# expanded with the new partition in the way
sed -i "s/init=.*//" "${ROOTFS_DIR}/boot/cmdline.txt"
echo "CMDLINE.TXT:"
cat "${ROOTFS_DIR}/boot/cmdline.txt"

# Unmount partitions and reset loop device
umount /mnt/raspbian/{${PART_MOUNT},boot,}
losetup -d $LOOP_DEV
echo "SUCCESSFULLY ADDED PARTITION AND UNMOUNTED IMG"
