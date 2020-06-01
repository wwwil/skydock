#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

ADD_DATA_PART=${ADD_DATA_PART:-false}
EXPAND=${EXPAND:-0}

# These are the environment variables that should be passed in from Docker.
echo "MOUNT: $MOUNT"
echo "SOURCE_IMAGE: $SOURCE_IMAGE"
echo "SCRIPT: $SCRIPT"
echo "ADD_DATA_PART: $ADD_DATA_PART"
echo "EXPAND: $EXPAND"

# If `EXPAND` has been set then run `expand.sh` to increase the size of
# the image's root file system.
if [ $EXPAND -gt "0" ]; then
    source ./expand.sh $EXPAND
fi

# If `ADD_DATA_PART` is true then run `add-partition.sh` to add a data partition
# after the root partition.
if [ $ADD_DATA_PART != false ]; then
	source ./add-partition.sh $SOURCE_IMAGE
    # `add-partition.sh` also runs `mount.sh` to mount the image as a loop
    # device.
else
	# Otherwise run `mount.sh` directly directly.
	source ./mount.sh $SOURCE_IMAGE
fi

# The `LOOP_DEV` and `ROOTFS_DIR` environment variables should now be set by
# `add-partition.sh` or `mount.sh`.
echo "LOOP_DEV: $LOOP_DEV"
echo "ROOTFS_DIR: $ROOTFS_DIR"

# Bind mount the directory specified as MOUNT. This is for scripts to run
# inside the image and for data to be copied in.
mkdir ${ROOTFS_DIR}/${MOUNT}
mount --bind $MOUNT ${ROOTFS_DIR}/${MOUNT}

# Apply `ld.so.preload` fix.
if [ -f ${ROOTFS_DIR}/etc/ld.so.preload ]; then
    sed -i 's/^/#CHROOT /g' ${ROOTFS_DIR}/etc/ld.so.preload
fi

# Copy the `qemu` binary for arm and arm64 into the image.
cp /usr/bin/qemu-arm-static ${ROOTFS_DIR}/usr/bin/
cp /usr/bin/qemu-aarch64-static ${ROOTFS_DIR}/usr/bin/

# Enable `qemu-arm` and `qemu-aarch64` for arm64.
update-binfmts --enable qemu-arm
update-binfmts --enable qemu-aarch64

# Ensure `SCRIPT` is executable.
chmod +x $SCRIPT

# `chroot` into the mounted image and run the `SCRIPT`.
chroot ${ROOTFS_DIR} $SCRIPT

# Revert `ld.so.preload` fix if it was applied.
if [ -f ${ROOTFS_DIR}/etc/ld.so.preload ]; then
    sed -i 's/^#CHROOT //g' ${ROOTFS_DIR}/etc/ld.so.preload
fi

# Unmount everything and remove the loop device.
if [ $ADD_DATA_PART != false ]; then
	umount ${ROOTFS_DIR}/data
fi
umount ${ROOTFS_DIR}/{dev/pts,dev,sys,proc,boot,${MOUNT},}
losetup --detach $LOOP_DEV
echo "SUCCESSFULLY UNMOUNTED IMG"
