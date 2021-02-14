create_partitions() {
    for partition in $(parted -s $selected_drive print 2>/dev/null | awk '/^ / {print $1}' | tac); do
        umount -l ${selected_drive}$partition > /dev/null 2>&1
        parted -s $selected_drive rm $partition

        info "unmounting and deleting: ${selected_drive}$partition"
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


    info "boot partition created and mounted: $(findmnt -o TARGET,FSTYPE ${selected_drive}1 | grep /boot | grep -q vfat && echo yes || echo no)"
    info "root partition created and mounted: $(findmnt -o TARGET,FSTYPE ${selected_drive}2 | grep / | grep -q ext4 && echo yes || echo no)"
}

download_mirrorlist() {
    local api_endpoint="https://archlinux.org/mirrorlist/?"
    local api_param_country="country=$mirrorlist_country&"
    local api_param_protocol="protocol=http&protocol=https&ip_version=4"
    local api_query="${api_endpoint}${api_param_country}${api_param_protocol}"
    curl -so /etc/pacman.d/mirrorlist "$api_query"
    sed -i '/^#.*Server /s/^#//' /etc/pacman.d/mirrorlist

    while read mirror; do
        [[ $mirror =~ Server ]] && info "mirror $mirror"
    done < /etc/pacman.d/mirrorlist
}

rank_mirrors() {
    echo -ne '' > /tmp/mirrorlist

    mirrorlist=($(awk '/Server/ { print $3 }' /etc/pacman.d/mirrorlist))
    # packages=(gcc-fortran-10.2.0-4-x86_64.pkg.tar.zst glibc-2.32-5-x86_64.pkg.tar.zst icu-68.2-1-x86_64.pkg.tar.zst)
    # TODO: dynamic package selection
    packages=(bash-5.1.004-1-x86_64.pkg.tar.zst openssl-1.0-1.0.2.u-1-x86_64.pkg.tar.zst sqlite-3.34.0-1-x86_64.pkg.tar.zst)

    total_downloads=$((${#mirrorlist[@]} * ${#packages[@]}))
    
    for i in ${!mirrorlist[@]}; do
        host=$(grep -o '.*//[^/]*' <<< "${mirrorlist[i]}")
        let index=$i+1
        base_url="$(sed 's/$repo/core/g; s/$arch/x86_64/g' <<< ${mirrorlist[i]})"

        start_time=$(date +%s%3N)
        for package_index in ${!packages[@]}; do
            url="$base_url/${packages[package_index]}"

            echo -e 'XXX'
            echo -e $(((current_progress * 100 + progress[rank_mirrors] * (i * ${#packages[@]} + package_index) * 100 / total_downloads) / total_progress))
            # TODO: echo download speed
            echo -e "Testing mirror $host"
            echo -e 'XXX'

            # TODO: handle timeouts
            curl -s "$url" -o /dev/null --connect-timeout 2 2>archer.err
        done
        total_time=$(($(date +%s%3N) - start_time))

        check_stderr && cat archer.err >> archer.err2

        # TODO: clean up this
        echo "$total_time Server = ${mirrorlist[i]}" >> /tmp/mirrorlist
    done

    cat /tmp/mirrorlist | sort -k1n | cut -d' ' -f2- > /etc/pacman.d/mirrorlist    
    rm /tmp/mirrorlist
#     TODO: debug log
}

enable_netcache() {
    sed -i "/\[core\]/i[netcache]\nSigLevel = Optional TrustAll\nServer = http://$netcache_ip:1337/\n" /etc/pacman.conf

    info "netcache repository added to pacman.conf: $(grep -q netcache /etc/pacman.conf && echo yes || echo no)"
}

install_packages() {
    local aur_packages=(
        $([[ $desktop_environment = dwm ]] && echo dwm)
#         $([ "$optimus_backend" = optimus-manager ] && echo optimus-manager)
        ${extra_packages_aur[@]}
    )

    local official_packages=(
        base
        sudo

        make
        patch

        $([[ ${#aur_packages[@]} != 0 ]] && echo fakeroot)
        $([[ ${#aur_packages[@]} != 0 ]] && echo binutils)

#         pkgconf?
#         gcc?

        linux
        linux-firmware

        $([[ $cpu_vendor = intel ]] && echo intel-ucode)
        $([[ $cpu_vendor = amd ]] && echo amd-ucode)

        networkmanager

        $([[ $gpu_configuration = nvidia ]] && echo nvidia)

        #$([ "$optimus_backend" = bumblebee ] && echo nvidia)
        #$([ "$optimus_backend" = bumblebee ] && echo bbswitch)
        #$([ "$optimus_backend" = bumblebee ] && echo bumblebee)

        #$([ "$optimus_backend" = optimus-manager ] && echo nvidia)
        #$([ "$optimus_backend" = optimus-manager ] && echo bbswitch)

#        $([ "$optimus_backend" = optimus-manager ] && echo optimus-manager) AUR package


        $([[ $login_shell = bash ]] && echo bash)
        $([[ $login_shell = fish ]] && echo fish)
        $([[ $login_shell = zsh ]] && echo zsh)

        $([[ $has_battery = yes ]] && echo tlp)
        $([[ $has_battery = yes ]] && [[ $has_wireless = yes ]] && echo tlp-rdw)

#         TODO: add menu bar
        $([[ $desktop_environment = bspwm ]] && echo bspwm sxhkd)

        $([[ $desktop_environment = dwm ]] && echo xorg-server xorg-xinit xorg-fonts-100dpi)

        $([[ $desktop_environment = i3 ]] && echo i3-gaps xorg-server xorg-xinit)

        $([[ $desktop_environment = 'KDE Plasma' ]] && echo bluedevil breeze-gtk kde-gtk-config kdeplasma-addons kgamma5 khotkeys kinfocenter kscreen kwayland-integration kwrited plasma-browser-integration plasma-desktop plasma-disks plasma-nm plasma-pa plasma-thunderbolt plasma-vault plasma-workspace plasma-workspace-wallpapers powerdevil sddm-kcm xdg-desktop-portal-kde)
        
#         bluedevil breeze breeze-gtk kactivitymanagerd kde-cli-tools kdecoration kde-gtk-config kdeplasma-addons kgamma5 khotkeys kinfocenter kmenuedit kscreen kscreenlocker ksshaskpass ksysguard kwallet-pam kwayland-integration kwayland-server kwin kwrited plasma-browser-integration plasma-desktop plasma-disks plasma-integration plasma-nm plasma-pa plasma-thunderbolt plasma-vault plasma-workspace plasma-workspace-wallpapers polkit-kde-agent powerdevil sddm-kcm systemsettings xdg-desktop-portal-kde

        #$([ "$feature_bluetooth_audio" = yes ] && echo pulseaudio-bluetooth)

#TODO: bluetooth
#         pulseaudio-bluez
        ${extra_packages_official[@]}
    )

    for package in ${official_packages[@]}; do info "package: $package"; done
    

    pacstrap /mnt ${official_packages[@]} 2>/dev/null | awk "
        BEGIN {
            current = $current_progress;
            weight = ${progress[install_packages]} * $([[ ${#aur_packages[@]} == 0 ]] && echo 1 || echo 0.6);
            scale = 100 / $total_progress;
        }
        /^:: Synchronizing package databases\.\.\.$/ {
            progress = int(current * scale);
            print \"XXX\n\"progress\"\nSynchronizing package databases\nXXX\"
        }
        /^Packages \([0-9]*\)/ {
            total = substr(\$2, 2, length(\$2) - 2)
        }
        /^downloading .*\.pkg\.tar.*\.\.\.$/ {
            dlindex++;
            progress = int((current + 0.4 * weight * dlindex / total) * scale);
            print \"XXX\n\"progress\"\nDownloading \"substr(\$2, 1, match(\$2, /\.pkg\.tar.*/) - 1)\"\nXXX\"
        }
        /^checking .*\.\.\.$/ {
            progress = int((current + 0.4 * weight) * scale);
            print \"XXX\n\"progress\"\nC\"substr(\$0, 2, length(\$0) - 4)\"\nXXX\"
        }
        /^installing .*\.\.\.$/ {
            insindex++;
            progress = int((current + 0.4 * weight + 0.4 * weight * insindex / total) * scale);
            print \"XXX\n\"progress\"\nInstalling \"substr(\$2, 1, length(\$2) - 3)\"\nXXX\"
        }
        /^:: Running post-transaction hooks\.\.\.$/ {
            progress = int((current + 0.8 * weight) * scale);
            print \"XXX\n\"progress\"\nRunning post-transaction hooks\nXXX\"
        }
        /^\([ 0-9]+\/[0-9]+\)/ {
            percentage = (int(substr(\$0, 2, index(\$0, \"/\") - 2)) / int(substr(\$0, index(\$0, \"/\") + 1, index(\$0, \")\") - index(\$0, \"/\") - 1)));
            progress = int((current + 0.8 * weight + 0.2 * weight * percentage) * scale);
            message = substr(\$0, index(\$0, \")\") + 2);
            print \"XXX\n\"progress\"\n\"substr(message, 0, length(message) - 3)\"\nXXX\"
        }
        {
            fflush(stdout)
        }
    "
    
    
    # TODO: remove helper after installation

    [[ ${#aur_packages[@]} = 0 ]] && return
    
#     for package in ${aur_packages[@]}; do info "AUR package: $package"; done

    sed -i '/^root.*/a nobody ALL=(ALL) NOPASSWD: ALL' /mnt/etc/sudoers

    # TODO: progress feedback
    # TODO: replace yay
    local command="$(for i in $(seq 0 $(expr ${#aur_packages[@]} - 1)); do
        echo "echo -e 'XXX\n$(awk "BEGIN{print int(($current_progress + 0.6 * ${progress[install_packages]} + ($i / ${#aur_packages[@]}) * 0.4 * ${progress[install_packages]}) * 100 / $total_progress)}")\nInstalling ${aur_packages[$i]}\nXXX' &&"
        echo "sudo -u nobody bash -c 'HOME=/tmp; yay -S ${aur_packages[$i]} --noconfirm >/dev/null 2>&1' &&"
    done)"
    
    echo -e "XXX\n$(awk "BEGIN{print int(($current_progress + 0.6 * ${progress[install_packages]}) * 100 / $total_progress)}")\nInitializing AUR build system\nXXX"

    arch-chroot /mnt /bin/bash <<< "cd /tmp &&
        curl -sO https://aur.archlinux.org/cgit/aur.git/snapshot/yay-bin.tar.gz >/dev/null 2>&1 &&
        sudo -u nobody tar xfvz yay-bin.tar.gz > /dev/null 2>&1 &&
        cd yay-bin &&
        sudo -u nobody makepkg -risc --noconfirm > /dev/null 2>&1 &&
        cd /tmp &&
        rm yay-bin.tar.gz &&
        rm -rf yay-bin &&
        $command
        pacman -Rns --noconfirm yay-bin"

    sed -i '/^nobody.*/d' /mnt/etc/sudoers

    for package in ${aur_packages[@]}; do
        info "AUR package '$package': $(arch-chroot /mnt /bin/bash <<< "pacman -Qs ^$package$ >/dev/null && echo installed || echo not installed")"
    done
}

#TODO: other bootloader options
install_bootloader() {
    arch-chroot /mnt /bin/bash <<< "bootctl --path=/boot install > /dev/null 2>&1"
    echo 'default arch-*' > /mnt/boot/loader/loader.conf
    echo 'title  Arch Linux' > /mnt/boot/loader/entries/arch.conf
    echo 'linux  /vmlinuz-linux' >> /mnt/boot/loader/entries/arch.conf

    [[ $cpu_vendor = intel ]] && echo 'initrd /intel-ucode.img' >> /mnt/boot/loader/entries/arch.conf
    [[ $cpu_vendor = amd ]] && echo 'initrd /amd-ucode.img' >> /mnt/boot/loader/entries/arch.conf

    echo 'initrd /initramfs-linux.img' >> /mnt/boot/loader/entries/arch.conf

    local root_uuid=$(blkid | \
        grep ${selected_drive}2 | \
        awk '{print $2}' | \
        cut -d'"' -f 2)

    echo "options root=UUID=$root_uuid rw" >> /mnt/boot/loader/entries/arch.conf

    info "bootloader installed: $(grep -q UUID /mnt/boot/loader/entries/arch.conf 2>/dev/null && echo yes || echo no)"
}

generate_fstab() {
    genfstab -U /mnt >> /mnt/etc/fstab
    sed -i 's/relatime/noatime/g' /mnt/etc/fstab

    info "fstab generated: $(grep -q noatime /mnt/etc/fstab 2>/dev/null && echo yes || echo no)"
}

generate_locale() {
    arch-chroot /mnt /bin/bash <<< "sed -i '/^#$locale/s/^#//' /etc/locale.gen && \
        locale-gen > /dev/null 2>&1"
    echo "LANG=$locale" > /mnt/etc/locale.conf

    info "locale generated: $(grep -q $locale /mnt/etc/locale.conf 2>/dev/null && echo yes || echo no)"
}

set_timezone() {
    arch-chroot /mnt /bin/bash <<< "timedatectl set-ntp true && \
        ln -sf /usr/share/zoneinfo/$timezone /etc/localtime && \
        hwclock --systohc"

    info "timezone configured: $(ls -la /mnt/etc/localtime | grep -q $timezone && echo yes || echo no)"
}

configure_network() {
    echo $hostname > /mnt/etc/hostname
    echo "127.0.0.1  localhost" >> /mnt/etc/hosts
    echo "::1        localhost" >> /mnt/etc/hosts
    echo "127.0.1.1  $hostname.localdomain $hostname" >> /mnt/etc/hosts

    info "network configured: $(grep -q $hostname /mnt/etc/hosts 2>/dev/null && echo yes || echo no)"
}

set_root_password() {
    arch-chroot /mnt /bin/bash <<< "yes $password | passwd > /dev/null 2>&1"

    info "password set for root: $(grep root /mnt/etc/shadow 2>/dev/null | grep -q '\$6\$' && echo yes || echo no)"
}
