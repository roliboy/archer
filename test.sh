#!/bin/bash
qemu-system-x86_64 \
    -boot order=d,menu=on,reboot-timeout=5000 \
    -m size=1G,slots=3,maxmem=4G \
    -k en \
    -name archer,process=archer-vm \
    -device virtio-scsi-pci,id=scsi0 \
    -device scsi-cd,bus=scsi0.0,drive=cdrom0 \
    -drive id=cdrom0,if=none,format=raw,media=cdrom,readonly=on,file=archlinux-2020.11.01-x86_64.iso \
    -drive file=arch.img,format=qcow2 \
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

#-drive if=pflash,format=raw,unit=0,file=/usr/share/edk2-ovmf/x64/OVMF_CODE.fd,readonly \
#-drive if=pflash,format=raw,unit=1,file=/usr/share/edk2-ovmf/x64/OVMF_VARS.fd,readonly \
#   -nic user,hostfwd=tcp::10022-:22 \
#   -device virtio-net-pci,romfile=,netdev=net0 \
#   -netdev user,id=net0 \
#   -serial stdio \
#   -audiodev pa,id=snd0 \
#   -device ich9-intel-hda \
#   -device hda-output,audiodev=snd0 \
#   #,pcspk-audiodev=snd0 \
#   -bios /usr/share/edk2-ovmf/x64/OVMF_CODE.fd \
