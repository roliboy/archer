create_partitions() {
    for partition in $(parted -s $selected_drive print 2>/dev/null | awk '/^ / {print $1}' | tac); do
        umount -l ${selected_drive}$partition > /dev/null 2>&1
        parted -s $selected_drive rm $partition

        echo "[DEBUG]: unmounting and deleting: ->${selected_drive}$partition<-" >> archer.log
    done

    parted -s $selected_drive mklabel gpt

    parted -s $selected_drive mkpart ESP fat32 1MiB 513MiB
    parted -s $selected_drive set 1 boot on
    parted -s $selected_drive mkpart primary ext4 513MiB 100%

    mkfs.vfat ${selected_drive}1 > /dev/null 2>&1
    mkfs.ext4 ${selected_drive}2 > /dev/null 2>&1

    mount ${selected_drive}2 /mnt
    mkdir /mnt/boot
    mount ${selected_drive}1 /mnt/boot


    echo "[DEBUG]: boot partition created and mounted: ->$([ -n "$(findmnt -o TARGET,FSTYPE ${selected_drive}1 | grep /boot | grep vfat)" ] && echo yes || echo no)<-" >> archer.log
    echo "[DEBUG]: root partition created and mounted: ->$([ -n "$(findmnt -o TARGET,FSTYPE ${selected_drive}2 | grep / | grep ext4)" ] && echo yes || echo no)<-" >> archer.log
}

#TODO: :thinking_face:
enable_ntp() {
    timedatectl set-ntp true

    echo "[DEBUG]: network time protocol: ->$(timedatectl show | grep '^NTP=' | cut -d'=' -f 2)<-" >> archer.log
}

# TODO: rank mirrors
download_mirrorlist() {
    api_endpoint="https://www.archlinux.org/mirrorlist/?"
    api_param_country="country=$mirrorlist_country&"
    api_param_protocol="protocol=http&protocol=https&ip_version=4"
    api_query="${api_endpoint}${api_param_country}${api_param_protocol}"
    curl -so /etc/pacman.d/mirrorlist "$api_query"
    sed -i '/^#.*Server /s/^#//' /etc/pacman.d/mirrorlist

    awk '/Server/ {print "[DEBUG]: mirror:", "->"$3"<-"}' /etc/pacman.d/mirrorlist >> archer.log
}

install_pacman_packages() {
    local packages=(
        base
        sudo
        make
        patch
#         TODO: condition?
        fakeroot
        binutils

#         linux
#         linux-firmware
        #$([ "$cpu_vendor" = intel ] && echo intel-ucode)
        #$([ "$cpu_vendor" = amd ] && echo amd-ucode)

        #networkmanager #dependency of plasma

        #TODO: do something about free/nonfree driver selection for nvidia
        $([ "$gpu_configuration" = nvidia ] && echo nvidia)

        $([ "$optimus_backend" = bumblebee ] && echo nvidia)
        $([ "$optimus_backend" = bumblebee ] && echo bbswitch)
        $([ "$optimus_backend" = bumblebee ] && echo bumblebee)

        $([ "$optimus_backend" = optimus-manager ] && echo nvidia)
        $([ "$optimus_backend" = optimus-manager ] && echo bbswitch)

#        $([ "$optimus_backend" = optimus-manager ] && echo optimus-manager) AUR package


        $([ "$login_shell" = bash ] && echo bash)
        $([ "$login_shell" = fish ] && echo fish)
        $([ "$login_shell" = zsh ] && echo zsh)

        #$([ "$has_battery" = yes ] && echo tlp)
        #$([ "$has_battery" = yes ] && [ "$has_wireless" = yes ] && echo tlp-rdw)

#         TODO: dependencies based on desktop environment
        $([ "$feature_bluetooth_audio" = yes ] && echo pulseaudio-bluetooth)

# TODO: bluetooth
#         pulseaudio-bluez
# TODO: provide multiple desktop environments
        #plasma
        #konsole
        #dolphin

        $([ "$feature_extra_packages" = yes ] && echo "${extra_packages_official[@]}")
    )

    for package in ${packages[@]}; do echo "[DEBUG]: package: ->$package<-" >> archer.log; done

    # remove "..." from post-transaction hooks
    pacstrap /mnt ${packages[@]} | awk '
        /^:: Synchronizing package databases\.\.\.$/ {
            print "XXX\n0\nSynchronizing package databases\nXXX"
        }
        /^Packages \([0-9]*\)/ {
            total=substr($2, 2, length($2) - 2)
        }
        /^downloading .*\.pkg\.tar.*\.\.\.$/ {
            dlindex++;
            print "XXX\n"int(dlindex*100/total)"\nDownloading "substr($2, 1, match($2, /\.pkg\.tar.*/) - 1)"\nXXX"
        }
        /^checking .*\.\.\.$/ {
            print "XXX\n0\nC"substr($0, 2, length($0) - 4)"\nXXX"
        }
        /^installing .*\.\.\.$/ {
            insindex++;
            print "XXX\n"int(insindex*100/total)"\nInstalling "substr($2, 1, length($2) - 3)"\nXXX"
        }
        /^:: Running post-transaction hooks\.\.\.$/ {
            print "XXX\n0\nRunning post-transaction hooks\nXXX"
        }
        /^\([ 0-9]+\/[0-9]+\)/ {
            progress = int(int(substr($0, 2, index($0, "/") - 2)) * 100 / int(substr($0, index($0, "/") + 1, index($0, ")") - index($0, "/") - 1)));
            print "XXX\n"progress"\n"substr($0, index($0, ")") + 2)"\nXXX"
        }
        {
            fflush(stdout)
        }
    '
}

enable_netcache() {
    #TODO: backup pacman.conf
    [ -n "$(grep netcache /etc/pacman.conf)" ] && return
    sed -i "/\[core\]/i[netcache]\nSigLevel = Optional TrustAll\nServer = http://$netcache_ip:1337/\n" /etc/pacman.conf
    echo "[DEBUG]: netcache repository added to pacman.conf: ->$([ -n "$(grep netcache /etc/pacman.conf)" ] && echo yes || echo no)<-" >> archer.log
}

enable_archstrike_repository() {
    echo '' >> /mnt/etc/pacman.conf
    echo '[archstrike]' >> /mnt/etc/pacman.conf
    echo 'Server = https://mirror.archstrike.org/$arch/$repo' >> /mnt/etc/pacman.conf

    arch-chroot /mnt /bin/bash <<< "pacman -Syy && \
        pacman-key --init && \
        curl -sO https://archstrike.org/keyfile.asc && \
        pacman-key --add keyfile.asc > /dev/null 2>&1 && \
        rm keyfile.asc && \
        pacman-key --lsign-key 9D5F1C051D146843CDA4858BDE64825E7CBC0D51 > /dev/null 2>&1 && \
        pacman -Sy archstrike-keyring --noconfirm > /dev/null 2>&1 && \
        pacman -Sy archstrike-mirrorlist --noconfirm > /dev/null 2>&1 && \
        sed -i '/mirror\.archstrike\.org/c\Include = /etc/pacman.d/archstrike-mirrorlist' /etc/pacman.conf && \
        pacman -Syy > /dev/null 2>&1"

    echo "[DEBUG]: archstrike repository enabled: ->$([ -n "$(grep archstrike-mirrorlist /mnt/etc/pacman.conf)" ] && echo yes || echo no)<-" >> archer.log
}

install_aur_packages() {
    local packages=(
        $([ "$optimus_backend" = optimus-manager ] && echo optimus-manager)
        $([ "$feature_extra_packages" = yes ] && echo "${extra_packages_aur[@]}")
    )

    for package in ${packages[@]}; do echo "[DEBUG]: AUR package: ->$package<-" >> archer.log; done

    sed -i '/^root.*/a nobody ALL=(ALL) NOPASSWD: ALL' /mnt/etc/sudoers

    for package in ${packages[@]}; do
        arch-chroot /mnt /bin/bash <<< "cd /tmp && \
            curl -sO https://aur.archlinux.org/cgit/aur.git/snapshot/$package.tar.gz > /dev/null 2>&1
            sudo -u nobody tar xfvz $package.tar.gz && \
            cd $package && \
            sudo -u nobody makepkg -risc --noconfirm && \
            cd /tmp && \
            rm $package.tar.gz && \
            rm -rf $package"
    done

    sed -i '/^nobody.*/d' /mnt/etc/sudoers

    echo "[DEBUG]: aur packages installed: ->$(arch-chroot /mnt /bin/bash <<< 'pacman -Qm | wc -l')<-" >> archer.log
}

generate_fstab() {
    genfstab -U /mnt >> /mnt/etc/fstab
    sed -i 's/relatime/noatime/g' /mnt/etc/fstab

    echo "[DEBUG]: fstab generated: ->$([ -n "$(grep noatime /mnt/etc/fstab)" ] && echo yes || echo no)<-" >> archer.log
}

generate_locale() {
    arch-chroot /mnt /bin/bash <<< "sed -i '/^#$locale/s/^#//' /etc/locale.gen && \
        locale-gen > /dev/null 2>&1"
    echo "LANG=$locale" > /mnt/etc/locale.conf

    echo "[DEBUG]: locale generated: ->$([ -n "$(grep $locale /mnt/etc/locale.conf)" ] && echo yes || echo no)<-" >> archer.log
}

install_bootloader() {
    arch-chroot /mnt /bin/bash <<< "bootctl --path=/boot install > /dev/null 2>&1"
    echo 'default arch-*' > /mnt/boot/loader/loader.conf
    echo 'title  Arch Linux' > /mnt/boot/loader/entries/arch.conf
    echo 'linux  /vmlinuz-linux' >> /mnt/boot/loader/entries/arch.conf

    [ "$cpu_vendor" = intel ] && \
        echo 'initrd /intel-ucode.img' >> /mnt/boot/loader/entries/arch.conf
    [ "$cpu_vendor" = amd ] && \
        echo 'initrd /amd-ucode.img' >> /mnt/boot/loader/entries/arch.conf

    echo 'initrd /initramfs-linux.img' >> /mnt/boot/loader/entries/arch.conf

    local root_uuid=$(blkid | \
        grep ${selected_drive}2 | \
        awk '{print $2}' | \
        cut -d'"' -f 2)

    echo "options root=UUID=$root_uuid rw" >> /mnt/boot/loader/entries/arch.conf

    echo "[DEBUG]: bootloader installed: ->$([ -n "$(grep UUID /mnt/boot/loader/entries/arch.conf)" ] && echo yes || echo no)<-" >> archer.log
}

set_timezone() {
    arch-chroot /mnt /bin/bash <<< "timedatectl set-ntp true && \
        ln -sf /usr/share/zoneinfo/$timezone /etc/localtime && \
        hwclock --systohc"

    echo "[DEBUG]: timezone configured: ->$([ -n "$(ls -la /mnt/etc/localtime | grep $timezone)" ] && echo yes || echo no)<-" >> archer.log
}

configure_network() {
    echo $hostname > /mnt/etc/hostname
    echo "127.0.0.1  localhost" >> /mnt/etc/hosts
    echo "::1        localhost" >> /mnt/etc/hosts
    echo "127.0.1.1  $hostname.localdomain $hostname" >> /mnt/etc/hosts

    echo "[DEBUG]: network configured: ->$([ -n "$(grep $hostname /mnt/etc/hosts)" ] && echo yes || echo no)<-" >> archer.log
}

configure_pacman() {
    sed -i '/Color/s/^#//g' /mnt/etc/pacman.conf
    sed -i '/CheckSpace/s/^#//g' /mnt/etc/pacman.conf
    sed -i '/VerbosePkgLists/s/^#//g' /mnt/etc/pacman.conf
    sed -i '/VerbosePkgLists/a ILoveCandy' /mnt/etc/pacman.conf

    echo "[DEBUG]: pacman configured: ->$([ -n "$(grep ILoveCandy /mnt/etc/pacman.conf)" ] && echo yes || echo no)<-" >> archer.log
}

#TODO: modify master file
#TODO: add auto-cpufreq
configure_tlp() {
    [ "$optimus_backend" = bumblebee ] && \
        echo 'RUNTIME_PM_DRIVER_BLACKLIST="nouveau nvidia"' > /mnt/etc/tlp.d/10-driver-blacklist.conf

    echo "[DEBUG]: tlp configured: ->$([ -n "$(grep nvidia /mnt/etc/tlp.d/10-driver-blacklist.conf)" ] && echo yes || echo no)<-" >> archer.log
}

configure_journald() {
    sed -i 's/#SystemMaxUse.*/SystemMaxUse=50M/g' /mnt/etc/systemd/journald.conf

    echo "[DEBUG]: journald configured: ->$([ -n "$(grep '^SystemMaxUse' /mnt/etc/systemd/journald.conf)" ] && echo yes || echo no)<-" >> archer.log
}

configure_coredump() {
    sed -i 's/#Storage.*/Storage=none/g' /mnt/etc/systemd/coredump.conf

    echo "[DEBUG]: coredump configured: ->$([ -n "$(grep '^Storage' /mnt/etc/systemd/coredump.conf)" ] && echo yes || echo no)<-" >> archer.log
}

enable_services() {
    arch-chroot /mnt /bin/bash <<< "systemctl enable NetworkManager.service > /dev/null 2>&1"

    [ "$has_battery" = yes ] && arch-chroot /mnt /bin/bash <<< "systemctl enable tlp.service > /dev/null 2>&1"

    [ "$has_battery" = yes ] && [ "$has_wireless" = yes ] && \
        arch-chroot /mnt /bin/bash <<< "systemctl enable NetworkManager-dispatcher.service > /dev/null 2>&1 && \
            systemctl mask systemd-rfkill.service > /dev/null 2>&1 && \
            systemctl mask systemd-rfkill.socket > /dev/null 2>&1"

    [ "$has_ssd" = yes ] && arch-chroot /mnt /bin/bash <<< "systemctl enable fstrim.timer > /dev/null 2>&1"
    [ "$optimus_backend" = optimus ] && arch-chroot /mnt /bin/bash <<< "systemctl enable bumblebeed.service > /dev/null 2>&1"
    [ "$optimus_backend" = optimus-manager ] && arch-chroot /mnt /bin/bash <<< "systemctl enable optimus-manager.service > /dev/null 2>&1"

    [ "$desktop_environment" = 'KDE Plasma' ] && arch-chroot /mnt /bin/bash <<< "systemctl enable sddm.service"
#       bluetooth
}

set_root_password() {
    arch-chroot /mnt /bin/bash <<< "yes $password | passwd > /dev/null 2>&1"

    echo "[DEBUG]: password set for root: ->$([ -n "$(grep root /mnt/etc/shadow | grep '\$6\$')" ] && echo yes || echo no)<-" >> archer.log
}

create_user() {
    arch-chroot /mnt /bin/bash <<< "groupadd $username && \
        useradd $username -m -g $username -G wheel && \
        yes $password | passwd $username > /dev/null 2>&1 && \
        chown -R $username:$username /home/$username && \
        usermod --shell /bin/$login_shell $username"

    [ "$optimus_backend" = bumblebee ] && \
        arch-chroot /mnt /bin/bash <<< "gpasswd -a $username bumblebee > /dev/null"

    # TODO: check for other properties
    echo "[DEBUG]: user created: ->$([ -n "$(grep $username /mnt/etc/shadow | grep '\$6\$')" ] && echo yes || echo no)<-" >> archer.log
}

enable_passwordless_sudo() {
    sed -i '/%wheel ALL=(ALL) NOPASSWD: ALL/s/^# //' /mnt/etc/sudoers

#     TODO: debug check
}

enable_autologin() {
    # TODO: handle different display managers

    [ "$desktop_environment" = 'KDE Plasma' ] && \
        echo -e "[Autologin]\nUser=$username\nSession=plasma.desktop" > /mnt/etc/sddm.conf.d/autologin.conf

    # mkdir /mnt/etc/systemd/getty@tty1.service.d ?
    [ "$desktop_environment" = 'None' ] && \
        echo -e "[Service]\nExecStart=\nExecStart=-/usr/bin/agetty --autologin $username --noclear %I \$TERM" > /mnt/etc/system/systemd/getty@tty1.service.d/override.conf

    [ "$desktop_environment" = 'KDE Plasma' ] && \
        echo "[DEBUG]: autologin enabled: ->$([ -n "$(grep $username /mnt/etc/sddm.conf.d/autologin.conf)" ] && echo yes || echo no)<-" >> archer.log
    # TODO: debug check
}
