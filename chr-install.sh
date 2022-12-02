#!/bin/bash

IMG_URL="https://down.idc.wiki/Image/Mikrotik/chr-6.48.6.img"
IMG_FILE=$(mktemp)
ROOT_DISK=`df -h / | tail -n 1  | awk '{print $1}' | sed 's/\([0-9]\+\)//g'`

INTERFACE=$(ip r | grep default | awk -F'dev' '{print $2}' | awk '{print $1}')
GATEWAY=$(ip r | grep default | awk -F'via' '{print $2}' | awk '{print $1}' | head -n 1)
ADDRESS=$(ip a | grep scope | grep $INTERFACE | awk '{print $2}' | head -n 1)
MACADDRESS=$(ip link | grep -A 1 $INTERFACE | grep link | awk '{print $2}' | head -n 1)

trap "rm -f $IMG_FILE" EXIT

setup_loop(){
    modprobe loop >/dev/null 2>&1
    losetup -D
}

if [ ! -b "$ROOT_DISK" ]
then
    echo "$ROOT_DISK must be a block device"
    exit 1
fi;


command -v partprobe >/dev/null 2>&1
if [ $? -ne 0 ]
then
    echo "partprobe is missing"
    exit 1
fi;

if [ ! -z "$1" ]
then
    echo "Using $1 as image"
    IMG_URL="$1"
fi;

wget -O $IMG_FILE $IMG_URL
if [ $? -ne 0 ]
then
    echo "Failed to download image file"
    exit 1
fi;

setup_loop

rm -rf /tmp/chr >/dev/null 2>&1
mkdir /tmp/chr

losetup /dev/loop0 $IMG_FILE
if [ $? -ne 0 ]
then
    echo "Failed to mount image file"
    exit 1
fi

partprobe /dev/loop0
mount /dev/loop0p1 /tmp/chr

echo "/ip address add address=$ADDRESS interface=[/interface ethernet find where mac-address=$MACADDRESS]" > /tmp/chr/autorun.scr
echo "/ip route add gateway=$GATEWAY" >> /tmp/chr/autorun.scr

umount /tmp/chr
losetup -d /dev/loop0

echo u > /proc/sysrq-trigger
dd if=$IMG_FILE of=$ROOT_DISK
reboot
