detect_boot_mode() {
    [[ -d /sys/firmware/efi/efivars ]] && echo UEFI || echo BIOS
}

# TODO: return unknown if the cpu is neither intel nor amd
detect_cpu_vendor() {
    grep -q GenuineIntel /proc/cpuinfo 2>archer.err && echo intel
    grep -q AuthenticAMD /proc/cpuinfo 2>archer.err && echo amd
}

# TODO: rework this
# TODO: return unknown on empty
detect_gpu_configuration() {
    lspci | grep VGA | grep -i intel && local vga_controller=intel
    lspci | grep VGA | grep -i amd && local vga_controller=amd
    lspci | grep 3D | grep -i intel && local gfx_accelerator=intel
    lspci | grep 3D | grep -i amd && local gfx_accelerator=amd
    lspci | grep 3D | grep -i nvidia && local gfx_accelerator=nvidia

    [[ $vga_controller = amd ]] && local configuration=amd
    [[ $vga_controller = intel ]] && local configuration=intel
    [[ $vga_controller = nvidia ]] && local configuration=nvidia
    [[ $vga_controller = intel ]] && [[ $gfx_accelerator = nvidia ]] && local configuration=optimus

    echo $configuration
}

detect_battery() {
    [[ -z "$(ls -A /sys/class/power_supply)" ]] && echo no && return
    grep -qi battery /sys/class/power_supply/*/type 2>archer.err && echo yes || echo no
}

detect_wireless() {
    lspci | grep -i network | grep -qi 'wireless\|WLAN\|wifi\|802\.11' && echo yes || echo no
}

detect_bluetooth() {
    lsusb | grep -qi bluetooth && echo yes && return
    dmesg | grep -qi bluetooth && echo yes || echo no
}

detect_ssd() {
    grep 0 /sys/block/*/queue/rotational 2>archer.err && echo yes || echo no
}
