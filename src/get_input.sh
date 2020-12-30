get_drive() {
    whiptail --title 'Target drive' \
        --menu 'Select drive:' \
        0 0 0 \
        $(
            lsblk -lno PATH,SIZE,MODEL,TYPE |
            awk '/disk/ { print $1, $2"<"$3">" }'
        ) \
        3>&1 1>&2 2>&3
}

#TODO: experiment with box height
get_mirrorlist_country() {
    whiptail --title 'Mirrorlist' \
        --menu 'Select country: ' \
        0 0 0 \
        $(
            curl -s https://archlinux.org/mirrorlist/ |
            awk -F'[<">]' '/<option value=".*">.*<\/option>/ { gsub(" ", "-", $5); print $3, $5 }'
        ) \
        3>&1 1>&2 2>&3
}

get_locale() {
    whiptail --title 'Locale' \
        --menu 'Select locale: ' \
        0 0 0 \
        $(
            awk -F '#' '/^#[a-z]/ { print $2 } /^[a-z]/ { print $1 }' /etc/locale.gen
        ) \
        3>&1 1>&2 2>&3
}

get_timezone() {
    whiptail --title 'Timezone' \
        --menu 'Select timezone: ' \
        0 0 0 \
        $(
            for zone in $(ls -F /usr/share/zoneinfo | grep \/$); do
                for region in $(ls /usr/share/zoneinfo/$zone); do
                    echo $zone$region '-'
                done
            done
        ) \
        3>&1 1>&2 2>&3
}

get_hostname() {
    whiptail --title 'Hostname' --inputbox "Enter hostname: " 0 0 3>&1 1>&2 2>&3
}

get_username() {
    whiptail --title 'Username' --inputbox "Enter username: " 0 0 3>&1 1>&2 2>&3
}

get_password() {
    whiptail --title 'Password' --passwordbox "Enter password: " 0 0 3>&1 1>&2 2>&3
}

#TODO: implement these
get_desktop_environment() {
    whiptail --title 'DE/WM' --radiolist 'Select desktop environment / window manager:' 0 $(expr $(tput cols) \* 3 / 4) 0 \
        'bspwm' 'Tiling window manager that represents windows as the leaves of a full binary tree' OFF \
        'Budgie' 'Desktop environment designed with the modern user in mind, that focuses on simplicity and elegance' OFF \
        'Cinnamon' 'Combines a traditional desktop layout with modern graphical effects' OFF \
        'Deepin' 'Intuitive and elegant design providing an easy to use and reliable system for global users' OFF \
        'dwm' 'extremely lightweight and fast tiling WM, optimizing the environment for the task being performed' OFF \
        'GNOME' 'Attractive, intuitive and extensible desktop with a modern look' OFF \
        'i3' 'Tiling window manager primarily targeted at developers and advanced users' OFF \
        'KDE Plasma' 'Modern and polished, highly customizable and lightweight' ON \
        'LXDE' 'Lightweight, fast and energy-saving desktop environment with a modern interface' OFF \
        'LXQt' 'Modular, blazing-fast and user-friendly desktop environment' OFF \
        'MATE' 'Intuitive and attractive, preserving a traditional desktop experience' OFF \
        'Xfce' 'Lightweight and modular desktop environment ' OFF \
        'None' 'Don'\''t install a desktop environment / window manager'  OFF \
        3>&1 1>&2 2>&3
}

get_login_shell() {
    whiptail --title 'Shell' --radiolist 'Select user'\''s default shell:' 0 $(expr $(tput cols) \* 3 / 4) 0 \
        'bash' 'Bourne Again Shell, default shell of many distributions' ON \
        'fish' 'Friendly Interactive Shell, user-friendly and easily customizable' OFF \
        'zsh' 'Z Shell, bash-compatible with spelling correction, approximate completion and recursive path expansion'  OFF \
        3>&1 1>&2 2>&3
}

get_optimus_backend() {
    whiptail --title 'Optimus' --radiolist 'Select backend for GPU switching:' 0 $(expr $(tput cols) \* 3 / 4) 0 \
        'bumblebee' 'allows running selected applications on the dedicated GPU while using integrated graphics for everything else (sacrificing some performance)' ON \
        'optimus-manager' 'switch cards with a single command, achieving maximum performance out of the dedicated GPU (requires X server restart after switch)'  OFF \
        'none' 'no backed or nvidia driver will be installed' OFF \
        3>&1 1>&2 2>&3
}

get_optional_features() {
    whiptail --title 'Optional features' --checklist 'Select optional features' --separate-output 0 $(expr $(tput cols) \* 3 / 4) 0 \
        'netcache' 'Use netcache during installation' OFF \
        'autologin' 'Get automatically logged in on boot' OFF \
        'archstrike repository' 'Enable Archstrike repository (pentesting tools)' OFF \
        'add extra packages' 'Install additional packages from official repositories or AUR' OFF \
        'passwordless sudo' 'No password prompt when running commands with sudo' ON \
        'bluetooth audio support' 'Add support for bluetooth headphones and speakers' OFF \
        3>&1 1>&2 2>&3
}

get_netcache_ip() {
    whiptail --title 'Netcache IP' --inputbox "Enter the IP address of the machine running the netcache server: " 0 0 3>&1 1>&2 2>&3
}

get_extra_packages() {
    whiptail --title 'Extra packages' --inputbox "Enter space separated package names: " 0 $(expr $(tput cols) \* 3 / 4) 3>&1 1>&2 2>&3
}
