#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

ADD_DATA_PART=${ADD_DATA_PART:-false}
EXPAND=${EXPAND:-0}

# These are the env vars that should be passed in from docker
echo "MOUNT: $MOUNT"
echo "SOURCE_IMAGE: $SOURCE_IMAGE"
echo "SCRIPT: $SCRIPT"
echo "ADD_DATA_PART: $ADD_DATA_PART"
echo "EXPAND: $EXPAND"

# If expand has been set then run the expand script
if [ $EXPAND -gt "0" ]; then
    source ./expand.sh $EXPAND
fi

# If ADD_DATA_PART is true then add a data partiton
if [ $ADD_DATA_PART != false ]; then
	source ./add-partition.sh $SOURCE_IMAGE
	# The add-partition script runs mount
else
	# Or mount is run here directly
	source ./mount.sh $SOURCE_IMAGE
fi

# The add-partition or mount scripts must set LOOP_DEV and ROOTFS_DIR
echo "LOOP_DEV: $LOOP_DEV"
echo "ROOTFS_DIR: $ROOTFS_DIR"

# Bind mount the directory specified as MOUNT. This is for scripts to run
# inside Raspbian and data to copy in
mkdir ${ROOTFS_DIR}/${MOUNT}
mount --bind $MOUNT ${ROOTFS_DIR}/${MOUNT}

# Apply ld.so.preload fix
sed -i 's/^/#CHROOT /g' /mnt/raspbian/etc/ld.so.preload

# Copy the `qemu` binary for arm and arm64 into the image.
cp /usr/bin/qemu-arm-static ${ROOTFS_DIR}/usr/bin/
cp /usr/bin/qemu-aarch64-static ${ROOTFS_DIR}/usr/bin/

# Enable `qemu-arm` and `qemu-aarch64` for arm64.
update-binfmts --enable qemu-arm
update-binfmts --enable qemu-aarch64

# Chroot to the mounted Raspbian environment and run the SCRIPT
chroot ${ROOTFS_DIR} $SCRIPT

# Revert ld.so.preload fix
sed -i 's/^#CHROOT //g' ${ROOTFS_DIR}/etc/ld.so.preload

# Unmount everything
if [ $ADD_DATA_PART != false ]; then
	umount ${ROOTFS_DIR}/data
fi
umount ${ROOTFS_DIR}/{dev/pts,dev,sys,proc,boot,${MOUNT},}
losetup -d $LOOP_DEV
echo "SUCCESSFULLY UNMOUNTED IMG"
