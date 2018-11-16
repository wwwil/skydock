#!/bin/bash

IMG_LINK=http://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2018-10-11/2018-10-09-raspbian-stretch-lite.zip
IMG_ZIP=$(basename $IMG_LINK)

# Download zip and extract the img
if [ ! -f "$IMG_ZIP" ]; then
	wget -nv $IMG_LINK
fi
unzip -o *.zip

# Create loop device map from image partition table
LOOP_DEV=$(losetup --show --find --partscan *.img)

# Wait a second or mount may fail
sleep 1

# Make mount point and mount image
mkdir -p /mnt/raspbian
mount -o rw ${LOOP_DEV}p2 /mnt/raspbian
mount -o rw ${LOOP_DEV}p1 /mnt/raspbian/boot

# Create bind mounts for system directories
mount --bind /dev /mnt/raspbian/dev/
mount --bind /sys /mnt/raspbian/sys/
mount --bind /proc /mnt/raspbian/proc/
mount --bind /dev/pts /mnt/raspbian/dev/pts

# Apply ld.so.preload fix
sed -i 's/^/#CHROOT /g' /mnt/raspbian/etc/ld.so.preload

# Copy qemu binary
cp /usr/bin/qemu-arm-static /mnt/raspbian/usr/bin/

# Chroot to raspbian
chroot /mnt/raspbian ls /boot

# Revert ld.so.preload fix
sed -i 's/^#CHROOT //g' /mnt/raspbian/etc/ld.so.preload

# Unmount everything
umount /mnt/raspbian/{dev/pts,dev,sys,proc,boot,}
