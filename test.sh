#!/bin/sh

# Some basic commands to run on the Raspbian system to confirm chroot is working
# and generate some information output

uname -a

ls /
ls /boot

apt-get update