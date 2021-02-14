detect_boot_mode() {
    [[ -d /sys/firmware/efi/efivars ]] && echo UEFI || echo BIOS
}

detect_cpu_vendor() {
    grep -q GenuineIntel /proc/cpuinfo 2>archer.err && echo intel && return
    grep -q AuthenticAMD /proc/cpuinfo 2>archer.err && echo amd && return
    echo unknown
}

# TODO: add amd
detect_gpu_configuration() {
    lspci | grep VGA | grep -qi intel && lspci | grep 3D | grep -qi nvidia && echo optimus && return
    lspci | grep VGA | grep -qi intel && echo intel && return
    lspci | grep VGA | grep -qi nvidia && echo nvidia && return
    echo unknown
}

detect_battery() {
    [[ -z "$(ls -A /sys/class/power_supply)" ]] && echo no && return
    grep -qi battery /sys/class/power_supply/*/type 2>archer.err && echo yes || echo no
}

detect_wireless() {
    lspci | grep Network | grep -qi 'wireless\|WLAN\|wifi\|802\.11' && echo yes || echo no
}

detect_bluetooth() {
    lsusb | grep -qi bluetooth && echo yes && return
    dmesg | grep -qi bluetooth && echo yes || echo no
}

detect_ssd() {
    grep -q 0 /sys/block/*/queue/rotational 2>archer.err && echo yes || echo no
}
