#!/usr/bin/env bash

set -e

echo "========================================"
echo " Arch Cyberpunk Rice Installer"
echo "========================================"

sleep 2

# -------------------------------------------------
# UPDATE SYSTEM
# -------------------------------------------------

sudo pacman -Syu --noconfirm

# -------------------------------------------------
# INSTALL REQUIRED PACKAGES
# -------------------------------------------------

sudo pacman -S --noconfirm \
i3-wm i3lock i3status dmenu \
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
wget curl unzip git

# -------------------------------------------------
# CREATE CONFIG DIRECTORIES
# -------------------------------------------------

mkdir -p ~/.config/i3
mkdir -p ~/.config/picom
mkdir -p ~/.config/polybar
mkdir -p ~/.config/kitty
mkdir -p ~/.local/bin
mkdir -p ~/Pictures/wallpapers

# -------------------------------------------------
# DOWNLOAD WALLPAPER
# -------------------------------------------------

wget -O ~/Pictures/wallpapers/rain.jpg \
https://images.unsplash.com/photo-1500375592092-40eb2168fd21

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
  strength = 6;
};

opacity-rule = [
  "90:class_g = 'kitty'",
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
radius = 0

background = ${colors.background}
foreground = ${colors.foreground}

line-size = 0

font-0 = Iosevka Nerd Font:size=10

modules-left = i3
modules-center = date
modules-right = cpu memory filesystem

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
# I3 CONFIG
# -------------------------------------------------

cat > ~/.config/i3/config << 'EOF'

set $mod Mod4

font pango:Iosevka Nerd Font 10

floating_modifier $mod

exec --no-startup-id picom
exec --no-startup-id feh --bg-fill ~/Pictures/wallpapers/rain.jpg
exec --no-startup-id polybar main

gaps inner 10
gaps outer 5

default_border pixel 0
default_floating_border pixel 0

for_window [class="kitty"] border pixel 0

# TERMINAL
bindsym $mod+Return exec kitty

# APP LAUNCHER
bindsym $mod+d exec rofi -show drun

# RELOAD
bindsym $mod+Shift+r restart
bindsym $mod+Shift+c reload

# CLOSE WINDOW
bindsym $mod+Shift+q kill

# FLOATING TOGGLE
bindsym $mod+Shift+space floating toggle

# WORKSPACES
bindsym $mod+1 workspace 1
bindsym $mod+2 workspace 2
bindsym $mod+3 workspace 3
bindsym $mod+4 workspace 4
bindsym $mod+5 workspace 5

EOF

# -------------------------------------------------
# CYBER DASHBOARD SCRIPT
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
# FINISHED
# -------------------------------------------------

echo
echo "========================================"
echo " INSTALL COMPLETE"
echo "========================================"
echo
echo "Log out and select i3 session."
echo
echo "After login run:"
echo
echo "cyber-dashboard"
echo
