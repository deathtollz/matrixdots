#!/usr/bin/env bash
set -euo pipefail

echo "========================================"
echo "  BSPWM CYBERPUNK INSTALLER (2026)"
echo "  Arch / EndeavourOS Compatible"
echo "========================================"

sleep 2

# -------------------------------------------------
# HELPERS
# -------------------------------------------------

log() {
  echo -e "\n[+] $1\n"
}

install_if_missing() {
  for pkg in "$@"; do
    if ! pacman -Qi "$pkg" &>/dev/null; then
      missing+=("$pkg")
    fi
  done

  if [ "${#missing[@]}" -ne 0 ]; then
    sudo pacman -S --noconfirm "${missing[@]}"
  fi
  missing=()
}

mkdir_safe() {
  [ -d "$1" ] || mkdir -p "$1"
}

write_file() {
  local file="$1"
  shift
  mkdir -p "$(dirname "$file")"
  cat > "$file"
}

# -------------------------------------------------
# SYSTEM UPDATE
# -------------------------------------------------

log "Updating system"
sudo pacman -Syu --noconfirm

# -------------------------------------------------
# PACKAGES (2026 CLEAN SET)
# -------------------------------------------------

log "Installing required packages"

install_if_missing \
bspwm \
sxhkd \
polybar \
picom \
kitty \
rofi \
feh \
fastfetch \
cava \
cmatrix \
btop \
lxappearance \
materia-gtk-theme \
papirus-icon-theme \
ttf-font-awesome \
ttf-jetbrains-mono-nerd \
xorg-xrandr \
xorg-xsetroot \
xorg-xinit \
wget \
curl \
unzip \
git

# -------------------------------------------------
# DIRECTORY STRUCTURE
# -------------------------------------------------

log "Creating config directories"

mkdir_safe ~/.config/bspwm
mkdir_safe ~/.config/sxhkd
mkdir_safe ~/.config/picom
mkdir_safe ~/.config/polybar
mkdir_safe ~/.config/kitty
mkdir_safe ~/.local/bin
mkdir_safe ~/Pictures/wallpapers

# -------------------------------------------------
# WALLPAPER
# -------------------------------------------------

log "Downloading wallpaper"

if [ ! -f ~/Pictures/wallpapers/rain.jpg ]; then
  wget -q -O ~/Pictures/wallpapers/rain.jpg \
  https://images.unsplash.com/photo-1500375592092-40eb2168fd21
fi

# -------------------------------------------------
# BSPWM CONFIG
# -------------------------------------------------

log "Writing bspwmrc"

cat > ~/.config/bspwm/bspwmrc <<'EOF'
#!/usr/bin/env bash

picom &
feh --bg-fill ~/Pictures/wallpapers/rain.jpg &

~/.config/polybar/launch.sh &

sxhkd &

bspc config border_width 0
bspc config window_gap 10
bspc config split_ratio 0.52

bspc config focused_border_color "#00ffcc"
bspc config normal_border_color "#000000"

bspc config top_padding 30
bspc config left_padding 5
bspc config right_padding 5
bspc config bottom_padding 5

bspc monitor -d 1 2 3 4 5 6
EOF

chmod +x ~/.config/bspwm/bspwmrc

# -------------------------------------------------
# SXHKD CONFIG (FIXED)
# -------------------------------------------------

log "Writing sxhkdrc"

cat > ~/.config/sxhkd/sxhkdrc <<'EOF'

super + Return
    kitty

super + d
    rofi -show drun

super + shift + q
    bspc node -c

super + shift + r
    bspc wm -r

super + shift + space
    bspc node -t floating

super + {h,j,k,l}
    bspc node -f {west,south,north,east}

super + shift + {h,j,k,l}
    bspc node -s {west,south,north,east}

super + {1-6}
    bspc desktop -f {1,2,3,4,5,6}

EOF

# -------------------------------------------------
# PICOM (MODERN COMPATIBLE)
# -------------------------------------------------

log "Writing picom config"

cat > ~/.config/picom/picom.conf <<'EOF'

backend = "glx";
vsync = true;

shadow = true;
shadow-radius = 12;
shadow-opacity = 0.35;

corner-radius = 8;

blur-method = "dual_kawase";
blur-strength = 7;

opacity-rule = [
  "92:class_g = 'kitty'",
  "95:class_g = 'Polybar'"
];

EOF

# -------------------------------------------------
# POLYBAR CONFIG + LAUNCHER
# -------------------------------------------------

log "Writing polybar config"

cat > ~/.config/polybar/config.ini <<'EOF'

[colors]
background = #000000
foreground = #00ffcc

[bar/main]
width = 100%
height = 24

background = ${colors.background}
foreground = ${colors.foreground}

font-0 = JetBrainsMono Nerd Font:size=10

modules-left = bspwm
modules-center = date
modules-right = cpu memory filesystem

[module/bspwm]
type = internal/bspwm

[module/date]
type = internal/date
interval = 1
date = %A %d %B %Y %H:%M:%S

[module/cpu]
type = internal/cpu
interval = 2
format-prefix = "CPU "

[module/memory]
type = internal/memory
interval = 2
format-prefix = "RAM "

[module/filesystem]
type = internal/fs
mount-0 = /
label-mounted = %{F#00ffcc}%percentage_used%%

EOF

log "Writing polybar launcher"

cat > ~/.config/polybar/launch.sh <<'EOF'
#!/usr/bin/env bash

killall -q polybar || true
polybar main &
EOF

chmod +x ~/.config/polybar/launch.sh

# -------------------------------------------------
# KITTY CONFIG
# -------------------------------------------------

log "Writing kitty config"

cat > ~/.config/kitty/kitty.conf <<'EOF'

font_family JetBrainsMono Nerd Font
font_size 11

background #000000
foreground #00ffcc

background_opacity 0.85

cursor #00ffcc

EOF

# -------------------------------------------------
# GTK THEME (SAFE MODERN DEFAULT)
# -------------------------------------------------

log "Writing GTK config"

mkdir_safe ~/.config/gtk-3.0

cat > ~/.config/gtk-3.0/settings.ini <<'EOF'
[Settings]
gtk-theme-name=Materia-dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=JetBrainsMono Nerd Font 10
EOF

# -------------------------------------------------
# DASHBOARD TOOL
# -------------------------------------------------

log "Creating cyber dashboard"

cat > ~/.local/bin/cyber-dashboard <<'EOF'
#!/usr/bin/env bash

setsid kitty --title btop -e btop &
setsid kitty --title cava -e cava &
setsid kitty --title fastfetch -e fastfetch &
setsid kitty --title matrix -e cmatrix -b -C green &
EOF

chmod +x ~/.local/bin/cyber-dashboard

# -------------------------------------------------
# XINITRC SAFE
# -------------------------------------------------

log "Configuring xinitrc"

if ! grep -q "exec bspwm" ~/.xinitrc 2>/dev/null; then
  echo "exec bspwm" >> ~/.xinitrc
fi

# -------------------------------------------------
# DONE
# -------------------------------------------------

echo ""
echo "========================================"
echo " INSTALL COMPLETE (2026 READY)"
echo "========================================"
echo ""
echo "Start session:"
echo "  startx"
echo ""
echo "Then run:"
echo "  cyber-dashboard"
echo ""
