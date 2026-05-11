#!/usr/bin/env bash
# =============================================================================
#  install-bspwm.sh — Clean bspwm setup for fresh Arch Linux
#  Run as your normal user (not root). sudo will be invoked where needed.
# =============================================================================

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}${BOLD}[INFO]${RESET}  $*"; }
ok()      { echo -e "${GREEN}${BOLD}[ OK ]${RESET}  $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[WARN]${RESET}  $*"; }
die()     { echo -e "${RED}${BOLD}[ERR ]${RESET}  $*" >&2; exit 1; }
section() { echo -e "\n${BOLD}━━━  $* ${RESET}"; }

# ── Sanity checks ─────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] && die "Do NOT run this script as root. Run as your normal user."
command -v pacman &>/dev/null || die "pacman not found — is this Arch Linux?"

section "Pre-flight checks"
info "User: $USER  |  Home: $HOME"
info "Making sure the system is up to date..."
sudo pacman -Syu --noconfirm
ok "System updated."

# ── Helper: install packages (skip already-installed) ─────────────────────────
pacman_install() {
    local pkgs=("$@")
    local to_install=()
    for p in "${pkgs[@]}"; do
        pacman -Qq "$p" &>/dev/null || to_install+=("$p")
    done
    if [[ ${#to_install[@]} -gt 0 ]]; then
        info "Installing: ${to_install[*]}"
        sudo pacman -S --noconfirm --needed "${to_install[@]}"
    else
        info "All packages already present, skipping."
    fi
}

# ── Helper: install yay (AUR helper) ──────────────────────────────────────────
install_yay() {
    if command -v yay &>/dev/null; then
        ok "yay already installed."
        return
    fi
    info "Installing yay (AUR helper)..."
    pacman_install git base-devel
    local tmp; tmp=$(mktemp -d)
    git clone --depth=1 https://aur.archlinux.org/yay.git "$tmp/yay"
    (cd "$tmp/yay" && makepkg -si --noconfirm)
    rm -rf "$tmp"
    ok "yay installed."
}

# ══════════════════════════════════════════════════════════════════════════════
section "1 · Core packages"
# ══════════════════════════════════════════════════════════════════════════════
CORE_PKGS=(
    # Window manager
    bspwm sxhkd

    # Display server / login
    xorg-server xorg-xinit xorg-xrandr xorg-xsetroot

    # Terminal
    alacritty

    # Status bar
    polybar

    # App launcher
    rofi

    # Compositor (shadows, transparency, fade)
    picom

    # Wallpaper setter
    feh

    # Fonts
    ttf-jetbrains-mono-nerd ttf-font-awesome

    # Notification daemon
    dunst libnotify

    # File manager (CLI)
    ranger

    # Utilities
    xclip xdotool xdo
    brightnessctl playerctl
    pulseaudio pulseaudio-alsa pavucontrol
    networkmanager nm-connection-editor

    # Polkit agent (needed by many GUI apps)
    polkit lxsession

    # Basic apps
    firefox thunar gvfs
)

pacman_install "${CORE_PKGS[@]}"
ok "Core packages installed."

# ══════════════════════════════════════════════════════════════════════════════
section "2 · AUR packages"
# ══════════════════════════════════════════════════════════════════════════════
install_yay
AUR_PKGS=(
    bsp-layout        # dynamic layout addon for bspwm
)
info "Installing AUR packages: ${AUR_PKGS[*]}"
yay -S --noconfirm --needed "${AUR_PKGS[@]}"
ok "AUR packages installed."

# ══════════════════════════════════════════════════════════════════════════════
section "3 · Enable services"
# ══════════════════════════════════════════════════════════════════════════════
sudo systemctl enable NetworkManager
sudo systemctl start  NetworkManager
ok "NetworkManager enabled."

# ══════════════════════════════════════════════════════════════════════════════
section "4 · Config directories"
# ══════════════════════════════════════════════════════════════════════════════
CONFIG="$HOME/.config"
mkdir -p \
    "$CONFIG/bspwm" \
    "$CONFIG/sxhkd" \
    "$CONFIG/polybar" \
    "$CONFIG/picom" \
    "$CONFIG/rofi" \
    "$CONFIG/alacritty" \
    "$CONFIG/dunst" \
    "$HOME/.local/bin"

ok "Config directories created."

# ══════════════════════════════════════════════════════════════════════════════
section "5 · bspwmrc"
# ══════════════════════════════════════════════════════════════════════════════
cat > "$CONFIG/bspwm/bspwmrc" << 'EOF'
#!/usr/bin/env bash
# ── bspwmrc ──────────────────────────────────────────────────────────────────

# Kill & restart sxhkd on reload
pgrep -x sxhkd > /dev/null || sxhkd &

# ── Workspaces ────────────────────────────────────────────────────────────────
bspc monitor -d I II III IV V VI VII VIII IX X

# ── Appearance ────────────────────────────────────────────────────────────────
bspc config border_width         2
bspc config window_gap           10
bspc config split_ratio          0.52
bspc config borderless_monocle   true
bspc config gapless_monocle      true
bspc config focused_border_color  "#89b4fa"   # Catppuccin blue
bspc config normal_border_color   "#313244"
bspc config active_border_color   "#585b70"

# ── Behavior ──────────────────────────────────────────────────────────────────
bspc config click_to_focus        button1
bspc config focus_follows_pointer false
bspc config pointer_follows_focus false
bspc config automatic_scheme      alternate

# ── Rules ─────────────────────────────────────────────────────────────────────
bspc rule -a Gimp                 state=floating follow=on
bspc rule -a Thunar               state=tiling
bspc rule -a "Pavucontrol"        state=floating
bspc rule -a "nm-connection-editor" state=floating
bspc rule -a "Firefox"            desktop='^2'

# ── Autostart ────────────────────────────────────────────────────────────────
# Compositor
picom --config "$HOME/.config/picom/picom.conf" -b

# Status bar
"$HOME/.config/polybar/launch.sh" &

# Wallpaper (replace with your image path or colour)
feh --no-fehbg --bg-fill "$HOME/.config/bspwm/wallpaper.jpg" 2>/dev/null \
    || xsetroot -solid "#1e1e2e"

# Polkit agent
/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 2>/dev/null &
lxpolkit 2>/dev/null &

# Notification daemon
dunst &

# Cursor theme
xsetroot -cursor_name left_ptr

EOF
chmod +x "$CONFIG/bspwm/bspwmrc"
ok "bspwmrc written."

# ══════════════════════════════════════════════════════════════════════════════
section "6 · sxhkdrc (keybindings)"
# ══════════════════════════════════════════════════════════════════════════════
cat > "$CONFIG/sxhkd/sxhkdrc" << 'EOF'
# ── sxhkdrc ──────────────────────────────────────────────────────────────────
# Modifier key: super (Windows key)

# ── WM control ───────────────────────────────────────────────────────────────
# Reload sxhkd
super + Escape
    pkill -USR1 -x sxhkd

# Reload bspwm
super + shift + r
    bspc wm -r

# Quit bspwm
super + shift + q
    bspc quit

# Close / kill focused window
super + {_,shift + }w
    bspc node -{c,k}

# ── Applications ─────────────────────────────────────────────────────────────
super + Return
    alacritty

super + space
    rofi -show drun -show-icons

super + shift + space
    rofi -show run

super + e
    thunar

super + b
    firefox

# Screenshot (requires: scrot)
Print
    scrot '%Y-%m-%d_%H:%M:%S.png' -e 'mv $f ~/Pictures/'

# ── Window state & flags ─────────────────────────────────────────────────────
super + {t,shift + t,s,f}
    bspc node -t {tiled,pseudo_tiled,floating,fullscreen}

super + ctrl + {m,x,y,z}
    bspc node -g {marked,locked,sticky,private}

# ── Focus / swap ─────────────────────────────────────────────────────────────
super + {h,j,k,l}
    bspc node -f {west,south,north,east}

super + shift + {h,j,k,l}
    bspc node -s {west,south,north,east}

# Focus/swap with arrow keys too
super + {Left,Down,Up,Right}
    bspc node -f {west,south,north,east}

# Focus the parent/child node
super + {e,r}
    bspc node -f @{parent,first}

# Focus the next/previous window
super + {_,shift + }c
    bspc node -f {next,prev}.local.!hidden.window

# Focus the next/previous desktop
super + bracket{left,right}
    bspc desktop -f {prev,next}.local

# Focus the last node / desktop
super + {grave,Tab}
    bspc {node,desktop} -f last

# Focus the older/newer node
super + {o,i}
    bspc wm -h off; \
    bspc node {older,newer} -f; \
    bspc wm -h on

# ── Workspaces ───────────────────────────────────────────────────────────────
super + {_,shift + }{1-9,0}
    bspc {desktop -f,node -d} '^{1-9,10}'

# ── Layout ───────────────────────────────────────────────────────────────────
# Rotate tree
super + ctrl + {h,l}
    bspc node @/ -R {270,90}

# Flip
super + ctrl + {j,k}
    bspc node @/ -F {vertical,horizontal}

# Balance / equalise
super + ctrl + {b,shift + b}
    bspc node @/ -{B,E}

# ── Resize (vim-like) ────────────────────────────────────────────────────────
super + alt + {h,j,k,l}
    bspc node -z {left -20 0,bottom 0 20,top 0 -20,right 20 0}

super + alt + shift + {h,j,k,l}
    bspc node -z {right -20 0,top 0 20,bottom 0 -20,left 20 0}

# Move floating window
super + {Left,Down,Up,Right}
    bspc node -v {-20 0,0 20,0 -20,20 0}

# ── Media keys ───────────────────────────────────────────────────────────────
XF86AudioRaiseVolume
    pactl set-sink-volume @DEFAULT_SINK@ +5%
XF86AudioLowerVolume
    pactl set-sink-volume @DEFAULT_SINK@ -5%
XF86AudioMute
    pactl set-sink-mute @DEFAULT_SINK@ toggle

XF86MonBrightnessUp
    brightnessctl set +5%
XF86MonBrightnessDown
    brightnessctl set 5%-

XF86AudioPlay
    playerctl play-pause
XF86AudioNext
    playerctl next
XF86AudioPrev
    playerctl previous

EOF
ok "sxhkdrc written."

# ══════════════════════════════════════════════════════════════════════════════
section "7 · Picom config"
# ══════════════════════════════════════════════════════════════════════════════
cat > "$CONFIG/picom/picom.conf" << 'EOF'
# ── picom.conf ───────────────────────────────────────────────────────────────

backend = "glx";
vsync = true;
glx-no-stencil = true;

# ── Shadows ──────────────────────────────────────────────────────────────────
shadow = true;
shadow-radius = 12;
shadow-offset-x = -7;
shadow-offset-y = -7;
shadow-opacity = 0.6;
shadow-exclude = [
    "name = 'Notification'",
    "class_g = 'Conky'",
    "class_g ?= 'Notify-osd'",
    "_GTK_FRAME_EXTENTS@:c"
];

# ── Fading ───────────────────────────────────────────────────────────────────
fading = true;
fade-in-step = 0.03;
fade-out-step = 0.03;
fade-delta = 4;

# ── Opacity ──────────────────────────────────────────────────────────────────
active-opacity = 1.0;
inactive-opacity = 0.92;
frame-opacity = 1.0;
inactive-opacity-override = false;
opacity-rule = [
    "100:class_g = 'Firefox'",
    "100:class_g = 'vlc'",
    "100:fullscreen"
];

# ── Blur ─────────────────────────────────────────────────────────────────────
blur-background = false;   # set true if you want blur (costs GPU)
blur-method = "dual_kawase";
blur-strength = 5;

# ── Rounded corners ──────────────────────────────────────────────────────────
corner-radius = 8;
rounded-corners-exclude = [
    "window_type = 'dock'",
    "window_type = 'desktop'"
];

EOF
ok "picom.conf written."

# ══════════════════════════════════════════════════════════════════════════════
section "8 · Polybar"
# ══════════════════════════════════════════════════════════════════════════════
cat > "$CONFIG/polybar/launch.sh" << 'EOF'
#!/usr/bin/env bash
# Kill any running bars
killall -q polybar
while pgrep -u "$UID" -x polybar > /dev/null; do sleep 0.1; done

# Launch on every connected monitor
if type "xrandr" > /dev/null 2>&1; then
    for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
        MONITOR=$m polybar --reload main &
    done
else
    polybar --reload main &
fi
EOF
chmod +x "$CONFIG/polybar/launch.sh"

cat > "$CONFIG/polybar/config.ini" << 'EOF'
; ── polybar/config.ini ────────────────────────────────────────────────────────

[colors]
bg       = #1e1e2e
bg-alt   = #313244
fg       = #cdd6f4
fg-dim   = #585b70
blue     = #89b4fa
green    = #a6e3a1
yellow   = #f9e2af
red      = #f38ba8
mauve    = #cba4f7
teal     = #94e2d5

[bar/main]
monitor         = ${env:MONITOR:}
width           = 100%
height          = 28
offset-x        = 0
offset-y        = 0
radius          = 0
fixed-center    = true

background = ${colors.bg}
foreground = ${colors.fg}

line-size   = 2
line-color  = ${colors.blue}

border-size  = 0
padding-left = 1
padding-right = 1
module-margin = 1

font-0 = JetBrainsMono Nerd Font:size=9:weight=bold;2
font-1 = Font Awesome 6 Free:style=Solid:size=9;2
font-2 = Font Awesome 6 Brands:size=9;2

modules-left   = bspwm
modules-center = date
modules-right  = pulseaudio network cpu memory battery

tray-position  = right
tray-padding   = 4

cursor-click  = pointer
cursor-scroll = ns-resize

enable-ipc = true

; ── Modules ───────────────────────────────────────────────────────────────────

[module/bspwm]
type = internal/bspwm
label-focused         = %name%
label-focused-background = ${colors.bg-alt}
label-focused-foreground = ${colors.blue}
label-focused-padding = 2
label-occupied        = %name%
label-occupied-padding = 2
label-urgent          = %name%!
label-urgent-background = ${colors.red}
label-urgent-padding  = 2
label-empty           = %name%
label-empty-foreground = ${colors.fg-dim}
label-empty-padding   = 2

[module/date]
type = internal/date
interval = 1
date = "%a %d %b"
time = "%H:%M"
label = " %date%   %time%"
label-foreground = ${colors.fg}

[module/pulseaudio]
type = internal/pulseaudio
format-volume = <ramp-volume> <label-volume>
label-volume = %percentage%%
label-muted = 婢 muted
label-muted-foreground = ${colors.fg-dim}
ramp-volume-0 = 
ramp-volume-1 = 
ramp-volume-2 = 
click-right = pavucontrol &

[module/network]
type = internal/network
interface-type = any
interval = 2
format-connected    =  <label-connected>
label-connected     = %essid%%{F-} %downspeed:8%  %upspeed:8%
format-disconnected =  disconnected
label-disconnected-foreground = ${colors.fg-dim}

[module/cpu]
type = internal/cpu
interval = 1
format-prefix = " "
format-prefix-foreground = ${colors.mauve}
label = %percentage:2%%

[module/memory]
type = internal/memory
interval = 2
format-prefix = " "
format-prefix-foreground = ${colors.teal}
label = %percentage_used:2%%

[module/battery]
type = internal/battery
battery = BAT0
adapter = ADP1
full-at = 98
format-charging    = <animation-charging> <label-charging>
format-discharging = <ramp-capacity> <label-discharging>
format-full-prefix = " "
format-full-prefix-foreground = ${colors.green}
ramp-capacity-0 = 
ramp-capacity-1 = 
ramp-capacity-2 = 
ramp-capacity-3 = 
ramp-capacity-4 = 
animation-charging-0 = 
animation-charging-1 = 
animation-charging-2 = 
animation-charging-3 = 
animation-charging-4 = 
animation-charging-framerate = 750

EOF
ok "Polybar config written."

# ══════════════════════════════════════════════════════════════════════════════
section "9 · Alacritty"
# ══════════════════════════════════════════════════════════════════════════════
cat > "$CONFIG/alacritty/alacritty.toml" << 'EOF'
# ── alacritty.toml ───────────────────────────────────────────────────────────

[window]
padding = { x = 10, y = 10 }
decorations = "none"
opacity = 0.92
startup_mode = "Windowed"

[font]
normal = { family = "JetBrainsMono Nerd Font", style = "Regular" }
bold   = { family = "JetBrainsMono Nerd Font", style = "Bold" }
size   = 11.0

[colors.primary]
background = "#1e1e2e"
foreground = "#cdd6f4"

[colors.normal]
black   = "#45475a"
red     = "#f38ba8"
green   = "#a6e3a1"
yellow  = "#f9e2af"
blue    = "#89b4fa"
magenta = "#f5c2e7"
cyan    = "#94e2d5"
white   = "#bac2de"

[colors.bright]
black   = "#585b70"
red     = "#f38ba8"
green   = "#a6e3a1"
yellow  = "#f9e2af"
blue    = "#89b4fa"
magenta = "#f5c2e7"
cyan    = "#94e2d5"
white   = "#a6adc8"

[cursor]
style = { shape = "Block", blinking = "On" }

[scrolling]
history = 5000

EOF
ok "Alacritty config written."

# ══════════════════════════════════════════════════════════════════════════════
section "10 · Dunst (notifications)"
# ══════════════════════════════════════════════════════════════════════════════
cat > "$CONFIG/dunst/dunstrc" << 'EOF'
[global]
    monitor                = 0
    follow                 = mouse
    width                  = 300
    height                 = 300
    origin                 = top-right
    offset                 = 10x40
    scale                  = 0
    notification_limit     = 0
    progress_bar           = true
    indicate_hidden        = yes
    transparency           = 5
    separator_height       = 2
    padding                = 8
    horizontal_padding     = 10
    frame_width            = 2
    frame_color            = "#89b4fa"
    separator_color        = frame
    sort                   = yes
    font                   = JetBrainsMono Nerd Font 9
    line_height            = 0
    markup                 = full
    format                 = "<b>%s</b>\n%b"
    alignment              = left
    vertical_alignment     = center
    show_age_threshold     = 60
    ellipsize              = middle
    ignore_newline         = no
    stack_duplicates       = true
    hide_duplicate_count   = false
    show_indicators        = yes
    icon_position          = left
    min_icon_size          = 0
    max_icon_size          = 32
    sticky_history         = yes
    history_length         = 20
    browser                = /usr/bin/firefox
    always_run_script      = true
    title                  = Dunst
    class                  = Dunst
    corner_radius          = 8
    ignore_dbusclose       = false
    mouse_left_click       = close_current
    mouse_middle_click     = do_action, close_current
    mouse_right_click      = close_all

[urgency_low]
    background             = "#1e1e2e"
    foreground             = "#cdd6f4"
    timeout                = 5

[urgency_normal]
    background             = "#1e1e2e"
    foreground             = "#cdd6f4"
    timeout                = 8

[urgency_critical]
    background             = "#f38ba8"
    foreground             = "#1e1e2e"
    frame_color            = "#f38ba8"
    timeout                = 0

EOF
ok "dunstrc written."

# ══════════════════════════════════════════════════════════════════════════════
section "11 · Rofi theme"
# ══════════════════════════════════════════════════════════════════════════════
cat > "$CONFIG/rofi/config.rasi" << 'EOF'
configuration {
    modi:            "drun,run,window";
    show-icons:      true;
    terminal:        "alacritty";
    drun-display-format: "{name}";
    font:            "JetBrainsMono Nerd Font 10";
}

@theme "/dev/null"

* {
    bg:     #1e1e2e;
    bg-alt: #313244;
    fg:     #cdd6f4;
    sel:    #89b4fa;
    urg:    #f38ba8;

    background-color: transparent;
    text-color:       @fg;
    border-color:     @sel;
}

window {
    background-color: @bg;
    border:           2px;
    border-color:     @sel;
    border-radius:    10px;
    width:            36%;
    padding:          10px;
}

mainbox  { spacing: 0; }
message  { padding: 4px; }
textbox  { text-color: @fg; }
listview { border: 0; lines: 8; }

inputbar {
    background-color: @bg-alt;
    border-radius:    6px;
    padding:          8px;
    margin:           0 0 8px 0;
    children:         [prompt, entry];
}

prompt {
    text-color: @sel;
    padding:    0 6px 0 0;
}

element {
    padding:      6px 8px;
    border-radius: 6px;
}

element selected {
    background-color: @sel;
    text-color:       @bg;
}

EOF
ok "Rofi config written."

# ══════════════════════════════════════════════════════════════════════════════
section "12 · .xinitrc"
# ══════════════════════════════════════════════════════════════════════════════
XINITRC="$HOME/.xinitrc"
if [[ -f "$XINITRC" ]]; then
    cp "$XINITRC" "${XINITRC}.bak"
    warn "Existing .xinitrc backed up to ${XINITRC}.bak"
fi

cat > "$XINITRC" << 'EOF'
#!/bin/sh
# ── .xinitrc ─────────────────────────────────────────────────────────────────

# Input: set your keyboard layout (change 'us' if needed)
setxkbmap us

# Increase key repeat rate
xset r rate 300 50

# Fix Java GUIs in non-reparenting WMs
export _JAVA_AWT_WM_NONREPARENTING=1

exec bspwm
EOF
ok ".xinitrc written."

# ══════════════════════════════════════════════════════════════════════════════
section "13 · Shell shortcut"
# ══════════════════════════════════════════════════════════════════════════════
PROFILE="$HOME/.bash_profile"
if ! grep -q "startx" "$PROFILE" 2>/dev/null; then
    cat >> "$PROFILE" << 'EOF'

# Auto-start X on TTY1 login
if [[ -z "$DISPLAY" ]] && [[ "$(tty)" = "/dev/tty1" ]]; then
    exec startx
fi
EOF
    ok "Auto-startx on TTY1 added to ~/.bash_profile"
else
    warn "Auto-startx already in ~/.bash_profile, skipping."
fi

# ══════════════════════════════════════════════════════════════════════════════
section "14 · Pictures directory for screenshots"
# ══════════════════════════════════════════════════════════════════════════════
mkdir -p "$HOME/Pictures"

# Optional: install scrot for screenshots
if ! pacman -Qq scrot &>/dev/null; then
    info "Installing scrot (screenshot tool)..."
    sudo pacman -S --noconfirm --needed scrot
fi
ok "scrot installed."

# ══════════════════════════════════════════════════════════════════════════════
section "✔  Installation complete!"
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}Summary of what was set up:${RESET}"
echo "  • bspwm + sxhkd       window manager & hotkey daemon"
echo "  • Polybar              status bar (Catppuccin Mocha theme)"
echo "  • Picom                compositor (shadows, fading, rounded corners)"
echo "  • Rofi                 app launcher"
echo "  • Alacritty            terminal (JetBrainsMono Nerd Font)"
echo "  • Dunst                notifications"
echo "  • Thunar / Ranger      GUI & CLI file managers"
echo "  • NetworkManager       networking"
echo "  • PulseAudio           audio"
echo ""
echo -e "${BOLD}Quick key reference:${RESET}"
echo "  super + Enter          → terminal"
echo "  super + Space          → app launcher (rofi drun)"
echo "  super + w              → close window"
echo "  super + {h,j,k,l}     → focus direction"
echo "  super + {1-9}          → switch workspace"
echo "  super + shift + {1-9}  → move window to workspace"
echo "  super + f              → fullscreen"
echo "  super + s              → floating"
echo "  super + t              → tile"
echo "  super + shift + r      → reload bspwm"
echo "  super + shift + q      → quit bspwm"
echo ""
echo -e "${YELLOW}${BOLD}Next steps:${RESET}"
echo "  1. Place a wallpaper at ~/.config/bspwm/wallpaper.jpg"
echo "     (or edit bspwmrc to point to your image)"
echo "  2. Log out and log back in, then run:  startx"
echo "     (or reboot — TTY1 login will auto-start X)"
echo "  3. Adjust ~/.config/polybar/config.ini battery interface"
echo "     if needed (check: ls /sys/class/power_supply/)"
echo ""
ok "Enjoy your bspwm setup! 🎉"
