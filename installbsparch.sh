#!/usr/bin/env bash

set -e

echo "========================================"
echo " BSPWM Cyberpunk Rice Installer"
echo "========================================"

sleep 2

# -------------------------------------------------
# UPDATE SYSTEM
# -------------------------------------------------

sudo pacman -Syu --noconfirm

# -------------------------------------------------
# INSTALL PACKAGES
# -------------------------------------------------

sudo pacman -S --noconfirm \
bspwm \
sxhkd \
polybar \
picom \
kitty \
rofi \
feh \
fastfetch \
neofetch \
cava \
cmatrix \
btop \
htop \
lxappearance \
arc-gtk-theme \
papirus-icon-theme \
ttf-font-awesome \
ttf-iosevka-nerd \
ttf-jetbrains-mono-nerd \
xorg-xrandr \
xorg-xsetroot \
wget curl unzip git

# -------------------------------------------------
# CONFIG DIRECTORIES
# -------------------------------------------------

mkdir -p ~/.config/bspwm
mkdir -p ~/.config/sxhkd
mkdir -p ~/.config/picom
mkdir -p ~/.config/polybar
mkdir -p ~/.config/kitty
mkdir -p ~/.local/bin
mkdir -p ~/Pictures/wallpapers

# -------------------------------------------------
# WALLPAPER
# -------------------------------------------------

wget -O ~/Pictures/wallpapers/rain.jpg \
https://images.unsplash.com/photo-1500375592092-40eb2168fd21

# -------------------------------------------------
# BSPWMRC
# -------------------------------------------------

cat > ~/.config/bspwm/bspwmrc << 'EOF'
#!/usr/bin/env bash

picom &
feh --bg-fill ~/Pictures/wallpapers/rain.jpg &
polybar main &

sxhkd &

bspc config border_width         0
bspc config window_gap          10
bspc config split_ratio         0.52

bspc config focused_border_color "#00ffcc"
bspc config normal_border_color "#000000"

bspc config top_padding         30
bspc config left_padding        5
bspc config right_padding       5
bspc config bottom_padding      5

# DESKTOPS
bspc monitor -d 1 2 3 4 5 6
EOF

chmod +x ~/.config/bspwm/bspwmrc

# -------------------------------------------------
# SXHKD CONFIG
# -------------------------------------------------

cat > ~/.config/sxhkd/sxhkdrc << 'EOF'

# TERMINAL
super + Return
    kitty

# APP LAUNCHER
super + d
    rofi -show drun

# CLOSE WINDOW
super + shift + q
    bspc node -c

# RESTART BSPWM
super + shift + r
    bspc wm -r

# FLOATING MODE
super + shift + space
    bspc node -t floating

# FOCUS WINDOWS
super + {h,j,k,l}
    bspc node -f {west,south,north,east}

# MOVE WINDOWS
super + shift + {h,j,k,l}
    bspc node -s {west,south,north,east}

# WORKSPACES
super + {1-6}
    bspc desktop -f '^{1-6}'

EOF

# -------------------------------------------------
# PICOM CONFIG
# -------------------------------------------------

cat > ~/.config/picom/picom.conf << 'EOF'

backend = "glx";
vsync = true;

shadow = true;
shadow-radius = 12;
shadow-opacity = 0.35;

corner-radius = 8;

blur:
{
  method = "dual_kawase";
  strength = 7;
};

opacity-rule = [
  "92:class_g = 'kitty'",
  "95:class_g = 'Polybar'"
];

EOF

# -------------------------------------------------
# KITTY CONFIG
# -------------------------------------------------

cat > ~/.config/kitty/kitty.conf << 'EOF'

font_family Iosevka Nerd Font
font_size 11

background #000000
foreground #00ffcc

background_opacity 0.82

cursor #00ffcc
selection_background #003333

EOF

# -------------------------------------------------
# POLYBAR CONFIG
# -------------------------------------------------

cat > ~/.config/polybar/config.ini << 'EOF'

[colors]
background = #000000
foreground = #00ffcc
green = #00ff99
red = #ff5555

[bar/main]
width = 100%
height = 24

background = ${colors.background}
foreground = ${colors.foreground}

font-0 = Iosevka Nerd Font:size=10

modules-left = bspwm
modules-center = date
modules-right = cpu memory filesystem

[module/bspwm]
type = internal/bspwm

[module/date]
type = internal/date
interval = 1
date = %A, %d %B %Y %H:%M:%S

[module/cpu]
type = internal/cpu
format-prefix = "CPU "

[module/memory]
type = internal/memory
format-prefix = "RAM "

[module/filesystem]
type = internal/fs
mount-0 = /

EOF

# -------------------------------------------------
# GTK SETTINGS
# -------------------------------------------------

mkdir -p ~/.config/gtk-3.0

cat > ~/.config/gtk-3.0/settings.ini << 'EOF'
[Settings]
gtk-theme-name=Arc-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Iosevka Nerd Font 10
EOF

# -------------------------------------------------
# DASHBOARD SCRIPT
# -------------------------------------------------

cat > ~/.local/bin/cyber-dashboard << 'EOF'
#!/usr/bin/env bash

kitty --title btop -e btop &
sleep 1

kitty --title cava -e cava &
sleep 1

kitty --title fetch -e fastfetch &
sleep 1

kitty --title matrix -e cmatrix -b -C green &
EOF

chmod +x ~/.local/bin/cyber-dashboard

# -------------------------------------------------
# XINITRC
# -------------------------------------------------

if ! grep -q "exec bspwm" ~/.xinitrc 2>/dev/null; then
    echo "exec bspwm" > ~/.xinitrc
fi

# -------------------------------------------------
# DONE
# -------------------------------------------------

echo
echo "========================================"
echo " INSTALL COMPLETE"
echo "========================================"
echo
echo "Start BSPWM with:"
echo
echo "startx"
echo
echo "Then run:"
echo
echo "cyber-dashboard"
echo
