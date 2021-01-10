# TODO: redirect errors to file
# TODO: send shutdown signal to netcache
# TODO: improve aur debug log
# TODO: dual-boot support?
# TODO: util functions for logging

echo "[LOG]" > archer.log

boot_mode=$(detect_boot_mode)
echo "[INFO]: boot mode: $boot_mode" >> archer.log

[[ $boot_mode != UEFI ]] && echo "[ERROR]: boot mode not supported" >> archer.log
[[ $boot_mode != UEFI ]] && exit 0

set_terminal_colors
set_newt_colors

systemctl stop reflector
timedatectl set-ntp true
sleep 5

cp /etc/pacman.conf /etc/pacman.conf.bak

cpu_vendor=$(detect_cpu_vendor)
echo "[INFO]: cpu vendor: $cpu_vendor" >> archer.log
gpu_configuration=$(detect_gpu_configuration)
echo "[INFO]: gpu configuration: $gpu_configuration" >> archer.log
has_battery=$(detect_battery)
echo "[INFO]: battery: $has_battery" >> archer.log
has_wireless=$(detect_wireless)
echo "[INFO]: wireless: $has_wireless" >> archer.log
has_bluetooth=$(detect_bluetooth)
echo "[INFO]: bluetooth: $has_bluetooth" >> archer.log
has_ssd=$(detect_ssd)
echo "[INFO]: ssd: $has_ssd" >> archer.log

[[ -s archer.err ]] && echo -ne "[ERROR]: " >> archer.log && cat archer.err >> archer.log && rm archer.err



selected_drive=$(get_drive)
[[ -z $selected_drive ]] && echo "[ERROR]: no drive selected" >> archer.log && exit
echo "[INFO]: selected drve: $selected_drive" >> archer.log

mirrorlist_country=$(get_mirrorlist_country)
[[ -z $mirrorlist_country ]] && echo "[ERROR]: no mirrorlist country selected" >> archer.log && exit
echo "[INFO]: mirrorlist country: $mirrorlist_country" >> archer.log

locale=$(get_locale)
[[ -z $locale ]] && echo "[ERROR]: no locale selected" >> archer.log && exit
echo "[INFO]: locale: $locale" >> archer.log

timezone=$(get_timezone)
[[ -z $timezone ]] && echo "[ERROR]: no timezone selected" >> archer.log && exit
echo "[INFO]: timezone: $timezone" >> archer.log

hostname=$(get_hostname)
[[ -z $hostname ]] && echo "[ERROR]: empty hostname" >> archer.log && exit
echo "[INFO]: hostname: $hostname" >> archer.log

username=$(get_username)
[[ -z $username ]] && echo "[ERROR]: username hostname" >> archer.log && exit
echo "[INFO]: username: $username" >> archer.log

password=$(get_password)
[[ -z $password ]] && echo "[ERROR]: empty password" >> archer.log && exit
echo "[INFO]: password: $password" >> archer.log

desktop_environment=$(get_desktop_environment)
[[ -z $desktop_environment ]] && echo "[ERROR]: no DE/WM selected" >> archer.log && exit
echo "[INFO]: DE/WM: $desktop_environment" >> archer.log

login_shell=$(get_login_shell)
[[ -z $login_shell ]] && echo "[ERROR]: no login shell selected" >> archer.log && exit
echo "[INFO]: login shell: $login_shell" >> archer.log

if [[ $gpu_configuration = optimus ]]; then
    optimus_backend=$(get_optimus_backend)
    [[ -z $optimus_backend ]] && echo "[ERROR]: no optimus backend selected" >> archer.log && exit
    echo "[INFO]: optimus backend: $optimus_backend" >> archer.log
fi

optional_features=$(get_optional_features)

feature_netcache=$([[ $optional_features =~ 'netcache' ]] && echo yes || echo no)
echo "[INFO]: enable netcache: $feature_netcache" >> archer.log
if [[ $feature_netcache = yes ]]; then
    netcache_ip=$(get_netcache_ip)
    if [[ -z $netcache_ip ]]; then
        echo "[ERROR]: netcache ip empty" >> archer.log
        exit
    fi
    if ! ping -c1 $netcache_ip >/dev/null 2>archer.err; then
        echo "[ERROR]: $netcache_ip unreachable" >> archer.log
        exit
    fi
    echo "[INFO]: netcache ip: $netcache_ip" >> archer.log
fi


feature_autologin=$([[ $optional_features =~ 'autologin' ]] && echo yes || echo no)
echo "[INFO]: enable autologin: $feature_autologin" >> archer.log

feature_rank_mirrors=$([[ $optional_features =~ 'rank mirrors' ]] && echo yes || echo no)
echo "[INFO]: enable mirror ranking: $feature_rank_mirrors" >> archer.log

feature_archstrike_repository=$([[ $optional_features =~ 'archstrike repository' ]] && echo yes || echo no)
echo "[INFO]: enable archstrike repository: $feature_archstrike_repository" >> archer.log

feature_extra_packages=$([[ $optional_features =~ 'add extra packages' ]] && echo yes || echo no)
echo "[INFO]: extra packages: $feature_extra_packages" >> archer.log
if [[ $feature_extra_packages = yes ]]; then
    extra_packages=$(get_extra_packages)
    extra_packages_official=()
    extra_packages_aur=()
    
    pacman -Sy >/dev/null 2>archer.err
    [[ -s archer.err ]] && echo -ne "[ERROR]: " >> archer.log && cat archer.err >> archer.log && rm archer.err
    
    for package in $extra_packages; do
        if pacman -Ss ^$package$ >/dev/null; then
            extra_packages_official+=($package)
            echo "[INFO]: extra official package: $package" >> archer.log
        elif curl -sI https://aur.archlinux.org/packages/$package/ | head -n1 | grep -q 200; then
            extra_packages_aur+=($package)
            echo "[INFO]: extra aur package: $package" >> archer.log
        else
            echo "[WARN]: unknown extra package: $package" >> archer.log
        fi
    done
fi

feature_passwordless_sudo=$([[ $optional_features =~ 'passwordless sudo' ]] && echo yes || echo no)
echo "[INFO]: enable passwordless sudo: $feature_passwordless_sudo" >> archer.log

feature_bluetooth_audio=$([[ $optional_features =~ 'bluetooth audio support' ]] && echo yes || echo no)
echo "[INFO]: enable bluetooth audio support: $feature_bluetooth_audio" >> archer.log


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

# whiptail --title "Progress" --gauge "Initializing" 0 $((`tput cols` * 3 / 4)) 0

#TODO: replace this, it worked fine for older versions but now it needs a rework
#'concatenate' progress bars
for step in ${!execution_order[@]}; do
    echo -e "XXX\n$(expr $step \* 100 / ${#execution_order[@]})\n${description[${execution_order[$step]}]}\nXXX"
    ${execution_order[$step]}
done | whiptail --title "Progress" --gauge "Initializing" 0 $((`tput cols` * 3 / 4)) 0

mv /etc/pacman.conf.bak /etc/pacman.conf

whiptail --title 'Show log' --yesno "Show installation log?" 0 0 3>&1 1>&2 2>&3

[ $? = 0 ] && whiptail --title 'archer.log' --textbox archer.log 0 0 3>&1 1>&2 2>&3
