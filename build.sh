#!/bin/bash

echo "SOURCE_IMAGE: $SOURCE_IMAGE"
echo "SCRIPT: $SCRIPT"

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
umount /mnt/raspbian/{dev/pts,dev,sys,proc,boot,${MOUNT},}
