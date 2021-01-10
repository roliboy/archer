configure_pacman() {
    sed -i '/Color/s/^#//g' /mnt/etc/pacman.conf
    sed -i '/CheckSpace/s/^#//g' /mnt/etc/pacman.conf
    sed -i '/VerbosePkgLists/s/^#//g' /mnt/etc/pacman.conf
    sed -i '/VerbosePkgLists/a ILoveCandy' /mnt/etc/pacman.conf

    echo "[INFO]: pacman configured: $(grep -q ILoveCandy /mnt/etc/pacman.conf 2>/dev/null && echo yes || echo no)" >> archer.log
}

#TODO: modify master file
#TODO: add auto-cpufreq
configure_tlp() {
    [[ $optimus_backend = bumblebee ]] && echo 'RUNTIME_PM_DRIVER_BLACKLIST="nouveau nvidia"' > /mnt/etc/tlp.d/10-driver-blacklist.conf

    echo "[INFO]: tlp configured: $(grep -q nvidia /mnt/etc/tlp.d/10-driver-blacklist.conf 2>/dev/null && echo yes || echo no)" >> archer.log
}

configure_journald() {
    sed -i 's/#SystemMaxUse.*/SystemMaxUse=50M/g' /mnt/etc/systemd/journald.conf

    echo "[INFO]: journald configured: $(grep -q ^SystemMaxUse /mnt/etc/systemd/journald.conf 2>/dev/null && echo yes || echo no)" >> archer.log
}

configure_coredump() {
    sed -i 's/#Storage.*/Storage=none/g' /mnt/etc/systemd/coredump.conf

    echo "[INFO]: coredump configured: $(grep -q ^Storage /mnt/etc/systemd/coredump.conf 2>/dev/null && echo yes || echo no)" >> archer.log
}

# TODO: redirect errors
create_user() {
    arch-chroot /mnt /bin/bash <<< "groupadd $username && \
        useradd $username -m -g $username -G wheel && \
        yes $password | passwd $username > /dev/null 2>&1 && \
        chown -R $username:$username /home/$username && \
        usermod --shell /bin/$login_shell $username"

    [ "$optimus_backend" = bumblebee ] && \
        arch-chroot /mnt /bin/bash <<< "gpasswd -a $username bumblebee > /dev/null"

# TODO: check for other properties
    echo "[INFO]: user created: $(grep $username /mnt/etc/shadow | grep -q '\$6\$' && echo yes || echo no)" >> archer.log
}

# TODO: redirect errors
# TODO: debug check
enable_services() {
    arch-chroot /mnt /bin/bash <<< "systemctl enable NetworkManager.service > /dev/null 2>&1"

    [[ $has_battery = yes ]] && arch-chroot /mnt /bin/bash <<< "systemctl enable tlp.service > /dev/null 2>&1"

    [[ $has_battery = yes ]] && [[ $has_wireless = yes ]] && \
        arch-chroot /mnt /bin/bash <<< "systemctl enable NetworkManager-dispatcher.service > /dev/null 2>&1 && \
            systemctl mask systemd-rfkill.service > /dev/null 2>&1 && \
            systemctl mask systemd-rfkill.socket > /dev/null 2>&1"

    [[ $has_ssd = yes ]] && arch-chroot /mnt /bin/bash <<< "systemctl enable fstrim.timer > /dev/null 2>&1"
    [[ $optimus_backend = optimus ]] && arch-chroot /mnt /bin/bash <<< "systemctl enable bumblebeed.service > /dev/null 2>&1"
    [[ $optimus_backend = optimus-manager ]] && arch-chroot /mnt /bin/bash <<< "systemctl enable optimus-manager.service > /dev/null 2>&1"

    [[ $desktop_environment = dwm ]] && echo 'exec dwm' > "/mnt/home/$username/.xinitrc"
    [[ $desktop_environment = i3 ]] && echo 'exec i3' > "/mnt/home/$username/.xinitrc"
    [[ $desktop_environment = 'KDE Plasma' ]] && arch-chroot /mnt /bin/bash <<< "systemctl enable sddm.service"
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

    echo "[INFO]: archstrike repository enabled: $(grep -q archstrike-mirrorlist /mnt/etc/pacman.conf 2>/dev/null && echo yes || echo no)" >> archer.log
}

enable_passwordless_sudo() {
    sed -i '/%wheel ALL=(ALL) NOPASSWD: ALL/s/^# //' /mnt/etc/sudoers

    echo "[INFO]: passwordless sudo enabled: $(grep -q '^%wheel ALL=(ALL) NOPASSWD: ALL$' /mnt/etc/sudoers 2>/dev/null && echo yes || echo no)" >> archer.log
}

# TODO: handle different display managers
enable_autologin() {
    if [[ $desktop_environment = 'KDE Plasma' ]]; then
        echo -e "[Autologin]\nUser=$username\nSession=plasma.desktop" > /mnt/etc/sddm.conf.d/autologin.conf
        echo "[INFO]: autologin enabled: $(grep -q $username /mnt/etc/sddm.conf.d/autologin.conf 2>/dev/null && echo yes || echo no)" >> archer.log
    fi

    # mkdir /mnt/etc/systemd/getty@tty1.service.d ?
    if [[ $desktop_environment = None ]]; then
        echo -e "[Service]\nExecStart=\nExecStart=-/usr/bin/agetty --autologin $username --noclear %I \$TERM" > /mnt/etc/system/systemd/getty@tty1.service.d/override.conf
        # TODO: debug check
    fi
}
