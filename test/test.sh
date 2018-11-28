#!/bin/sh

# Some basic commands to run on the Raspbian system to confirm chroot is working
# and generate some information output

set -e

uname -a

ls /
ls /boot
ls /data

lsblk

apt-get update