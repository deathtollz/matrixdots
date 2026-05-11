#!/usr/bin/env bash

set -e

echo "======================================="
echo " Kali Cyberpunk Rice Installer"
echo "======================================="

sleep 2

# -------------------------------------------------
# UPDATE SYSTEM
# -------------------------------------------------

sudo apt update

# -------------------------------------------------
# INSTALL PACKAGES
# -------------------------------------------------

sudo apt install -y \
i3 picom polybar \
kitty rofi feh \
fastfetch neofetch \
cava cmatrix \
btop htop \
lxappearance \
arc-theme papirus-icon-theme \
fonts-font-awesome \
unzip wget curl git

# -------------------------------------------------
# INSTALL NERD FONT
# -------------------------------------------------

mkdir -p ~/.local/share/fonts
cd ~/.local/share/fonts

wget -O Iosevka.zip \
https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Iosevka.zip

unzip -o Iosevka.zip

fc-cache -fv

# -------------------------------------------------
# CREATE CONFIG DIRS
# -------------------------------------------------

mkdir -p ~/.config/i3
mkdir -p ~/.config/picom
mkdir -p ~/.config/polybar
mkdir -p ~/.config/kitty
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
  strength = 5;
};

opacity-rule = [
  "92:class_g = 'kitty'",
  "92:class_g = 'Polybar'"
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

modules-left = i3
modules-center = date
modules-right = cpu memory

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

bindsym $mod+Return exec kitty
bindsym $mod+d exec rofi -show drun
bindsym $mod+Shift+q kill
bindsym $mod+Shift+r restart
bindsym $mod+Shift+c reload

# Workspace keys
bindsym $mod+1 workspace 1
bindsym $mod+2 workspace 2
bindsym $mod+3 workspace 3
bindsym $mod+4 workspace 4
bindsym $mod+5 workspace 5
EOF

# -------------------------------------------------
# CREATE DASHBOARD SCRIPT
# -------------------------------------------------

mkdir -p ~/.local/bin

cat > ~/.local/bin/cyber-dashboard << 'EOF'
#!/usr/bin/env bash

kitty --class floating -e btop &
sleep 1

kitty --class floating -e cava &
sleep 1

kitty --class floating -e fastfetch &
sleep 1

kitty --class floating -e cmatrix -b -C green &
EOF

chmod +x ~/.local/bin/cyber-dashboard

# -------------------------------------------------
# DONE
# -------------------------------------------------

echo
echo "======================================="
echo " INSTALL COMPLETE"
echo "======================================="
echo
echo "Log out and choose i3 session."
echo
echo "Then run:"
echo
echo "cyber-dashboard"
echo
