#!/usr/bin/env bash
# =============================================================================
#  ARCH LINUX — BSPWM POST-INSTALL SETUP
#  Run this on a fresh Arch base install (after pacstrap + chroot + reboot)
#  Installs and configures the full BSPWM desktop environment from scratch
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

# ─── COLORS ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[0;33m'
BLU='\033[0;34m'; MAG='\033[0;35m'; CYN='\033[0;36m'
BOLD='\033[1m'; RST='\033[0m'

LOG_FILE="$HOME/bspwm-setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

info()    { echo -e "${BLU}${BOLD}[INFO]${RST}  $*"; }
ok()      { echo -e "${GRN}${BOLD}[ OK ]${RST}  $*"; }
warn()    { echo -e "${YLW}${BOLD}[WARN]${RST}  $*"; }
err()     { echo -e "${RED}${BOLD}[ERR ]${RST}  $*" >&2; exit 1; }
section() { echo -e "\n${MAG}${BOLD}══════════════════════════════════════════${RST}";
            echo -e "${MAG}${BOLD}  $*${RST}";
            echo -e "${MAG}${BOLD}══════════════════════════════════════════${RST}\n"; }

# ─── CHECKS ─────────────────────────────────────────────────────────────────
section "Pre-flight Checks"

[[ $EUID -ne 0 ]] && err "Run as root: sudo bash bspwm-setup.sh"

ping -c 2 -W 3 archlinux.org &>/dev/null || err "No internet connection."
ok "Internet OK"

# Detect the real user (the one who called sudo, or first non-root user)
if [[ -n "${SUDO_USER:-}" ]]; then
    REALUSER="$SUDO_USER"
elif id -u "$USER" &>/dev/null && [[ "$USER" != "root" ]]; then
    REALUSER="$USER"
else
    # Fall back to first non-root user in /home
    REALUSER=$(ls /home | head -1)
fi

[[ -z "$REALUSER" ]] && err "Could not determine a non-root user. Create one first."
USERHOME="/home/$REALUSER"
[[ -d "$USERHOME" ]] || err "Home directory $USERHOME does not exist."

ok "Target user: $REALUSER ($USERHOME)"

# ─── PACMAN SETUP ───────────────────────────────────────────────────────────
section "Pacman Configuration"

# Enable Color, ILoveCandy, ParallelDownloads if not already set
grep -q "^Color" /etc/pacman.conf             || sed -i 's/^#Color/Color/' /etc/pacman.conf
grep -q "^ILoveCandy" /etc/pacman.conf        || sed -i '/^# Misc options/a ILoveCandy' /etc/pacman.conf
grep -q "^ParallelDownloads" /etc/pacman.conf || sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf
grep -q "^VerbosePkgLists" /etc/pacman.conf   || sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf

pacman -Sy --noconfirm
ok "Pacman configured"

# ─── MIRROR OPTIMIZATION ────────────────────────────────────────────────────
section "Optimizing Mirrors"
pacman -S --noconfirm --needed reflector rsync
reflector \
    --country Canada,US \
    --age 12 \
    --protocol https \
    --sort rate \
    --fastest 10 \
    --save /etc/pacman.d/mirrorlist
pacman -Sy --noconfirm
ok "Mirrors optimized"

# ─── PACKAGE INSTALLATION ───────────────────────────────────────────────────
section "Installing Desktop Stack"

PKGS=(
    # Xorg
    xorg-server xorg-xinit xorg-xrandr xorg-xsetroot
    xorg-xev xorg-xprop xorg-xinput
    xdg-utils xdg-user-dirs

    # WM + hotkeys
    bspwm sxhkd

    # Compositor
    picom

    # Bar
    polybar

    # Launcher
    rofi

    # Notifications
    dunst libnotify

    # Terminal
    alacritty

    # Display manager
    ly

    # Audio — PipeWire stack
    pipewire pipewire-alsa pipewire-pulse pipewire-jack
    wireplumber pavucontrol

    # Bluetooth
    bluez bluez-utils blueman

    # File managers
    thunar thunar-archive-plugin thunar-volman
    gvfs gvfs-mtp file-roller
    ranger

    # Fonts
    noto-fonts noto-fonts-emoji noto-fonts-cjk
    ttf-jetbrains-mono-nerd ttf-firacode-nerd
    ttf-font-awesome

    # Images / wallpaper
    feh imv

    # GTK theming
    lxappearance
    gtk2 gtk3
    arc-gtk-theme
    papirus-icon-theme
    xcursor-themes

    # Screenshots
    maim slop xclip

    # System utilities
    htop btop fastfetch
    zip unzip p7zip
    openssh
    acpi acpid upower
    polkit lxsession
    xdotool
    brightnessctl playerctl
    wget curl

    # Network
    networkmanager network-manager-applet nm-connection-editor

    # Dev tools
    git base-devel

    # Multimedia
    mpv ffmpeg
)

pacman -S --noconfirm --needed "${PKGS[@]}"
ok "All packages installed"

# ─── ENABLE SERVICES ────────────────────────────────────────────────────────
section "Enabling System Services"

systemctl enable --now NetworkManager
systemctl enable --now bluetooth
systemctl enable --now acpid
systemctl enable ly        # display manager — don't start now, we're in a TTY

# PipeWire as user service
sudo -u "$REALUSER" systemctl --user enable pipewire pipewire-pulse wireplumber 2>/dev/null || true

ok "Services enabled"

# ─── AUR HELPER (paru) ──────────────────────────────────────────────────────
section "Installing AUR Helper: paru"

if ! command -v paru &>/dev/null; then
    pacman -S --noconfirm --needed rust git base-devel
    sudo -u "$REALUSER" bash -c "
        rm -rf /tmp/paru-bin
        git clone https://aur.archlinux.org/paru-bin.git /tmp/paru-bin
        cd /tmp/paru-bin
        makepkg -si --noconfirm
        rm -rf /tmp/paru-bin
    " && ok "paru installed" || warn "paru install failed — install manually: https://github.com/Morganamilo/paru"
else
    ok "paru already installed, skipping"
fi

# ─── CREATE CONFIG DIRECTORIES ──────────────────────────────────────────────
section "Creating Config Directories"

CFG="$USERHOME/.config"
mkdir -p \
    "$CFG/bspwm" \
    "$CFG/sxhkd" \
    "$CFG/polybar" \
    "$CFG/picom" \
    "$CFG/rofi" \
    "$CFG/dunst" \
    "$CFG/alacritty" \
    "$USERHOME/.local/share/wallpapers" \
    "$USERHOME/Pictures" \
    "$USERHOME/Screenshots"

ok "Config directories created"

# ─── BSPWMRC ────────────────────────────────────────────────────────────────
section "Writing bspwmrc"

cat > "$CFG/bspwm/bspwmrc" << 'EOF'
#!/usr/bin/env bash

# ── Monitors & Desktops ──────────────────────────────────────────────────────
for monitor in $(bspc query -M --names); do
    bspc monitor "$monitor" -d I II III IV V VI VII VIII IX X
done

# ── SXHKD ────────────────────────────────────────────────────────────────────
pgrep -x sxhkd > /dev/null || sxhkd &

# ── Global Settings ───────────────────────────────────────────────────────────
bspc config border_width          2
bspc config window_gap            10
bspc config top_padding           35     # clearance for polybar
bspc config bottom_padding        0
bspc config left_padding          0
bspc config right_padding         0

bspc config split_ratio           0.52
bspc config borderless_monocle    true
bspc config gapless_monocle       true
bspc config single_monocle        false
bspc config focus_follows_pointer true
bspc config pointer_follows_focus false
bspc config click_to_focus        button1

# ── Colors (Nord palette) ─────────────────────────────────────────────────────
bspc config normal_border_color   "#3b4252"
bspc config active_border_color   "#4c566a"
bspc config focused_border_color  "#88c0d0"
bspc config presel_feedback_color "#81a1c1"

# ── Window Rules ──────────────────────────────────────────────────────────────
bspc rule -a Gimp                 desktop='^8' state=floating follow=on
bspc rule -a Thunar               state=floating
bspc rule -a Pavucontrol          state=floating
bspc rule -a Blueman-manager      state=floating
bspc rule -a nm-connection-editor state=floating
bspc rule -a Lxappearance         state=floating
bspc rule -a feh                  state=floating

# ── Autostart ─────────────────────────────────────────────────────────────────

# Compositor
pgrep -x picom > /dev/null || picom --daemon

# Wallpaper — uses last set wallpaper or picks from collection
if [[ -f ~/.fehbg ]]; then
    ~/.fehbg
else
    # Pick a random wallpaper if any exist, otherwise solid color
    WP=$(find ~/.local/share/wallpapers -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \) 2>/dev/null | shuf -n1)
    if [[ -n "$WP" ]]; then
        feh --no-fehbg --bg-fill "$WP"
    else
        xsetroot -solid '#2e3440'
    fi
fi

# Polybar
~/.config/polybar/launch.sh &

# System tray utilities
pgrep -x nm-applet  > /dev/null || nm-applet  --indicator &
pgrep -x dunst      > /dev/null || dunst &

# Authentication agent
pgrep -x lxpolkit   > /dev/null || lxpolkit &

# Cursor
xsetroot -cursor_name left_ptr

# Keyboard repeat: delay ms, rate keys/s
xset r rate 300 50

# Disable screen blanking
xset s off
xset -dpms
xset s noblank
EOF

chmod +x "$CFG/bspwm/bspwmrc"
ok "bspwmrc written"

# ─── SXHKDRC ────────────────────────────────────────────────────────────────
section "Writing sxhkdrc"

cat > "$CFG/sxhkd/sxhkdrc" << 'EOF'
# ══════════════════════════════════════════════════════════════
#  SXHKD — Hotkey Configuration
# ══════════════════════════════════════════════════════════════

# ── Applications ─────────────────────────────────────────────

# Terminal
super + Return
    alacritty

# App launcher (drun)
super + d
    rofi -show drun

# Run command
super + r
    rofi -show run

# Window switcher
super + w
    rofi -show window

# File manager
super + e
    thunar

# ── WM Controls ──────────────────────────────────────────────

# Quit / restart bspwm
super + alt + {q,r}
    bspc {quit,wm -r}

# Reload sxhkd config
super + Escape
    pkill -USR1 -x sxhkd

# Close window
super + q
    bspc node -c

# Kill window (force)
super + shift + q
    bspc node -k

# ── Window State ─────────────────────────────────────────────

# Toggle fullscreen
super + f
    bspc node -t ~fullscreen

# Toggle floating
super + shift + space
    bspc node -t ~floating

# Toggle monocle layout
super + m
    bspc desktop -l next

# Toggle pseudo-tiled
super + p
    bspc node -t ~pseudo_tiled

# ── Focus ────────────────────────────────────────────────────

# Focus node — vim keys
super + {h,j,k,l}
    bspc node -f {west,south,north,east}

# Focus node — arrow keys
super + {Left,Down,Up,Right}
    bspc node -f {west,south,north,east}

# Focus next / previous window on desktop
super + {_,shift + }c
    bspc node -f {next,prev}.local.!hidden.window

# Focus last node / desktop
super + {grave,Tab}
    bspc {node,desktop} -f last

# ── Swap ─────────────────────────────────────────────────────

# Swap node — vim keys
super + shift + {h,j,k,l}
    bspc node -s {west,south,north,east}

# Swap node — arrow keys
super + shift + {Left,Down,Up,Right}
    bspc node -s {west,south,north,east}

# ── Desktops ─────────────────────────────────────────────────

# Focus desktop 1-10
super + {1-9,0}
    bspc desktop -f '^{1-9,10}'

# Move window to desktop 1-10 and follow
super + shift + {1-9,0}
    bspc node -d '^{1-9,10}' --follow

# Cycle desktops
super + bracket{left,right}
    bspc desktop -f {prev,next}.local

# Move window to prev/next desktop
super + shift + bracket{left,right}
    bspc node -d {prev,next}.local --follow

# ── Resize ───────────────────────────────────────────────────

# Preselect split direction
super + ctrl + {h,j,k,l}
    bspc node -p {west,south,north,east}

super + ctrl + {Left,Down,Up,Right}
    bspc node -p {west,south,north,east}

# Preselect split ratio
super + ctrl + {1-9}
    bspc node -o 0.{1-9}

# Cancel preselection (node)
super + ctrl + space
    bspc node -p cancel

# Cancel preselection (desktop)
super + ctrl + shift + space
    bspc query -N -d | xargs -I id -n 1 bspc node id -p cancel

# Expand window (resize outward)
super + alt + {h,j,k,l}
    bspc node -z {left -20 0,bottom 0 20,top 0 -20,right 20 0}

# Contract window (resize inward)
super + alt + shift + {h,j,k,l}
    bspc node -z {right -20 0,top 0 20,bottom 0 -20,left 20 0}

# ── Media Keys ───────────────────────────────────────────────

# Volume
XF86AudioRaiseVolume
    pactl set-sink-volume @DEFAULT_SINK@ +5%

XF86AudioLowerVolume
    pactl set-sink-volume @DEFAULT_SINK@ -5%

XF86AudioMute
    pactl set-sink-mute @DEFAULT_SINK@ toggle

XF86AudioMicMute
    pactl set-source-mute @DEFAULT_SOURCE@ toggle

# Brightness
XF86MonBrightnessUp
    brightnessctl set 10%+

XF86MonBrightnessDown
    brightnessctl set 10%-

# Playback
XF86AudioPlay
    playerctl play-pause

XF86AudioNext
    playerctl next

XF86AudioPrev
    playerctl previous

# ── Screenshots ──────────────────────────────────────────────

# Full screen → file
Print
    maim ~/Screenshots/$(date +%Y%m%d_%H%M%S).png \
    && notify-send "Screenshot" "Saved to ~/Screenshots"

# Select region → file
super + Print
    maim -s ~/Screenshots/$(date +%Y%m%d_%H%M%S).png \
    && notify-send "Screenshot" "Region saved to ~/Screenshots"

# Full screen → clipboard
ctrl + Print
    maim | xclip -selection clipboard -t image/png \
    && notify-send "Screenshot" "Copied to clipboard"

# Select region → clipboard
ctrl + super + Print
    maim -s | xclip -selection clipboard -t image/png \
    && notify-send "Screenshot" "Region copied to clipboard"
EOF

ok "sxhkdrc written"

# ─── PICOM ──────────────────────────────────────────────────────────────────
section "Writing picom.conf"

cat > "$CFG/picom/picom.conf" << 'EOF'
# ══════════════════════════════════════════════════════════════
#  Picom Compositor Configuration
# ══════════════════════════════════════════════════════════════

# ── Backend ──────────────────────────────────────────────────
backend         = "glx";
glx-no-stencil  = true;
use-damage      = true;
vsync           = true;

# ── Shadows ──────────────────────────────────────────────────
shadow          = true;
shadow-radius   = 14;
shadow-offset-x = -7;
shadow-offset-y = -7;
shadow-opacity  = 0.55;
shadow-exclude  = [
    "name = 'Notification'",
    "class_g = 'Conky'",
    "class_g ?= 'Notify-osd'",
    "_GTK_FRAME_EXTENTS@:c"
];

# ── Fading ───────────────────────────────────────────────────
fading        = true;
fade-in-step  = 0.04;
fade-out-step = 0.04;
fade-delta    = 4;
no-fading-openclose = false;

# ── Opacity ──────────────────────────────────────────────────
inactive-opacity          = 0.93;
active-opacity            = 1.0;
frame-opacity             = 1.0;
inactive-opacity-override = false;

opacity-rule = [
    "100:class_g = 'Alacritty' && focused",
    "88:class_g  = 'Alacritty' && !focused",
    "100:class_g = 'Thunar'",
    "100:class_g = 'Gimp'",
    "100:class_g = 'Pavucontrol'"
];

# ── Rounded Corners ──────────────────────────────────────────
corner-radius = 8;
rounded-corners-exclude = [
    "class_g = 'Polybar'",
    "class_g = 'dmenu'"
];

# ── General ──────────────────────────────────────────────────
mark-wmwin-focused    = true;
mark-ovredir-focused  = true;
detect-rounded-corners = true;
detect-client-opacity  = true;
detect-transient       = true;
detect-client-leader   = true;
EOF

ok "picom.conf written"

# ─── POLYBAR ────────────────────────────────────────────────────────────────
section "Writing Polybar config"

cat > "$CFG/polybar/launch.sh" << 'EOF'
#!/usr/bin/env bash
# Kill any running polybar instances
killall -q polybar

# Wait for them to die
while pgrep -u $UID -x polybar > /dev/null; do sleep 0.5; done

# Launch one bar per monitor
for m in $(polybar --list-monitors | cut -d":" -f1); do
    MONITOR=$m polybar --reload main 2>&1 | tee -a /tmp/polybar-$m.log & disown
done
EOF
chmod +x "$CFG/polybar/launch.sh"

cat > "$CFG/polybar/config.ini" << 'EOF'
; ══════════════════════════════════════════════════════════════
;  Polybar Configuration — Nord Theme
; ══════════════════════════════════════════════════════════════

[colors]
bg        = #CC2e3440
bg-alt    = #3b4252
bg-solid  = #2e3440
fg        = #eceff4
fg-alt    = #4c566a
primary   = #88c0d0
secondary = #81a1c1
alert     = #bf616a
good      = #a3be8c
warn      = #ebcb8b

; ── Bar ──────────────────────────────────────────────────────
[bar/main]
monitor          = ${env:MONITOR:}
width            = 100%
height           = 30
radius           = 0
fixed-center     = true

background       = ${colors.bg}
foreground       = ${colors.fg}

line-size        = 2
line-color       = ${colors.primary}

border-size      = 0
padding-left     = 2
padding-right    = 2
module-margin    = 1

font-0 = "JetBrainsMono Nerd Font:size=10:weight=bold;2"
font-1 = "Font Awesome 6 Free Solid:size=10;2"
font-2 = "Font Awesome 6 Brands Regular:size=10;2"
font-3 = "Noto Color Emoji:scale=9;2"

modules-left   = bspwm xwindow
modules-center = date
modules-right  = cpu memory temperature pulseaudio battery network tray

wm-restack        = bspwm
override-redirect = true
cursor-click      = pointer
cursor-scroll     = ns-resize

tray-position   = none   ; handled by [module/tray]
enable-ipc      = true

; ── Modules ──────────────────────────────────────────────────

[module/bspwm]
type = internal/bspwm

pin-workspaces        = true
inline-mode           = false
enable-click          = true
enable-scroll         = true
reverse-scroll        = false

label-focused              = %name%
label-focused-background   = ${colors.primary}
label-focused-foreground   = ${colors.bg-solid}
label-focused-padding      = 2

label-occupied             = %name%
label-occupied-foreground  = ${colors.fg}
label-occupied-padding     = 2

label-urgent               = %name%
label-urgent-background    = ${colors.alert}
label-urgent-padding       = 2

label-empty                = %name%
label-empty-foreground     = ${colors.fg-alt}
label-empty-padding        = 2

[module/xwindow]
type             = internal/xwindow
label            = %title:0:60:…%
label-foreground = ${colors.fg-alt}
label-padding    = 1

[module/date]
type     = internal/date
interval = 1
date     =  %a %b %d
time     =  %H:%M:%S
label    = %date%  %time%
label-foreground = ${colors.primary}

[module/cpu]
type                     = internal/cpu
interval                 = 2
format-prefix            = " "
format-prefix-foreground = ${colors.secondary}
label                    = %percentage:2%%

[module/memory]
type                     = internal/memory
interval                 = 2
format-prefix            = " "
format-prefix-foreground = ${colors.secondary}
label                    = %percentage_used%%

[module/temperature]
type             = internal/temperature
thermal-zone     = 0
base-temperature = 20
warn-temperature = 80
format-prefix    = " "
format-prefix-foreground = ${colors.secondary}
format-warn-prefix = " "
format-warn-prefix-foreground = ${colors.alert}
label            = %temperature-c%
label-warn       = %temperature-c%
label-warn-foreground = ${colors.alert}

[module/pulseaudio]
type             = internal/pulseaudio
use-ui-max       = true
interval         = 5

format-volume             = <ramp-volume> <label-volume>
label-volume              = %percentage%%
label-muted               = 婢 muted
label-muted-foreground    = ${colors.fg-alt}

ramp-volume-0             = 
ramp-volume-1             = 
ramp-volume-2             = 
ramp-volume-foreground    = ${colors.good}

click-right               = pavucontrol &

[module/battery]
type             = internal/battery
battery          = BAT0
adapter          = AC
full-at          = 98
poll-interval    = 5

format-charging            = <animation-charging> <label-charging>
format-discharging         = <ramp-capacity> <label-discharging>
format-full-prefix         = " "
format-full-prefix-foreground = ${colors.good}

ramp-capacity-0            = 
ramp-capacity-1            = 
ramp-capacity-2            = 
ramp-capacity-3            = 
ramp-capacity-4            = 
ramp-capacity-foreground   = ${colors.good}

animation-charging-0       = 
animation-charging-1       = 
animation-charging-2       = 
animation-charging-3       = 
animation-charging-4       = 
animation-charging-foreground = ${colors.warn}
animation-charging-framerate  = 750

label-discharging          = %percentage%%
label-charging             = %percentage%%
label-full                 = Full

[module/network]
type             = internal/network
interface-type   = wireless
interval         = 3

format-connected             = <label-connected>
format-connected-prefix      = "直 "
format-connected-prefix-foreground = ${colors.good}

format-disconnected          = <label-disconnected>
format-disconnected-prefix   = "睊 "
format-disconnected-prefix-foreground = ${colors.alert}

label-connected              = %essid% %signal%%
label-disconnected           = offline
label-disconnected-foreground = ${colors.fg-alt}

[module/tray]
type         = internal/tray
tray-size    = 18
tray-spacing = 4px
EOF

ok "Polybar config written"

# ─── ROFI ───────────────────────────────────────────────────────────────────
section "Writing Rofi config"

cat > "$CFG/rofi/config.rasi" << 'EOF'
configuration {
    modi:                "drun,run,window";
    show-icons:          true;
    icon-theme:          "Papirus";
    font:                "JetBrainsMono Nerd Font 11";
    drun-display-format: "{name}";
    display-drun:        " Apps";
    display-run:         " Run";
    display-window:      " Windows";
    kb-cancel:           "Escape,super+d";
    matching:            "fuzzy";
    sort:                true;
    sorting-method:      "fzf";
}

* {
    bg:      #2e3440;
    bg-alt:  #3b4252;
    fg:      #eceff4;
    fg-alt:  #4c566a;
    accent:  #88c0d0;
    urgent:  #bf616a;
    transparent: #00000000;

    background-color: @transparent;
    text-color:       @fg;
}

window {
    width:            480px;
    border:           2px solid;
    border-color:     @accent;
    border-radius:    8px;
    background-color: @bg;
}

mainbox {
    background-color: @transparent;
    children: [ inputbar, listview, mode-switcher ];
}

inputbar {
    background-color: @bg-alt;
    border-radius:    6px 6px 0 0;
    padding:          10px 14px;
    children:         [ prompt, textbox-prompt-colon, entry ];
}

prompt {
    text-color: @accent;
    font:       "JetBrainsMono Nerd Font Bold 11";
}

textbox-prompt-colon {
    text-color: @accent;
    margin:     0 8px 0 0;
}

entry {
    placeholder:       "Search...";
    placeholder-color: @fg-alt;
}

listview {
    padding:          8px;
    spacing:          3px;
    background-color: @transparent;
    scrollbar:        false;
    lines:            10;
}

element {
    padding:          8px 10px;
    border-radius:    5px;
    background-color: @transparent;
    orientation:      horizontal;
}

element normal normal    { background-color: @transparent; }
element normal urgent    { text-color: @urgent; }
element selected normal  { background-color: @accent; text-color: @bg; }
element selected urgent  { background-color: @urgent; text-color: @bg; }

element-icon {
    size:   22px;
    margin: 0 10px 0 0;
}

element-text { vertical-align: 0.5; }

mode-switcher {
    background-color: @bg-alt;
    border-radius:    0 0 6px 6px;
    padding:          4px 8px;
    spacing:          6px;
}

button {
    padding:          5px 12px;
    border-radius:    4px;
    text-color:       @fg-alt;
    background-color: @transparent;
}

button selected {
    background-color: @accent;
    text-color:       @bg;
}
EOF

ok "Rofi config written"

# ─── DUNST ──────────────────────────────────────────────────────────────────
section "Writing dunstrc"

cat > "$CFG/dunst/dunstrc" << 'EOF'
[global]
    monitor                    = 0
    follow                     = mouse
    width                      = 330
    height                     = 120
    origin                     = top-right
    offset                     = 14x46
    scale                      = 0
    notification_limit         = 5
    progress_bar               = true
    progress_bar_height        = 8
    progress_bar_frame_width   = 1
    indicate_hidden            = yes
    transparency               = 8
    separator_height           = 2
    padding                    = 12
    horizontal_padding         = 14
    text_icon_padding          = 8
    frame_width                = 2
    frame_color                = "#88c0d0"
    sort                       = yes
    idle_threshold             = 120
    font                       = JetBrainsMono Nerd Font 10
    line_height                = 0
    markup                     = full
    format                     = "<b>%s</b>\n%b"
    alignment                  = left
    vertical_alignment         = center
    show_age_threshold         = 60
    ellipsize                  = middle
    ignore_newline             = no
    stack_duplicates           = true
    hide_duplicate_count       = false
    show_indicators            = yes
    icon_theme                 = Papirus, Adwaita
    enable_recursive_icon_lookup = true
    sticky_history             = yes
    history_length             = 25
    dmenu                      = /usr/bin/rofi -p dunst
    browser                    = /usr/bin/xdg-open
    always_run_script          = true
    title                      = Dunst
    class                      = Dunst
    corner_radius              = 7
    ignore_dbusclose           = false
    mouse_left_click           = close_current
    mouse_middle_click         = do_action, close_current
    mouse_right_click          = close_all

[urgency_low]
    background  = "#2e3440"
    foreground  = "#eceff4"
    frame_color = "#4c566a"
    timeout     = 5
    default_icon = dialog-information

[urgency_normal]
    background  = "#2e3440"
    foreground  = "#eceff4"
    frame_color = "#88c0d0"
    timeout     = 8
    default_icon = dialog-information

[urgency_critical]
    background  = "#2e3440"
    foreground  = "#bf616a"
    frame_color = "#bf616a"
    timeout     = 0
    default_icon = dialog-error
EOF

ok "dunstrc written"

# ─── ALACRITTY ──────────────────────────────────────────────────────────────
section "Writing Alacritty config"

cat > "$CFG/alacritty/alacritty.toml" << 'EOF'
[window]
padding         = { x = 14, y = 12 }
decorations     = "full"
opacity         = 0.92
startup_mode    = "Windowed"
title           = "Alacritty"
dynamic_title   = true

[scrolling]
history    = 10000
multiplier = 3

[font]
normal  = { family = "JetBrainsMono Nerd Font", style = "Regular" }
bold    = { family = "JetBrainsMono Nerd Font", style = "Bold" }
italic  = { family = "JetBrainsMono Nerd Font", style = "Italic" }
size    = 11.0
offset  = { x = 0, y = 1 }

[cursor]
style         = { shape = "Block", blinking = "On" }
blink_interval = 500
unfocused_hollow = true

# Nord color scheme
[colors.primary]
background    = "#2e3440"
foreground    = "#d8dee9"
dim_foreground = "#a5abb6"

[colors.cursor]
text   = "#2e3440"
cursor = "#d8dee9"

[colors.selection]
text       = "CellForeground"
background = "#4c566a"

[colors.normal]
black   = "#3b4252"
red     = "#bf616a"
green   = "#a3be8c"
yellow  = "#ebcb8b"
blue    = "#81a1c1"
magenta = "#b48ead"
cyan    = "#88c0d0"
white   = "#e5e9f0"

[colors.bright]
black   = "#4c566a"
red     = "#bf616a"
green   = "#a3be8c"
yellow  = "#ebcb8b"
blue    = "#81a1c1"
magenta = "#b48ead"
cyan    = "#8fbcbb"
white   = "#eceff4"

[[keyboard.bindings]]
key = "V"     ; mods = "Control|Shift" ; action = "Paste"
[[keyboard.bindings]]
key = "C"     ; mods = "Control|Shift" ; action = "Copy"
[[keyboard.bindings]]
key = "Plus"  ; mods = "Control"       ; action = "IncreaseFontSize"
[[keyboard.bindings]]
key = "Minus" ; mods = "Control"       ; action = "DecreaseFontSize"
[[keyboard.bindings]]
key = "Key0"  ; mods = "Control"       ; action = "ResetFontSize"
[[keyboard.bindings]]
key = "F11"                            ; action = "ToggleFullscreen"
EOF

ok "Alacritty config written"

# ─── GTK THEME ──────────────────────────────────────────────────────────────
section "Applying GTK Theme (Arc-Dark + Papirus)"

mkdir -p "$USERHOME/.config/gtk-3.0"

cat > "$USERHOME/.config/gtk-3.0/settings.ini" << 'EOF'
[Settings]
gtk-theme-name           = Arc-Dark
gtk-icon-theme-name      = Papirus-Dark
gtk-font-name            = Noto Sans 10
gtk-cursor-theme-name    = Adwaita
gtk-cursor-theme-size    = 16
gtk-toolbar-style        = GTK_TOOLBAR_ICONS
gtk-button-images        = 0
gtk-menu-images          = 0
gtk-enable-event-sounds  = 0
gtk-enable-input-feedback-sounds = 0
gtk-xft-antialias        = 1
gtk-xft-hinting          = 1
gtk-xft-hintstyle        = hintslight
gtk-xft-rgba             = rgb
EOF

cat > "$USERHOME/.gtkrc-2.0" << 'EOF'
gtk-theme-name        = "Arc-Dark"
gtk-icon-theme-name   = "Papirus-Dark"
gtk-font-name         = "Noto Sans 10"
gtk-cursor-theme-name = "Adwaita"
EOF

ok "GTK theme applied"

# ─── XINITRC ────────────────────────────────────────────────────────────────
section "Writing .xinitrc"

cat > "$USERHOME/.xinitrc" << 'EOF'
#!/usr/bin/env bash

# X resources
[[ -f ~/.Xresources ]] && xrdb -merge ~/.Xresources

# Set keyboard repeat
xset r rate 300 50

# Disable screen blanking
xset s off
xset -dpms
xset s noblank

exec bspwm
EOF
chmod +x "$USERHOME/.xinitrc"
ok ".xinitrc written"

# ─── XRESOURCES ─────────────────────────────────────────────────────────────
cat > "$USERHOME/.Xresources" << 'EOF'
! DPI — adjust for your monitor (96 = standard, 192 = HiDPI)
Xft.dpi:        96
Xft.antialias:  true
Xft.hinting:    true
Xft.hintstyle:  hintslight
Xft.rgba:       rgb

! Cursor size
Xcursor.size:   16
Xcursor.theme:  Adwaita
EOF

# ─── BASHRC ADDITIONS ───────────────────────────────────────────────────────
section "Updating .bashrc"

# Only add if not already present
if ! grep -q "# BSPWM Setup Additions" "$USERHOME/.bashrc" 2>/dev/null; then
cat >> "$USERHOME/.bashrc" << 'EOF'

# ── BSPWM Setup Additions ────────────────────────────────────────────────────

# Aliases
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias grep='grep --color=auto'
alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -Iv'
alias mkdir='mkdir -pv'
alias df='df -h'
alias free='free -m'
alias du='du -sh'
alias ..='cd ..'
alias ...='cd ../..'

# Pacman shortcuts
alias pacup='sudo pacman -Syu'
alias pacin='sudo pacman -S'
alias pacrem='sudo pacman -Rns'
alias pacsearch='pacman -Ss'
alias pacinfo='pacman -Si'
alias paclist='pacman -Qs'

# Colored prompt
RESET='\[\e[0m\]'
BOLD='\[\e[1m\]'
CYAN='\[\e[36m\]'
BLUE='\[\e[34m\]'
GREEN='\[\e[32m\]'
RED='\[\e[31m\]'
PS1="${BOLD}${CYAN}[${BLUE}\u${CYAN}@${GREEN}\h${CYAN}] ${BLUE}\w${RESET}\$ "

# fastfetch on new terminal
command -v fastfetch &>/dev/null && fastfetch
EOF
fi
ok ".bashrc updated"

# ─── XDG USER DIRS ──────────────────────────────────────────────────────────
sudo -u "$REALUSER" xdg-user-dirs-update

# ─── FIX OWNERSHIP ──────────────────────────────────────────────────────────
section "Fixing Ownership"
chown -R "$REALUSER:$REALUSER" "$USERHOME"
ok "Ownership set for $REALUSER"

# ─── SUDOERS CHECK ──────────────────────────────────────────────────────────
section "Verifying Sudo Access"
if ! groups "$REALUSER" | grep -q wheel; then
    warn "$REALUSER is not in the wheel group. Adding..."
    usermod -aG wheel "$REALUSER"
fi
if ! grep -q "^%wheel ALL=(ALL:ALL) ALL" /etc/sudoers; then
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
    ok "Wheel group sudoers entry enabled"
else
    ok "Sudoers already configured"
fi

# ─── FINAL SUMMARY ──────────────────────────────────────────────────────────
section "Setup Complete"

echo -e "${GRN}${BOLD}╔══════════════════════════════════════════════════╗${RST}"
echo -e "${GRN}${BOLD}║        BSPWM DESKTOP SETUP COMPLETE             ║${RST}"
echo -e "${GRN}${BOLD}╠══════════════════════════════════════════════════╣${RST}"
echo -e "${GRN}${BOLD}║${RST}  User         : $REALUSER"
echo -e "${GRN}${BOLD}║${RST}  WM           : BSPWM + SXHKD"
echo -e "${GRN}${BOLD}║${RST}  Bar          : Polybar (Nord)"
echo -e "${GRN}${BOLD}║${RST}  Compositor   : Picom (GLX + rounded corners)"
echo -e "${GRN}${BOLD}║${RST}  Terminal     : Alacritty (JetBrainsMono NF)"
echo -e "${GRN}${BOLD}║${RST}  Launcher     : Rofi"
echo -e "${GRN}${BOLD}║${RST}  Notifications: Dunst"
echo -e "${GRN}${BOLD}║${RST}  Audio        : PipeWire + WirePlumber"
echo -e "${GRN}${BOLD}║${RST}  Theme        : Arc-Dark + Papirus-Dark"
echo -e "${GRN}${BOLD}║${RST}  Display Mgr  : LY (enabled)"
echo -e "${GRN}${BOLD}╚══════════════════════════════════════════════════╝${RST}"
echo ""
echo -e "${YLW}${BOLD}Key Bindings (quick ref):${RST}"
echo "  super + Return       → Alacritty"
echo "  super + d            → Rofi (app launcher)"
echo "  super + w            → Rofi (window switcher)"
echo "  super + e            → Thunar"
echo "  super + q            → close window"
echo "  super + f            → fullscreen"
echo "  super + m            → monocle layout"
echo "  super + shift+space  → toggle floating"
echo "  super + 1-0          → switch desktop"
echo "  super + hjkl         → focus (vim keys)"
echo "  super + alt + hjkl   → resize window"
echo "  super + alt + r      → restart bspwm"
echo "  super + alt + q      → quit bspwm"
echo "  Print                → screenshot → ~/Screenshots"
echo "  super + Print        → region screenshot"
echo "  ctrl  + Print        → screenshot → clipboard"
echo ""
echo -e "${CYN}${BOLD}Next steps:${RST}"
echo "  1. Reboot (or: systemctl start ly)"
echo "  2. Log in → BSPWM starts automatically via LY"
echo "  3. Set a wallpaper: feh --bg-fill ~/path/to/image.jpg"
echo "  4. GTK theme:       lxappearance"
echo "  5. Install browser: paru -S firefox  OR  paru -S brave-bin"
echo "  6. Full log:        $LOG_FILE"
echo ""
echo -e "${MAG}If polybar shows missing icons, run: fc-cache -fv${RST}"
echo ""
