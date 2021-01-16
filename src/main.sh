# TODO: redirect errors to file
# TODO: send shutdown signal to netcache
# TODO: improve aur debug log
# TODO: dual-boot support?
# TODO: util functions for logging
# TODO: show log on error

echo "[LOG]" > archer.log

boot_mode=$(detect_boot_mode)
info "boot mode: $boot_mode"

[[ $boot_mode != UEFI ]] && error "$boot_mode boot mode not supported"

set_terminal_colors
set_dialog_colors

# systemctl stop reflector
# timedatectl set-ntp true
# sleep 5

cp /etc/pacman.conf /etc/pacman.conf.bak

cpu_vendor=$(detect_cpu_vendor)
info "cpu vendor: $cpu_vendor"
check_stderr && warn "could not detect CPU vendor"

gpu_configuration=$(detect_gpu_configuration)
info "gpu configuration: $gpu_configuration"

has_battery=$(detect_battery)
info "battery: $has_battery"
check_stderr && warn "error occured while checking for battery"

has_wireless=$(detect_wireless)
info "wireless: $has_wireless"

has_bluetooth=$(detect_bluetooth)
info "bluetooth: $has_bluetooth"

has_ssd=$(detect_ssd)
info "ssd: $has_ssd"
check_stderr && warn "could not query ssd information"

selected_drive=$(get_drive)
[[ -z $selected_drive ]] && error 'no drive selected'
info "selected drve: $selected_drive"

mirrorlist_country=$(get_mirrorlist_country)
[[ -z $mirrorlist_country ]] && error 'no mirrorlist country selected'
info "mirrorlist country: $mirrorlist_country"

locale=$(get_locale)
[[ -z $locale ]] && error 'no locale selected'
info "locale: $locale"

timezone=$(get_timezone)
[[ -z $timezone ]] && error 'no timezone selected'
info "timezone: $timezone"

hostname=$(get_hostname)
[[ -z $hostname ]] && error 'empty hostname'
info "hostname: $hostname"

username=$(get_username)
[[ -z $username ]] && error 'username hostname'
info "username: $username"

password=$(get_password)
[[ -z $password ]] && error 'empty password'
info "password: $password"

desktop_environment=$(get_desktop_environment)
[[ -z $desktop_environment ]] && error 'no DE/WM selected'
info "DE/WM: $desktop_environment"

login_shell=$(get_login_shell)
[[ -z $login_shell ]] && error 'no login shell selected'
info "login shell: $login_shell"

if [[ $gpu_configuration = optimus ]]; then
    optimus_backend=$(get_optimus_backend)
    [[ -z $optimus_backend ]] && error 'no optimus backend selected'
    info "optimus backend: $optimus_backend"
fi

optional_features=$(get_optional_features)

feature_netcache=$([[ $optional_features =~ 'netcache' ]] && echo yes || echo no)
info "enable netcache: $feature_netcache"
if [[ $feature_netcache = yes ]]; then
    netcache_ip=$(get_netcache_ip)
    [[ -z $netcache_ip ]] && error 'netcache ip empty'
    if ! ping -c1 $netcache_ip >/dev/null 2>archer.err; then
        check_stderr
        error "$netcache_ip unreachable"
    fi
    info "netcache ip: $netcache_ip"
fi


feature_autologin=$([[ $optional_features =~ 'autologin' ]] && echo yes || echo no)
info "enable autologin: $feature_autologin"

feature_rank_mirrors=$([[ $optional_features =~ 'rank mirrors' ]] && echo yes || echo no)
info "enable mirror ranking: $feature_rank_mirrors"

feature_archstrike_repository=$([[ $optional_features =~ 'archstrike repository' ]] && echo yes || echo no)
info "enable archstrike repository: $feature_archstrike_repository"

feature_extra_packages=$([[ $optional_features =~ 'add extra packages' ]] && echo yes || echo no)
info "extra packages: $feature_extra_packages"
if [[ $feature_extra_packages = yes ]]; then
    extra_packages=$(get_extra_packages)
    extra_packages_official=()
    extra_packages_aur=()

    pacman -Sy >/dev/null 2>archer.err
    check_stderr && error 'could not fetch pacman database'

    for package in $extra_packages; do
        if pacman -Ss ^$package$ >/dev/null; then
            extra_packages_official+=($package)
            info "extra official package: $package"
        elif curl -sI https://aur.archlinux.org/packages/$package/ | head -n1 | grep -q 200; then
            extra_packages_aur+=($package)
            info "extra aur package: $package"
        else
            warn "unknown extra package: $package"
        fi
    done
fi

feature_passwordless_sudo=$([[ $optional_features =~ 'passwordless sudo' ]] && echo yes || echo no)
info "enable passwordless sudo: $feature_passwordless_sudo"

feature_bluetooth_audio=$([[ $optional_features =~ 'bluetooth audio support' ]] && echo yes || echo no)
info "enable bluetooth audio support: $feature_bluetooth_audio"


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

# TODO: merge arrays
# TODO: conditions to skip optional features
# TODO: convert to cummulative values
declare -A progress
progress[create_partitions]=100
progress[download_mirrorlist]=100
[[ $feature_rank_mirrors = yes ]] && progress[rank_mirrors]=10000
[[ $feature_netcache = yes ]] && progress[enable_netcache]=100
progress[install_pacman_packages]=20000
# condition for this
progress[install_aur_packages]=100
progress[install_bootloader]=200
progress[generate_fstab]=100
progress[generate_locale]=500
progress[set_timezone]=100
progress[configure_network]=100
progress[set_root_password]=100
progress[configure_pacman]=100
[[ $has_battery = yes ]] && progress[configure_tlp]=100
progress[configure_journald]=100
progress[configure_coredump]=100
progress[create_user]=100
progress[enable_services]=200
[[ $feature_archstrike_repository = yes ]] && progress[enable_archstrike_repository]=1000
[[ $feature_passwordless_sudo = yes ]] && progress[enable_passwordless_sudo]=100
[[ $feature_autologin = yes ]] && progress[enable_autologin]=100

total_progress=0
for item in ${progress[@]}; do
    let total_progress+=$item
done

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

#TODO: replace this, it worked fine for older versions but now it needs a rework
#'concatenate' progress bars
current_progress=0
for step in ${execution_order[@]}; do
    echo -e "XXX"
    echo -e "$(($current_progress * 100 / $total_progress))"
    echo -e "${description[$step]}"
    echo -e "XXX"
    $step
    let current_progress+=${progress[$step]}
    # :thinking_face:
    # echo -e "XXX"
    # echo -e "$(($current_progress * 100 / $total_progress))"
    # echo -e "${description[$step]}"
    # echo -e "XXX"
    # 
done | whiptail --title "Progress" --gauge "Initializing" 0 $((`tput cols` * 3 / 4)) 0

mv /etc/pacman.conf.bak /etc/pacman.conf

whiptail --title 'Show log' --yesno "Show installation log?" 0 0 3>&1 1>&2 2>&3

[ $? = 0 ] && whiptail --title 'archer.log' --textbox archer.log 0 0 3>&1 1>&2 2>&3
