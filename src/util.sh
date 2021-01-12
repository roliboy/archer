info() {
    echo "[INFO] $1" >> archer.log
}

warn() {
    echo "[WARN] $1" >> archer.log
    
    whiptail --title 'A warning was issued' --yesno "$1\n\nYou may chose to ignore this warning and continue the install\nContinue?" 0 0 3>&1 1>&2 2>&3
    
    if [[ $? != 0 ]]; then
        whiptail --title 'archer.log' --textbox archer.log `tput lines` `tput cols` 3>&1 1>&2 2>&3
        clear
        exit 1
    fi
}

error() {
    echo "[ERROR] $1" >> archer.log
    
    whiptail --title 'An error has occured' --yesno "Show installation log?" 0 0 3>&1 1>&2 2>&3
    [[ $? = 0 ]] && whiptail --title 'archer.log' --textbox archer.log `tput lines` `tput cols` 3>&1 1>&2 2>&3
    clear
    
    exit 1
}

# TODO: this
check_stderr() {
    if [[ -s archer.err ]]; then
        echo "[STDERR] $(cat archer.err)" >> archer.log
        rm archer.err
        return 0
    else
        return 1
    fi
}
