#!/bin/bash

mkdir -p build/root
# Replace the current disk image with a blank FAT16 image
# TODO: This is dumb, just make a blank image
cp -f resources/blank.img build/boot.img

# Compile every assembly file:
# boot and strap are edge cases
nasm -f bin source/boot.asm -o build/boot.bin
nasm -f bin source/strap.asm -o build/root/boot
# Every other file gets compiled as filename.asm -> filename.sys
find source -name *.asm ! -name boot.asm ! -name strap.asm -print0 | while read -d $'\0' file
do
  nasm $file -o ./build/root/$(basename $file | cut -d'.' -f1).sys
done

# Mount boot.img, then write our bootsector to it
# TODO: Make this whole section OS-ambiguous
dev=$(hdid -nomount build/boot.img)
dd bs=512 count=1 if=build/boot.bin of=$dev

# Mount boot.img as a volume, then copy our files to it
hdid build/boot.img
mountpoint=$(diskutil info $dev | grep 'Mount Point' | cut -d : -f 2 | sed 's/^ *//g' | sed 's/ *$//g')
cp -R -v ./build/root/* "$mountpoint"

# Eject boot.img now, since we our done
hdiutil eject $dev
