set_terminal_colors() {
    setterm -blank 0 -powersave off
    echo -ne "\e]P0282a36" #black
    echo -ne "\e]P814151b" #darkgrey
    echo -ne "\e]P1ff2222" #darkred
    echo -ne "\e]P9ff5555" #red
    echo -ne "\e]P21ef956" #darkgreen
    echo -ne "\e]PA50fa7b" #green
    echo -ne "\e]P3ebf85b" #brown
    echo -ne "\e]PBf1fa8c" #yellow
    echo -ne "\e]P44d5b86" #darkblue
    echo -ne "\e]PCbd93f9" #blue
    echo -ne "\e]P5ff46b0" #darkmagenta
    echo -ne "\e]PDff79c6" #magenta
    echo -ne "\e]P659dffc" #darkcyan
    echo -ne "\e]PE8be9fd" #cyan
    echo -ne "\e]P7f8f8f2" #lightgrey
    echo -ne "\e]PFf8f8f2" #white
    clear
}

set_dialog_colors() {
    export NEWT_COLORS='
        root=,black
        border=cyan,black
        window=,black
        shadow=,black
        title=brightcyan,black
        button=black,cyan
        checkbox=cyan,black
        actcheckbox=black,cyan
        entry=cyan,black
        listbox=cyan,black
        actlistbox=black,cyan
        textbox=cyan,black
        acttextbox=black,cyan
        emptyscale=,black
        fullscale=,cyan
        compactbutton=cyan,black
        actsellistbox=black,cyan'
}
