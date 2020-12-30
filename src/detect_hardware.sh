detect_boot_mode() {
    [ -d /sys/firmware/efi/efivars ] && echo UEFI || echo BIOS
}

detect_cpu_vendor() {
    [ -n "$(grep GenuineIntel /proc/cpuinfo)" ] && echo intel
    [ -n "$(grep AuthenticAMD /proc/cpuinfo)" ] && echo amd
}

detect_gpu_configuration() {
    [ -n "$(lspci | grep VGA | grep -i intel)" ] && local vga_controller=intel
    [ -n "$(lspci | grep VGA | grep -i amd)" ] && local vga_controller=amd
    [ -n "$(lspci | grep 3D | grep -i intel)" ] && local gfx_accelerator=intel
    [ -n "$(lspci | grep 3D | grep -i amd)" ] && local gfx_accelerator=amd
    [ -n "$(lspci | grep 3D | grep -i nvidia)" ] && local gfx_accelerator=nvidia

    #TODO: experiment with different amd configurations
    [ "$vga_controller" = amd ] && local configuration=amd
    [ "$vga_controller" = intel ] && local configuration=intel
    [ "$vga_controller" = nvidia ] && local configuration=nvidia
    [ "$vga_controller" = intel ] && [ "$gfx_accelerator" = nvidia ] && local configuration=optimus

    echo "$configuration"
}

detect_battery() {
    [ -n "$(grep -i battery /sys/class/power_supply/*/type 2>/dev/null)" ] && echo yes || echo no
}

detect_wireless() {
    [ -n "$(lspci | grep -i network | grep -i 'wireless\|WLAN\|wifi\|802\.11')" ] && echo yes || echo no
}

detect_bluetooth() {
    [ -n "$(lsusb | grep -i bluetooth)" ] && echo yes && return
    [ -n "$(dmesg | grep -i bluetooth)" ] && echo yes || echo no
}

detect_ssd() {
    [ -n "$(grep 0 /sys/block/*/queue/rotational 2>/dev/null)" ] && echo yes || echo no
}
