#TODO: send shutdown signal to netcache
#TODO: improve aur debug log
#TODO: dual-boot support?
#TODO: kill reflector service

echo "[LOG]" > archer.log

boot_mode="$(detect_boot_mode)"
echo "[DEBUG]: boot mode: ->$boot_mode<-" >> archer.log

[ $boot_mode != UEFI ] && echo "[ERROR]: boot mode not supported: ->$boot_mode<-" >> archer.log
[ $boot_mode != UEFI ] && exit 0

set_terminal_colors
set_newt_colors

systemctl stop reflector
timedatectl set-ntp true
sleep 5

cp /etc/pacman.conf /etc/pacman.conf.bak

cpu_vendor="$(detect_cpu_vendor)"
echo "[DEBUG]: cpu vendor: ->$cpu_vendor<-" >> archer.log
gpu_configuration="$(detect_gpu_configuration)"
echo "[DEBUG]: gpu configuration: ->$gpu_configuration<-" >> archer.log
has_battery="$(detect_battery)"
echo "[DEBUG]: battery: ->$has_battery<-" >> archer.log
has_wireless="$(detect_wireless)"
echo "[DEBUG]: wireless: ->$has_wireless<-" >> archer.log
has_bluetooth="$(detect_bluetooth)"
echo "[DEBUG]: bluetooth: ->$has_bluetooth<-" >> archer.log
has_ssd="$(detect_ssd)"
echo "[DEBUG]: ssd: ->$has_ssd<-" >> archer.log


selected_drive="$(get_drive)"
echo "[DEBUG]: selected drve: ->$selected_drive<-" >> archer.log
mirrorlist_country="$(get_mirrorlist_country)"
echo "[DEBUG]: mirrorlist country: ->$mirrorlist_country<-" >> archer.log
locale="$(get_locale)"
echo "[DEBUG]: locale: ->$locale<-" >> archer.log
timezone="$(get_timezone)"
echo "[DEBUG]: timezone: ->$timezone<-" >> archer.log
hostname="$(get_hostname)"
echo "[DEBUG]: hostname: ->$hostname<-" >> archer.log
username="$(get_username)"
echo "[DEBUG]: username: ->$username<-" >> archer.log
password="$(get_password)"
echo "[DEBUG]: password: ->$password<-" >> archer.log

desktop_environment="$(get_desktop_environment)"
echo "[DEBUG]: DE/WM: ->$desktop_environment<-" >> archer.log

login_shell="$(get_login_shell)"
echo "[DEBUG]: login shell: ->$login_shell<-" >> archer.log

[ "$gpu_configuration" = optimus ] && optimus_backend="$(get_optimus_backend)"
[ "$gpu_configuration" = optimus ] && echo "[DEBUG]: optimus backend: ->$optimus_backend<-" >> archer.log

optional_features="$(get_optional_features)"

feature_netcache=$([ -n "$(grep 'netcache' <<< $optional_features)" ] && echo yes || echo no)
echo "[DEBUG]: enable netcache: ->$feature_netcache<-" >> archer.log
[ $feature_netcache = yes ] && netcache_ip="$(get_netcache_ip)"

feature_autologin=$([ -n "$(grep 'autologin' <<< $optional_features)" ] && echo yes || echo no)
echo "[DEBUG]: enable autologin: ->$feature_autologin<-" >> archer.log

feature_rank_mirrors=$([ -n "$(grep 'rank mirrors' <<< $optional_features)" ] && echo yes || echo no)
echo "[DEBUG]: enable mirror ranking: ->$feature_rank_mirrors<-" >> archer.log

feature_archstrike_repository=$([ -n "$(grep 'archstrike repository' <<< $optional_features)" ] && echo yes || echo no)
echo "[DEBUG]: enable Archstrike repository: ->$feature_archstrike_repository<-" >> archer.log

feature_extra_packages=$([ -n "$(grep 'add extra packages' <<< $optional_features)" ] && echo yes || echo no)
echo "[DEBUG]: enable Extra Packages: ->$feature_extra_packages<-" >> archer.log
[ $feature_extra_packages = yes ] && extra_packages="$(get_extra_packages)"

feature_passwordless_sudo=$([ -n "$(grep 'passwordless sudo' <<< $optional_features)" ] && echo yes || echo no)
echo "[DEBUG]: enable Passwordless sudo: ->$feature_passwordless_sudo<-" >> archer.log

feature_bluetooth_audio=$([ -n "$(grep 'bluetooth audio support' <<< $optional_features)" ] && echo yes || echo no)
echo "[DEBUG]: enable Bluetooth Audio: ->$feature_bluetooth_audio<-" >> archer.log

#TODO: separate function?
extra_packages_official=()
extra_packages_aur=()
pacman -Sy > /dev/null 2>&1
for package in $extra_packages; do
    if [ "$(pacman -Ss ^$package$ | wc -l)" != 0 ]; then
        extra_packages_official+=($package)
        echo "[DEBUG]: extra package official: ->$package<-" >> archer.log
    elif [ -n "$(curl -sI https://aur.archlinux.org/packages/$package/ | head -n1 | grep 200)" ]; then
        extra_packages_aur+=($package)
        echo "[DEBUG]: extra package aur: ->$package<-" >> archer.log
    else
        echo "[DEBUG]: unknown package: ->$package<-" >> archer.log
    fi
done

declare -A description
description[create_partitions]="Creating partitions on $selected_drive"
description[download_mirrorlist]='Downloading mirrorlist'
description[rank_mirrors]='Ranking mirrors'
description[enable_netcache]='Enabling netcache'
description[install_pacman_packages]='Installing pacman packages'
description[install_aur_packages]='Installing AUR packages'
description[install_bootloader]='Installing bootloader'
description[generate_fstab]='Generating fstab'
description[generate_locale]='Generating locale'
description[set_timezone]='Setting timezone'
description[configure_network]='Configuring network'
description[set_root_password]='Setting root password'
description[configure_pacman]='Configuring pacman'
description[configure_tlp]='Configuring TLP'
description[configure_journald]='Configuring journald'
description[configure_coredump]='Configuring coredump'
description[create_user]="Creating user $username"
description[enable_services]='Enabling systemd services'
description[enable_archstrike_repository]='Enabling archstrike repository'
description[enable_passwordless_sudo]="Enable passwordless sudo for wheel group"
description[enable_autologin]="Enabling autologin for $username"


execution_order=(
    create_partitions
    download_mirrorlist
    $([ "$feature_rank_mirrors" = yes ] && echo rank_mirrors)
    $([ "$feature_netcache" = yes ] && echo enable_netcache)
    install_pacman_packages
    install_aur_packages
    install_bootloader
    generate_fstab
    generate_locale
    set_timezone
    configure_network
    set_root_password
    configure_pacman
    $([ "$has_battery" = yes ] && echo configure_tlp)
    configure_journald
    configure_coredump
    create_user
    enable_services
    $([ "$feature_archstrike_repository" = yes ] && echo enable_archstrike_repository)
    $([ "$feature_passwordless_sudo" = yes ] && echo enable_passwordless_sudo)
    $([ "$feature_autologin" = yes ] && echo enable_autologin)
)


for step in ${!execution_order[@]}; do
    echo -e "XXX\n$(expr $step \* 100 / ${#execution_order[@]})\n${description[${execution_order[$step]}]}\nXXX"
    ${execution_order[$step]}
done | whiptail --title "Progress" --gauge "Initializing" 0 $(expr $(tput cols) \* 3 / 4) 0

mv /etc/pacman.conf.bak /etc/pacman.conf

whiptail --title 'Show log' --yesno "Show installation log?" 0 0 3>&1 1>&2 2>&3

[ $? = 0 ] && whiptail --title 'archer.log' --textbox archer.log 0 0 3>&1 1>&2 2>&3
