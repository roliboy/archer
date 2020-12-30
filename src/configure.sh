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

enable_passwordless_sudo() {
    sed -i '/%wheel ALL=(ALL) NOPASSWD: ALL/s/^# //' /mnt/etc/sudoers

    echo "[DEBUG]: passwordless sudo enabled: ->$([ -n "$(grep '^%wheel ALL=(ALL) NOPASSWD: ALL$' /mnt/etc/sudoers)" ] && echo yes || echo no)<-" >> archer.log
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
