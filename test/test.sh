#!/bin/sh

# Some basic commands to run inside the image OS to confirm `chroot` is working
# and generate some information output.

set -e

uname -a

ls /
ls /boot
if [ -f /data ]; then
    ls /data
fi

lsblk

apt-get update
