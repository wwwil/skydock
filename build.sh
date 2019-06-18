#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

ADD_DATA_PART=${ADD_DATA_PART:-false}

echo "MOUNT: $MOUNT"
echo "SOURCE_IMAGE: $SOURCE_IMAGE"
echo "SCRIPT: $SCRIPT"
echo "ADD_DATA_PART: $ADD_DATA_PART"

if [ $ADD_DATA_PART != false ]; then
	source ./add-partition.sh $SOURCE_IMAGE
fi

# Create loop device map from image partition table
LOOP_DEV=$(losetup --show --find --partscan $SOURCE_IMAGE)

# If this fails, exit here
if [ $? -ne 0 ]; then
	exit 1
fi

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
mkdir -p /mnt/raspbian
mount -o rw ${LOOP_DEV}p2 /mnt/raspbian
mount -o rw ${LOOP_DEV}p1 /mnt/raspbian/boot

if [ $ADD_DATA_PART != false ]; then
	mount -o rw ${LOOP_DEV}p3 /mnt/raspbian/data
fi

# Create bind mounts for system directories
mount --bind /dev /mnt/raspbian/dev/
mount --bind /sys /mnt/raspbian/sys/
mount --bind /proc /mnt/raspbian/proc/
mount --bind /dev/pts /mnt/raspbian/dev/pts

mkdir /mnt/raspbian/$MOUNT
mount --bind $MOUNT /mnt/raspbian/$MOUNT

# Apply ld.so.preload fix
sed -i 's/^/#CHROOT /g' /mnt/raspbian/etc/ld.so.preload

# Copy qemu binary
cp /usr/bin/qemu-arm-static /mnt/raspbian/usr/bin/

# Enable qemu-arm
update-binfmts --enable qemu-arm

# Chroot to raspbian
chroot /mnt/raspbian $SCRIPT

# Revert ld.so.preload fix
sed -i 's/^#CHROOT //g' /mnt/raspbian/etc/ld.so.preload

# Unmount everything
if [ $ADD_DATA_PART != false ]; then
	umount /mnt/raspbian/data
fi
umount /mnt/raspbian/{dev/pts,dev,sys,proc,boot,${MOUNT},}
losetup -d $LOOP_DEV
