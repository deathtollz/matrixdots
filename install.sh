#!/usr/bin/env bash

# =========================================================
# Modern Arch Linux BSPWM Installer (2026)
# Clean + Fully Functional BSPWM Desktop
# =========================================================

set -euo pipefail

# =========================================================
# USER CHECK
# =========================================================

if [[ $EUID -eq 0 ]]; then
    echo "Do NOT run this script as root."
    echo "Run as your normal user with sudo access."
    exit 1
fi

USERNAME="${SUDO_USER:-$USER}"

# =========================================================
# PACKAGE LIST
# Updated for modern Arch repositories (2026)
# =========================================================

PACKAGES=(
    # -----------------------------------------------------
    # XORG
    # -----------------------------------------------------
    xorg-server
    xorg-xinit
    xorg-xrandr
    xorg-xsetroot
    xorg-xprop
    xclip
    xdg-user-dirs

    # -----------------------------------------------------
    # WINDOW MANAGER
    # -----------------------------------------------------
    bspwm
    sxhkd

    # -----------------------------------------------------
    # TERMINAL / LAUNCHER
    # -----------------------------------------------------
    kitty
    rofi

    # -----------------------------------------------------
    # COMPOSITOR / BAR
    # -----------------------------------------------------
    picom
    polybar

    # -----------------------------------------------------
    # FILE MANAGEMENT
    # -----------------------------------------------------
    thunar
    thunar-volman
    tumbler
    gvfs
    gvfs-mtp
    file-roller
    unzip
    zip
    p7zip

    # -----------------------------------------------------
    # NETWORK
    # -----------------------------------------------------
    networkmanager
    network-manager-applet

    # -----------------------------------------------------
    # AUDIO (PIPEWIRE)
    # -----------------------------------------------------
    pipewire
    wireplumber
    pipewire-pulse
    pipewire-alsa
    pipewire-jack
    pavucontrol
    alsa-utils

    # -----------------------------------------------------
    # BLUETOOTH
    # -----------------------------------------------------
    bluez
    bluez-utils
    blueman

    # -----------------------------------------------------
    # NOTIFICATIONS
    # -----------------------------------------------------
    dunst

    # -----------------------------------------------------
    # THEMING / APPEARANCE
    # -----------------------------------------------------
    lxappearance
    papirus-icon-theme
    arc-gtk-theme

    # -----------------------------------------------------
    # UTILITIES
    # -----------------------------------------------------
    feh
    brightnessctl
    playerctl
    fastfetch
    btop
    neovim
    git
    wget
    curl

    # -----------------------------------------------------
    # FONTS
    # -----------------------------------------------------
    ttf-jetbrains-mono-nerd
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
    ttf-font-awesome

    # -----------------------------------------------------
    # LOGIN MANAGER
    # -----------------------------------------------------
    lightdm
    lightdm-gtk-greeter
)

# =========================================================
# OPTIONAL AUR PACKAGES
# =========================================================

AUR_PACKAGES=(
    bibata-cursor-theme-bin
)

# =========================================================
# SYSTEM UPDATE
# =========================================================

echo "=================================================="
echo " Updating System"
echo "=================================================="

sudo pacman -Syu --noconfirm

# =========================================================
# INSTALL OFFICIAL PACKAGES
# =========================================================

echo "=================================================="
echo " Installing Packages"
echo "=================================================="

sudo pacman -S --needed --noconfirm "${PACKAGES[@]}"

# =========================================================
# ENABLE SERVICES
# =========================================================

echo "=================================================="
echo " Enabling Services"
echo "=================================================="

sudo systemctl enable NetworkManager
sudo systemctl enable bluetooth
sudo systemctl enable lightdm

# =========================================================
# INSTALL YAY
# =========================================================

if ! command -v yay >/dev/null 2>&1; then

    echo "=================================================="
    echo " Installing yay"
    echo "=================================================="

    cd /tmp

    rm -rf yay

    git clone https://aur.archlinux.org/yay.git

    cd yay

    makepkg -si --noconfirm
fi

# =========================================================
# INSTALL AUR PACKAGES
# =========================================================

echo "=================================================="
echo " Installing AUR Packages"
echo "=================================================="

yay -S --needed --noconfirm "${AUR_PACKAGES[@]}"

# =========================================================
# CREATE CONFIG DIRS
# =========================================================

echo "=================================================="
echo " Creating Configuration"
echo "=================================================="

mkdir -p ~/.config/{bspwm,sxhkd,picom,polybar,rofi,dunst,kitty}

# =========================================================
# BSPWM CONFIG
# =========================================================

cat > ~/.config/bspwm/bspwmrc << 'EOF'
#!/usr/bin/env bash

# -------------------------------------------------
# AUTOSTART
# -------------------------------------------------

pgrep -x sxhkd >/dev/null || sxhkd &
pgrep -x picom >/dev/null || picom &
pgrep -x dunst >/dev/null || dunst &
pgrep -x nm-applet >/dev/null || nm-applet &
pgrep -x blueman-applet >/dev/null || blueman-applet &

# -------------------------------------------------
# WALLPAPER
# -------------------------------------------------

feh --bg-fill ~/Pictures/wallpaper.jpg &

# -------------------------------------------------
# POLYBAR
# -------------------------------------------------

killall -q polybar

polybar main &

# -------------------------------------------------
# DESKTOPS
# -------------------------------------------------

bspc monitor -d I II III IV V VI VII VIII IX

# -------------------------------------------------
# APPEARANCE
# -------------------------------------------------

bspc config border_width         2
bspc config window_gap           12
bspc config split_ratio          0.52

bspc config focused_border_color "#89b4fa"
bspc config normal_border_color  "#313244"
bspc config active_border_color  "#cba6f7"
bspc config presel_feedback_color "#f38ba8"

bspc config borderless_monocle true
bspc config gapless_monocle true
EOF

chmod +x ~/.config/bspwm/bspwmrc

# =========================================================
# SXHKD CONFIG
# =========================================================

cat > ~/.config/sxhkd/sxhkdrc << 'EOF'
super + Return
    kitty

super + d
    rofi -show drun

super + Escape
    xkill

super + shift + q
    bspc node -c

super + shift + r
    bspc wm -r

super + alt + {h,j,k,l}
    bspc node -p {west,south,north,east}

super + {h,j,k,l}
    bspc node -f {west,south,north,east}

super + shift + {h,j,k,l}
    bspc node -s {west,south,north,east}

super + {1-9}
    bspc desktop -f '^{1-9}'

super + shift + {1-9}
    bspc node -d '^{1-9}'
EOF

# =========================================================
# PICOM CONFIG
# =========================================================

cat > ~/.config/picom/picom.conf << 'EOF'
backend = "glx";
vsync = true;

corner-radius = 10;

shadow = true;
shadow-radius = 18;
shadow-opacity = 0.25;

fading = true;

blur:
{
  method = "dual_kawase";
  strength = 5;
};

opacity-rule = [
  "95:class_g = 'kitty'"
];
EOF

# =========================================================
# POLYBAR CONFIG
# =========================================================

cat > ~/.config/polybar/config.ini << 'EOF'
[bar/main]
width = 100%
height = 28

background = #11111b
foreground = #cdd6f4

modules-left = bspwm
modules-center = date
modules-right = pulseaudio cpu memory

font-0 = JetBrainsMono Nerd Font:size=10

[module/bspwm]
type = internal/bspwm

[module/date]
type = internal/date
interval = 1
date = %Y-%m-%d %H:%M

[module/cpu]
type = internal/cpu

[module/memory]
type = internal/memory

[module/pulseaudio]
type = internal/pulseaudio
EOF

# =========================================================
# DUNST CONFIG
# =========================================================

cat > ~/.config/dunst/dunstrc << 'EOF'
[global]
font=JetBrainsMono Nerd Font 10
corner_radius=10
offset=15x15
EOF

# =========================================================
# KITTY CONFIG
# =========================================================

cat > ~/.config/kitty/kitty.conf << 'EOF'
font_family JetBrainsMono Nerd Font
font_size 11

background_opacity 0.92
enable_audio_bell no
confirm_os_window_close 0
EOF

# =========================================================
# ROFI CONFIG
# =========================================================

cat > ~/.config/rofi/config.rasi << 'EOF'
configuration {
    modi: "drun,run";
    show-icons: true;
    font: "JetBrainsMono Nerd Font 11";
}
EOF

# =========================================================
# XINITRC
# =========================================================

cat > ~/.xinitrc << 'EOF'
exec bspwm
EOF

# =========================================================
# USER DIRS
# =========================================================

xdg-user-dirs-update

mkdir -p ~/Pictures

# =========================================================
# WALLPAPER PLACEHOLDER
# =========================================================

if [[ ! -f ~/Pictures/wallpaper.jpg ]]; then
    echo "No wallpaper found."
    echo "Place a wallpaper at:"
    echo "~/Pictures/wallpaper.jpg"
fi

# =========================================================
# FINISHED
# =========================================================

echo ""
echo "=================================================="
echo " INSTALLATION COMPLETE"
echo "=================================================="
echo ""
echo "Reboot your system:"
echo ""
echo "    reboot"
echo ""
echo "Login through LightDM."
echo ""
echo "Default Keybinds:"
echo ""
echo " SUPER + ENTER      -> Terminal"
echo " SUPER + D          -> App Launcher"
echo " SUPER + SHIFT + Q  -> Close Window"
echo ""
echo "=================================================="
