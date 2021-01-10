create_partitions() {
    for partition in $(parted -s $selected_drive print 2>/dev/null | awk '/^ / {print $1}' | tac); do
        umount -l ${selected_drive}$partition > /dev/null 2>&1
        parted -s $selected_drive rm $partition

        echo "[INFO]: unmounting and deleting: ${selected_drive}$partition" >> archer.log
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


    echo "[INFO]: boot partition created and mounted: ->$([ -n "$(findmnt -o TARGET,FSTYPE ${selected_drive}1 | grep /boot | grep vfat)" ] && echo yes || echo no)<-" >> archer.log
    echo "[INFO]: root partition created and mounted: ->$([ -n "$(findmnt -o TARGET,FSTYPE ${selected_drive}2 | grep / | grep ext4)" ] && echo yes || echo no)<-" >> archer.log
}

download_mirrorlist() {
    api_endpoint="https://archlinux.org/mirrorlist/?"
    api_param_country="country=$mirrorlist_country&"
    api_param_protocol="protocol=http&protocol=https&ip_version=4"
    api_query="${api_endpoint}${api_param_country}${api_param_protocol}"
    curl -so /etc/pacman.d/mirrorlist "$api_query"
    sed -i '/^#.*Server /s/^#//' /etc/pacman.d/mirrorlist

    awk '/Server/ {print "[INFO]: mirror:", $3}' /etc/pacman.d/mirrorlist >> archer.log
}

#TODO: rank by file download speed
rank_mirrors() {
    echo -ne '' > /tmp/mirrorlist-ranked

    mirrorlist=($(awk '/Server/ { print $3 }' /etc/pacman.d/mirrorlist))

    for mirror in "${mirrorlist[@]}"; do
        host=$(grep -o '.*//[^/]*' <<< "$mirror")
        domain="$(cut -d'/' -f3 <<< $mirror)"
        index="$(expr $index + 1)"

        ping $domain -c 8 | awk "
        /time=/ {
            split(\$(NF-1), time, \"=\");
            total += time[2];
            crt++;
            progress = int(100 * crt / 8);
            print \"XXX\n\"progress\"\nPinging [$index/${#mirrorlist[@]}] $host - \"time[2]\" ms\nXXX\";
            fflush(stdout);
        }
        END {
            print total > \"/tmp/ping-result\"
        }"

        pingtime="$(cat /tmp/ping-result)"

        echo "$pingtime $mirror" >> /tmp/mirrorlist-ranked

        #url="$(eval echo $mirror)"

        #echo "$url"
#        package="$url/icu-1.22.4-3-x86_64.pkg.tar.xz"
#         $(expr $step \* 100 / ${#execution_order[@]})
        #groff_rtt="$({ time curl -s "$url/groff-1.22.4-3-x86_64.pkg.tar.xz" -o /dev/null; } 2>&1 | grep real)"
        #echo "$groff_rtt"

        #icu_rtt="$({ time curl -s "$url/icu-68.2-1-x86_64.pkg.tar.zst" -o /dev/null; } 2>&1 | grep real)"
        #echo "$icu_rtt"

        #curl https://mirrors.chroot.ro/archlinux/core/os/x86_64/ | grep -shoP '<tr>.*</tr>' | grep '>icu.*zst<'

        #echo -ne '\n\n\n'
    done
    cat /tmp/mirrorlist-ranked | sort -nk1 | awk '{ print "Server = "$2 }' > /etc/pacman.d/mirrorlist
    rm /tmp/ping-result
    rm /tmp/mirrorlist-ranked
#     TODO: debug log
}

enable_netcache() {
    sed -i "/\[core\]/i[netcache]\nSigLevel = Optional TrustAll\nServer = http://$netcache_ip:1337/\n" /etc/pacman.conf

    echo "[INFO]: netcache repository added to pacman.conf: $([ -n "$(grep netcache /etc/pacman.conf)" ] && echo yes || echo no)" >> archer.log
}

install_pacman_packages() {
    local packages=(
        base
        sudo

        make
        patch

        fakeroot
        binutils
        
# TODO: something about this?

        pkgconf
        gcc

#         linux
#         linux-firmware

        $([ "$cpu_vendor" = intel ] && echo intel-ucode)
        $([ "$cpu_vendor" = amd ] && echo amd-ucode)

        networkmanager

        #$([ "$gpu_configuration" = nvidia ] && echo nvidia)

        #$([ "$optimus_backend" = bumblebee ] && echo nvidia)
        #$([ "$optimus_backend" = bumblebee ] && echo bbswitch)
        #$([ "$optimus_backend" = bumblebee ] && echo bumblebee)

        #$([ "$optimus_backend" = optimus-manager ] && echo nvidia)
        #$([ "$optimus_backend" = optimus-manager ] && echo bbswitch)

#        $([ "$optimus_backend" = optimus-manager ] && echo optimus-manager) AUR package


        $([ "$login_shell" = bash ] && echo bash)
        $([ "$login_shell" = fish ] && echo fish)
        $([ "$login_shell" = zsh ] && echo zsh)

        $([ "$has_battery" = yes ] && echo tlp)
        $([ "$has_battery" = yes ] && [ "$has_wireless" = yes ] && echo tlp-rdw)

#         TODO: add menu bar
        $([ "$desktop_environment" = bspwm ] && echo bspwm sxhkd)

        $([ "$desktop_environment" = dwm ] && echo xorg-server xorg-xinit xorg-fonts-100dpi)

        $([ "$desktop_environment" = i3 ] && echo i3-gaps xorg-server xorg-xinit)

        $([ "$desktop_environment" = 'KDE Plasma' ] && echo bluedevil breeze-gtk kde-gtk-config kdeplasma-addons kgamma5 khotkeys kinfocenter kscreen kwayland-integration kwrited plasma-browser-integration plasma-desktop plasma-disks plasma-nm plasma-pa plasma-thunderbolt plasma-vault plasma-workspace plasma-workspace-wallpapers powerdevil sddm-kcm xdg-desktop-portal-kde)

        #$([ "$feature_bluetooth_audio" = yes ] && echo pulseaudio-bluetooth)

#TODO: bluetooth
#         pulseaudio-bluez
        ${extra_packages_official[@]}
    )

    for package in ${packages[@]}; do echo "[INFO]: package: $package" >> archer.log; done

    pacstrap /mnt ${packages[@]} 2>/dev/null | awk '
        /^:: Synchronizing package databases\.\.\.$/ {
            print "XXX\n0\nSynchronizing package databases\nXXX"
        }
        /^Packages \([0-9]*\)/ {
            total = substr($2, 2, length($2) - 2)
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
            message = substr($0, index($0, ")") + 2);
            print "XXX\n"progress"\n"substr(message, 0, length(message) - 3)"\nXXX"
        }
        {
            fflush(stdout)
        }
    '
}

#TODO: AUR dependency checks
#TODO: progress feedback
install_aur_packages() {
    local packages=(
        $([ "$desktop_environment" = dwm ] && echo dwm)
#         $([ "$optimus_backend" = optimus-manager ] && echo optimus-manager)
        ${extra_packages_aur[@]}
    )

    [ ${#packages[@]} = 0 ] && return

    for package in ${packages[@]}; do echo "[INFO]: AUR package: $package" >> archer.log; done

    sed -i '/^root.*/a nobody ALL=(ALL) NOPASSWD: ALL' /mnt/etc/sudoers

    #TODO: rework this kek
    #TODO: progress feedback
    local command="$(for i in $(seq 0 $(expr ${#packages[@]} - 1)); do
        echo "echo -e 'XXX\n$(expr $i \* 100 / ${#packages[@]})\nInstalling ${packages[$i]}\nXXX' &&"
        echo "sudo -u nobody bash -c 'HOME=/tmp; yay -S ${packages[$i]} --noconfirm >/dev/null 2>&1' &&"
    done) :"

    arch-chroot /mnt /bin/bash <<< "cd /tmp &&
        curl -sO https://aur.archlinux.org/cgit/aur.git/snapshot/yay-bin.tar.gz >/dev/null 2>&1 &&
        sudo -u nobody tar xfvz yay-bin.tar.gz > /dev/null 2>&1 &&
        cd yay-bin &&
        sudo -u nobody makepkg -risc --noconfirm > /dev/null 2>&1 &&
        cd /tmp &&
        rm yay-bin.tar.gz &&
        rm -rf yay-bin &&
        $command"

    sed -i '/^nobody.*/d' /mnt/etc/sudoers

    echo "[INFO]: aur packages installed: $(arch-chroot /mnt /bin/bash <<< 'pacman -Qm | wc -l')" >> archer.log
}

#TODO: other bootloader options
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

    echo "[INFO]: bootloader installed: $([ -n "$(grep UUID /mnt/boot/loader/entries/arch.conf)" ] && echo yes || echo no)" >> archer.log
}

generate_fstab() {
    genfstab -U /mnt >> /mnt/etc/fstab
    sed -i 's/relatime/noatime/g' /mnt/etc/fstab

    echo "[INFO]: fstab generated: $([ -n "$(grep noatime /mnt/etc/fstab)" ] && echo yes || echo no)" >> archer.log
}

generate_locale() {
    arch-chroot /mnt /bin/bash <<< "sed -i '/^#$locale/s/^#//' /etc/locale.gen && \
        locale-gen > /dev/null 2>&1"
    echo "LANG=$locale" > /mnt/etc/locale.conf

    echo "[INFO]: locale generated: $([ -n "$(grep $locale /mnt/etc/locale.conf)" ] && echo yes || echo no)" >> archer.log
}

set_timezone() {
    arch-chroot /mnt /bin/bash <<< "timedatectl set-ntp true && \
        ln -sf /usr/share/zoneinfo/$timezone /etc/localtime && \
        hwclock --systohc"

    echo "[INFO]: timezone configured: $([ -n "$(ls -la /mnt/etc/localtime | grep $timezone)" ] && echo yes || echo no)" >> archer.log
}

configure_network() {
    echo $hostname > /mnt/etc/hostname
    echo "127.0.0.1  localhost" >> /mnt/etc/hosts
    echo "::1        localhost" >> /mnt/etc/hosts
    echo "127.0.1.1  $hostname.localdomain $hostname" >> /mnt/etc/hosts

    echo "[INFO]: network configured: $([ -n "$(grep $hostname /mnt/etc/hosts)" ] && echo yes || echo no)" >> archer.log
}

set_root_password() {
    arch-chroot /mnt /bin/bash <<< "yes $password | passwd > /dev/null 2>&1"

    echo "[INFO]: password set for root: $([ -n "$(grep root /mnt/etc/shadow | grep '\$6\$')" ] && echo yes || echo no)" >> archer.log
}
