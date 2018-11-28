#!/bin/sh

# Some basic commands to run on the Raspbian system to confirm chroot is working
# and generate some information output

uname -a

ls /
ls /boot
ls /data

for PART_NUMBER in 1 2 3; do
	parted align-check opt $PART_NUMBER
done

apt-get update