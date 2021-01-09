#TODO: dracula color theme
#Background	#282a36
#Current Line	#44475a
#Foreground	#f8f8f2
#Comment	#6272a4
#Cyan	#8be9fd
#Green	#50fa7b
#Orange	#ffb86c
#Pink	#ff79c6
#Purple	#bd93f9
#Red	#ff5555
#Yellow	#f1fa8c

set_terminal_colors() {
    setterm -blank 0 -powersave off
    echo -ne "\e]P02e3436" #black
    echo -ne "\e]P8555753" #darkgrey
    echo -ne "\e]P1cc0000" #darkred
    echo -ne "\e]P9ef2929" #red
    echo -ne "\e]P24e9a06" #darkgreen
    echo -ne "\e]PA8ae234" #green
    echo -ne "\e]P3c4a000" #brown
    echo -ne "\e]PBfce94f" #yellow
    echo -ne "\e]P43465a4" #darkblue
    echo -ne "\e]PC729fcf" #blue
    echo -ne "\e]P575507b" #darkmagenta
    echo -ne "\e]PDad7fa8" #magenta
    echo -ne "\e]P606989a" #darkcyan
    echo -ne "\e]PE34e2e2" #cyan
    echo -ne "\e]P7d3d7cf" #lightgrey
    echo -ne "\e]PFeeeeec" #white
    clear
}

set_newt_colors() {
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
