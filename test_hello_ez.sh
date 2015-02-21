#!/bin/sh
mkdir mnt
./hello mnt &
sleep 5
ls mnt
fusermount -u mnt
rm -rf mnt
