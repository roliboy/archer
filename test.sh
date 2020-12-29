#!/bin/bash

case "$1" in
	setup)
		echo downloading iso file
		curl -L 'http://mirrors.evowise.com/archlinux/iso/2020.12.01/archlinux-2020.12.01-x86_64.iso' -o archlinux.iso
		echo creating disk image file
		qemu-img create -f qcow2 archlinux.img 8G
		;;
	run)
		echo starting qemu
		qemu-system-x86_64 \
			-boot order=d,menu=on,reboot-timeout=5000 \
			-m size=1G,slots=3,maxmem=4G \
			-k en \
			-name archer,process=archer-vm \
			-device virtio-scsi-pci,id=scsi0 \
			-device scsi-cd,bus=scsi0.0,drive=cdrom0 \
			-drive id=cdrom0,if=none,format=raw,media=cdrom,readonly=on,file=archlinux.iso \
			-drive file=archlinux.img,format=qcow2 \
			-display sdl \
			-vga virtio \
			-usb \
			-device usb-tablet,bus=usb-bus.0,port=1 \
			-net nic \
			-net user,hostfwd=tcp::10022-:22 \
			-smp 1 \
			-cpu host \
			-machine type=q35,smm=on,accel=kvm,usb=on \
			-global ICH9-LPC.disable_s3=1 \
			-enable-kvm \
			-bios /usr/share/edk2-ovmf/x64/OVMF_CODE.fd \
			-global driver=cfi.pflash01,property=secure,value=off \
			-no-reboot
		;;
	*)
		echo invalid argument
		;;
esac
