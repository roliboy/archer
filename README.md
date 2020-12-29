![Archer](/images/archer.png)

# archer

Automated Arch Linux install script for brainlets

### anon what do

- download arch
- make usb with arch
- boot arch
- `curl -s roliboy.ml/archer | bash`
- done

disclaimer: it will nuke your entire drive

### additional steps

- pray to /g/ everything is working

### requirements

- internet connection
- at least three brain cells

### my internet speed sucks but i alrady use arch btw

run another suspicious script **as root**, this time on your existing arch machine

```bash
curl -s roliboy.ml/netcache | sudo bash
```

and on the new system tick the use netcache box on the additional features dialog
you will be asked to enter the ip address of the machine on which the netcache script is running

### features

- GUI (sort-of) installer
- detect cpu vendor and install correct microcode
- detect gpu configuration and install proprietary drivers (and gpu switching for optimus laptops)
- detect battery and install tlp for optimizing power consumption
- detect wireless and install tlp-rdw
- detect ssd and enable automatic trimming
- automatically download mirrorlist from selected country
- automatically generate selected locale
- automatically set timezone and ntp
- set root password
- create user
- multiple DE/WM choices (only KDE for now)
- enable autologin
- set up archstrike repository
- automatic partitioning
- minimal base installation
- install selected packages from aur
- automatic fstab generation
- install bootloader
- auto-configure network
- auto-configure pacman
- auto-configure tlp
- auto-configure journald
- auto-configure coredump

### planned featurs
- shell options for new user
- rank mirrors by speed
- detect bluetooth and install bluez (and option for installing bluez-pulseaudio for bluetooth headphones/speakers)
- multiple backends for gpu switching (currently only bumblebee is supported)
- add auto-cpufreq for automatic cpu speed and power optimization

### setup

packages required
- qemu
- edk2-ovmf

download the official arch iso and create a qemu disk image

```bash
$ ./test.sh setup
```

start the emulator with

```bash
./test.sh run
```

the guest machine can also be accessed through ssh on port 10022

```bash
ssh -p 10022 root@localhost
```
