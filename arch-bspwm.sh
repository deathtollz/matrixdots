#!/usr/bin/env bash
# =============================================================================
#  arch-bspwm-setup.sh  —  Hacker BSPWM Desktop for Arch Linux
#  Replicates: bspwm · sxhkd · Polybar (crypto/sysinfo) · alacritty ·
#              green-on-black theme · cava · cmatrix · neofetch · oh-my-zsh
# =============================================================================
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${GREEN}[+]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[✗]${NC} $*"; exit 1; }
section() { echo -e "\n${CYAN}══════════════════════════════════════════════${NC}"; \
            echo -e "${CYAN}  $*${NC}"; \
            echo -e "${CYAN}══════════════════════════════════════════════${NC}"; }

[[ $EUID -eq 0 ]] && error "Do NOT run as root. Run as your normal user (sudo access required)."

DOTDIR="$HOME/.config"
mkdir -p "$DOTDIR"

# ─── 1. PACMAN SETUP ──────────────────────────────────────────────────────────
section "SYSTEM UPDATE"
info "Updating system..."
sudo pacman -Syu --noconfirm --needed

info "Installing base dependencies..."
sudo pacman -S --noconfirm --needed \
  base-devel git curl wget unzip \
  xorg xorg-xinit xorg-xrandr xorg-xsetroot xdotool \
  bspwm sxhkd \
  polybar \
  alacritty \
  zsh \
  neofetch htop \
  cava \
  feh picom rofi dunst \
  ttf-font-awesome \
  nerd-fonts \
  lm_sensors net-tools iproute2 \
  jq bc \
  imagemagick \
  scrot \
  python python-pip \
  gtk3 papirus-icon-theme \
  xdg-utils \
  2>/dev/null || warn "Some pacman packages may have failed — continuing."

# ─── 2. YAY (AUR HELPER) ──────────────────────────────────────────────────────
section "AUR HELPER (yay)"
if ! command -v yay &>/dev/null; then
  info "Installing yay AUR helper..."
  git clone --depth=1 https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
  (cd /tmp/yay-bin && makepkg -si --noconfirm)
  rm -rf /tmp/yay-bin
else
  info "yay already installed."
fi

# ─── 3. AUR PACKAGES ──────────────────────────────────────────────────────────
section "AUR PACKAGES"
info "Installing AUR packages (cmatrix, bspwm extras)..."
yay -S --noconfirm --needed \
  cmatrix \
  bspwm-rounded-corners \
  xtitle \
  2>/dev/null || {
    warn "Some AUR packages failed. Trying plain cmatrix from community..."
    sudo pacman -S --noconfirm --needed cmatrix 2>/dev/null || warn "cmatrix unavailable."
  }

# ─── 4. IOSEVKA NERD FONT ─────────────────────────────────────────────────────
section "FONTS"
info "Checking for Iosevka Nerd Font..."
if ! fc-list | grep -qi "iosevka"; then
  info "Installing Iosevka Nerd Font from releases..."
  FONT_DIR="$HOME/.local/share/fonts/IosevkaNerd"
  mkdir -p "$FONT_DIR"
  FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/Iosevka.zip"
  wget -q --show-progress -O /tmp/Iosevka.zip "$FONT_URL"
  unzip -q /tmp/Iosevka.zip -d "$FONT_DIR" || true
  rm -f /tmp/Iosevka.zip
  fc-cache -fv "$HOME/.local/share/fonts" > /dev/null 2>&1
  info "Iosevka Nerd Font installed."
else
  info "Iosevka Nerd Font already present."
fi

# ─── 5. OH-MY-ZSH ─────────────────────────────────────────────────────────────
section "ZSH + OH-MY-ZSH"
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  info "Installing oh-my-zsh..."
  RUNZSH=no CHSH=no sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  info "oh-my-zsh already installed."
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

[[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]] && \
  git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git \
  "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

[[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]] && \
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git \
  "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

[[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]] && \
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
  "$ZSH_CUSTOM/themes/powerlevel10k"

sudo chsh -s "$(which zsh)" "$USER" 2>/dev/null || \
  warn "Could not auto-change shell. Run manually: chsh -s \$(which zsh)"

# ─── 6. .ZSHRC ────────────────────────────────────────────────────────────────
info "Writing .zshrc..."
cat > "$HOME/.zshrc" << 'ZSHRC'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Powerlevel10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

plugins=(git zsh-syntax-highlighting zsh-autosuggestions sudo history)
source $ZSH/oh-my-zsh.sh

export TERM=xterm-256color
export CLICOLOR=1
export LS_COLORS='di=1;32:fi=0;32:ln=1;36:ex=1;31:'

alias ls='ls --color=always'
alias ll='ls -lah --color=always'
alias grep='grep --color=always'
alias cls='clear && neofetch'
alias bspwm-reload='~/.config/bspwm/bspwmrc && pkill -USR1 sxhkd'

# Auto neofetch
neofetch

[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
ZSHRC

# ─── 7. ALACRITTY ─────────────────────────────────────────────────────────────
section "TERMINAL"
info "Configuring alacritty..."
mkdir -p "$DOTDIR/alacritty"
cat > "$DOTDIR/alacritty/alacritty.toml" << 'ALACRITTY'
[window]
padding          = { x = 10, y = 8 }
decorations      = "none"
opacity          = 0.88
dynamic_title    = true
startup_mode     = "Windowed"

[scrolling]
history = 10000

[font]
normal = { family = "IosevkaNFM", style = "Regular" }
bold   = { family = "IosevkaNFM", style = "Bold" }
italic = { family = "IosevkaNFM", style = "Italic" }
size   = 10.5

[colors.primary]
background = "#080808"
foreground = "#00ff41"

[colors.cursor]
text   = "#000000"
cursor = "#00ff41"

[colors.selection]
text       = "#000000"
background = "#00aa33"

[colors.normal]
black   = "#080808"
red     = "#ff2222"
green   = "#00ff41"
yellow  = "#ffff00"
blue    = "#0088ff"
magenta = "#ff00ff"
cyan    = "#00ffff"
white   = "#aaffaa"

[colors.bright]
black   = "#2a2a2a"
red     = "#ff5555"
green   = "#55ff77"
yellow  = "#ffff55"
blue    = "#5599ff"
magenta = "#ff55ff"
cyan    = "#55ffff"
white   = "#ccffcc"

[cursor]
style = { shape = "Block", blinking = "On" }

[bell]
duration = 0
ALACRITTY

# ─── 8. BSPWM CONFIG ──────────────────────────────────────────────────────────
section "BSPWM"
info "Writing bspwm config..."
mkdir -p "$DOTDIR/bspwm"
cat > "$DOTDIR/bspwm/bspwmrc" << 'BSPWMRC'
#!/usr/bin/env bash
# ══════════════════════════════════════════════════════
#  BSPWMRC — hacker green theme
# ══════════════════════════════════════════════════════

# Kill & restart sxhkd on reload
pgrep -x sxhkd > /dev/null || sxhkd &

# ── Workspaces ──────────────────────────────────────
bspc monitor -d 1 2 3 4 5 6 7 8 9 10

# ── Global Settings ─────────────────────────────────
bspc config border_width          2
bspc config window_gap            10
bspc config split_ratio           0.52
bspc config borderless_monocle    true
bspc config gapless_monocle       false
bspc config focus_follows_pointer true
bspc config pointer_follows_focus false
bspc config automatic_scheme      alternate

# ── Colors ──────────────────────────────────────────
bspc config normal_border_color   "#1a331a"
bspc config active_border_color   "#00aa33"
bspc config focused_border_color  "#00ff41"
bspc config presel_feedback_color "#004411"

# ── Padding (room for polybar) ───────────────────────
bspc config top_padding    22
bspc config bottom_padding 0
bspc config left_padding   0
bspc config right_padding  0

# ── Floating Rules ───────────────────────────────────
bspc rule -a Pavucontrol    state=floating
bspc rule -a Nitrogen       state=floating
bspc rule -a feh            state=floating
bspc rule -a "Alacritty:float" state=floating

# ── Startup ──────────────────────────────────────────
pkill -x picom 2>/dev/null; sleep 0.3
picom --config "$HOME/.config/picom/picom.conf" -b &

pkill -x polybar 2>/dev/null; sleep 0.3
"$HOME/.config/polybar/launch.sh" &

feh --bg-scale "$HOME/.config/bspwm/wallpaper.jpg" &

dunst &

# Fix cursor
xsetroot -cursor_name left_ptr &
BSPWMRC
chmod +x "$DOTDIR/bspwm/bspwmrc"

# ─── 9. SXHKD (keybindings) ───────────────────────────────────────────────────
info "Writing sxhkd keybindings..."
mkdir -p "$DOTDIR/sxhkd"
cat > "$DOTDIR/sxhkd/sxhkdrc" << 'SXHKD'
# ══════════════════════════════════════════════════════
#  SXHKDRC — keybindings for bspwm
# ══════════════════════════════════════════════════════

# ── Essentials ───────────────────────────────────────
# Terminal
super + Return
    alacritty

# App launcher
super + d
    rofi -show drun

# Kill window
super + shift + q
    bspc node -c

# Reload sxhkd
super + Escape
    pkill -USR1 -x sxhkd

# Reload bspwm
super + shift + r
    bspc wm -r

# Logout
super + shift + e
    bspc quit

# ── Quick Apps ───────────────────────────────────────
super + ctrl + m
    alacritty -e cmatrix -C green

super + ctrl + v
    alacritty -e cava

super + ctrl + h
    alacritty -e htop

super + ctrl + n
    alacritty --title "float" -e neofetch

# Screenshot (full)
Print
    scrot ~/Pictures/screenshot_%Y%m%d_%H%M%S.png

# Screenshot (select region)
super + Print
    scrot -s ~/Pictures/screenshot_%Y%m%d_%H%M%S.png

# ── Focus / Swap ──────────────────────────────────────
super + {h,j,k,l}
    bspc node -f {west,south,north,east}

super + shift + {h,j,k,l}
    bspc node -s {west,south,north,east}

# Cycle focus
super + {_,shift + }Tab
    bspc node -f {next,prev}.local.!hidden.window

# ── Preselect ────────────────────────────────────────
super + ctrl + {h,j,k,l}
    bspc node -p {west,south,north,east}

super + ctrl + space
    bspc node -p cancel

# ── Move & Resize ─────────────────────────────────────
super + alt + {h,j,k,l}
    bspc node -z {left -20 0,bottom 0 20,top 0 -20,right 20 0}

super + alt + shift + {h,j,k,l}
    bspc node -z {right -20 0,top 0 20,bottom 0 -20,left 20 0}

# Floating move (arrow keys)
super + {Left,Down,Up,Right}
    bspc node -v {-20 0,0 20,0 -20,20 0}

# ── Layout / State ────────────────────────────────────
super + f
    bspc node -t fullscreen

super + shift + f
    bspc node -t floating

super + t
    bspc node -t tiled

super + m
    bspc desktop -l next

# ── Workspaces ───────────────────────────────────────
super + {1-9,0}
    bspc desktop -f '^{1-9,10}'

super + shift + {1-9,0}
    bspc node -d '^{1-9,10}' --follow

# ── Volume ───────────────────────────────────────────
XF86AudioRaiseVolume
    pactl set-sink-volume @DEFAULT_SINK@ +5%

XF86AudioLowerVolume
    pactl set-sink-volume @DEFAULT_SINK@ -5%

XF86AudioMute
    pactl set-sink-mute @DEFAULT_SINK@ toggle
SXHKD

# ─── 10. POLYBAR ──────────────────────────────────────────────────────────────
section "POLYBAR"
info "Configuring polybar..."
mkdir -p "$DOTDIR/polybar"

cat > "$DOTDIR/polybar/launch.sh" << 'LAUNCH'
#!/usr/bin/env bash
killall -q polybar 2>/dev/null || true
while pgrep -u "$UID" -x polybar > /dev/null; do sleep 0.3; done

# Multi-monitor support
if type "xrandr" > /dev/null 2>&1; then
  for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
    MONITOR=$m polybar --reload main 2>&1 | tee -a /tmp/polybar-"$m".log & disown
  done
else
  polybar --reload main 2>&1 | tee -a /tmp/polybar-main.log & disown
fi
LAUNCH
chmod +x "$DOTDIR/polybar/launch.sh"

cat > "$DOTDIR/polybar/crypto.sh" << 'CRYPTO'
#!/usr/bin/env bash
COIN="${1:-BTC}"
PRICE=$(curl -sf "https://api.coinbase.com/v2/prices/${COIN}-USD/spot" 2>/dev/null | \
        jq -r '.data.amount' 2>/dev/null | xargs printf "%.0f" 2>/dev/null)
[[ -z "$PRICE" ]] && echo "${COIN} N/A" && exit 0
echo "${COIN} \$${PRICE}"
CRYPTO
chmod +x "$DOTDIR/polybar/crypto.sh"

cat > "$DOTDIR/polybar/firewall.sh" << 'FW'
#!/usr/bin/env bash
# Check both ufw and iptables
if command -v ufw &>/dev/null && sudo ufw status 2>/dev/null | grep -q "Status: active"; then
  echo " FW ON"
elif sudo iptables -L INPUT 2>/dev/null | grep -q "DROP\|REJECT"; then
  echo " FW ON"
else
  echo " FW OFF"
fi
FW
chmod +x "$DOTDIR/polybar/firewall.sh"

cat > "$DOTDIR/polybar/bspwm-desktops.sh" << 'DESKTOPS'
#!/usr/bin/env bash
# Show bspwm desktop status for polybar
focused=$(bspc query -D -d focused --names)
for d in $(bspc query -D --names); do
  occupied=$(bspc query -N -d "$d" 2>/dev/null | head -1)
  if [[ "$d" == "$focused" ]]; then
    echo -n "%{F#00ff41}%{+u}$d%{-u}%{F-} "
  elif [[ -n "$occupied" ]]; then
    echo -n "%{F#00aa33}$d%{F-} "
  else
    echo -n "%{F#224422}$d%{F-} "
  fi
done
DESKTOPS
chmod +x "$DOTDIR/polybar/bspwm-desktops.sh"

cat > "$DOTDIR/polybar/config.ini" << 'POLYBAR'
; ══════════════════════════════════════════════════════
;  POLYBAR CONFIG — bspwm / hacker green theme
; ══════════════════════════════════════════════════════

[colors]
bg         = #dd080808
fg         = #00ff41
green      = #00ff41
green-dim  = #00aa33
green-dark = #224422
red        = #ff2222
yellow     = #ffff00
cyan       = #00ffff
dim        = #335533
sep        = #1a331a

[bar/main]
monitor              = ${env:MONITOR:}
width                = 100%
height               = 22
offset-x             = 0
offset-y             = 0
radius               = 0
fixed-center         = true
background           = ${colors.bg}
foreground           = ${colors.fg}
line-size            = 1
line-color           = ${colors.green}
border-size          = 0
padding-left         = 1
padding-right        = 1
module-margin-left   = 1
module-margin-right  = 1
font-0               = IosevkaNFM:size=9;2
font-1               = Font Awesome 6 Free:size=9;2
font-2               = Font Awesome 6 Brands:size=9;2
font-3               = IosevkaNFM:size=7;1
separator            = |
separator-foreground = ${colors.sep}
modules-left         = desktops title
modules-center       = btc bch eth
modules-right        = cpu ram disk net-in net-out firewall ip weather date
wm-restack           = bspwm
override-redirect    = true
cursor-click         = pointer
enable-ipc           = true
tray-position        = none

; ── Desktop Indicator ────────────────────────────────
[module/desktops]
type = custom/script
exec = ~/.config/polybar/bspwm-desktops.sh
interval = 1
format = <label>
label = %output%
format-foreground = ${colors.green}

[module/title]
type = internal/xwindow
label = %title:0:40:...%
label-foreground = ${colors.green-dim}
format-padding = 1

; ── Crypto ──────────────────────────────────────────
[module/btc]
type = custom/script
exec = ~/.config/polybar/crypto.sh BTC
interval = 120
format-prefix = " "
format-prefix-foreground = ${colors.yellow}
format-foreground = ${colors.fg}

[module/bch]
type = custom/script
exec = ~/.config/polybar/crypto.sh BCH
interval = 120
format-prefix = " "
format-prefix-foreground = ${colors.green-dim}
format-foreground = ${colors.fg}

[module/eth]
type = custom/script
exec = ~/.config/polybar/crypto.sh ETH
interval = 120
format-prefix = "Ξ "
format-prefix-foreground = ${colors.cyan}
format-foreground = ${colors.fg}

; ── System ──────────────────────────────────────────
[module/cpu]
type = internal/cpu
interval = 2
format-prefix = " CPU "
format-prefix-foreground = ${colors.green-dim}
label = %percentage%%

[module/ram]
type = internal/memory
interval = 2
format-prefix = " RAM "
format-prefix-foreground = ${colors.green-dim}
label = %used%

[module/disk]
type = internal/fs
mount-0 = /
interval = 30
format-prefix = " Disk "
format-prefix-foreground = ${colors.green-dim}
label-mounted = %used%

[module/net-in]
type = internal/network
interface-type = wired
interval = 2
format-connected = <label-connected>
format-connected-prefix = " IN "
format-connected-prefix-foreground = ${colors.green-dim}
label-connected = %downspeed%

[module/net-out]
type = internal/network
interface-type = wired
interval = 2
format-connected = <label-connected>
format-connected-prefix = "OUT "
format-connected-prefix-foreground = ${colors.green-dim}
label-connected = %upspeed%

[module/firewall]
type = custom/script
exec = ~/.config/polybar/firewall.sh
interval = 30
format-foreground = ${colors.green}

[module/ip]
type = custom/script
exec = ip route get 1 2>/dev/null | awk '{print $7; exit}' || echo "N/A"
interval = 60
format-prefix = " "
format-prefix-foreground = ${colors.green-dim}
format-foreground = ${colors.fg}

[module/weather]
type = custom/script
exec = curl -sf "wttr.in/?format=%c%t" 2>/dev/null | tr -d '+' || echo "N/A"
interval = 1800
format-foreground = ${colors.fg}

[module/date]
type = internal/date
interval = 1
date  = %A, %d %B %Y
time  = %H:%M:%S
label = %date%  %time%
format-foreground = ${colors.fg}
POLYBAR

# ─── 11. PICOM ────────────────────────────────────────────────────────────────
section "COMPOSITOR"
info "Configuring picom..."
mkdir -p "$DOTDIR/picom"
cat > "$DOTDIR/picom/picom.conf" << 'PICOM'
# ══════════════════════════════════════════════════════
#  PICOM — compositor config for bspwm
# ══════════════════════════════════════════════════════
backend = "glx";
glx-no-stencil = true;
vsync = true;

# Shadows
shadow = true;
shadow-radius = 16;
shadow-offset-x = -16;
shadow-offset-y = -16;
shadow-opacity = 0.5;
shadow-color = "#000000";
shadow-exclude = [
  "class_g = 'Polybar'",
  "class_g = 'Dunst'",
  "_NET_WM_STATE@:32a *= '_NET_WM_STATE_HIDDEN'"
];

# Fading
fading = true;
fade-in-step  = 0.04;
fade-out-step = 0.04;
fade-delta    = 4;

# Transparency
inactive-opacity         = 0.82;
active-opacity           = 0.95;
frame-opacity            = 1.0;
inactive-opacity-override = false;
opacity-rule = [
  "100:class_g = 'Polybar'",
  "90:class_g  = 'Alacritty'",
  "100:fullscreen"
];

# Blur
blur-method          = "dual_kawase";
blur-strength        = 6;
blur-background      = true;
blur-background-exclude = [
  "class_g = 'Polybar'",
  "class_g = 'Dunst'"
];

# Corners (requires picom with rounded corners patch)
corner-radius = 6;
rounded-corners-exclude = [
  "class_g = 'Polybar'"
];
PICOM

# ─── 12. ROFI ─────────────────────────────────────────────────────────────────
section "LAUNCHER"
info "Configuring rofi..."
mkdir -p "$DOTDIR/rofi"
cat > "$DOTDIR/rofi/config.rasi" << 'ROFI'
configuration {
  modi:        "drun,run,window,ssh";
  show-icons:  true;
  icon-theme:  "Papirus-Dark";
  font:        "IosevkaNFM 11";
  drun-display-format: "{name}";
  display-drun: "  Apps";
  display-run:  "  Run";
  display-ssh:  "  SSH";
}

* {
  bg0:    #080808ee;
  bg1:    #0d200dee;
  accent: #00aa33;
  fg0:    #00ff41;
  fg1:    #006622;
  urgent: #ff2222;
  background-color: transparent;
  text-color:       @fg0;
  border-color:     @accent;
}

window {
  background-color: @bg0;
  border:           2px solid;
  border-color:     @accent;
  border-radius:    4px;
  width:            42%;
  padding:          0;
}

mainbox { background-color: transparent; padding: 0; }

inputbar {
  background-color: @bg1;
  padding: 10px 14px;
  border-bottom: 1px solid @accent;
  children: [prompt, entry];
}

prompt {
  text-color:      @accent;
  padding:         0 8px 0 0;
}

entry {
  text-color:      @fg0;
  placeholder:     "type to search...";
  placeholder-color: @fg1;
}

listview {
  background-color: transparent;
  lines:   10;
  columns: 1;
  padding: 6px 4px;
  scrollbar: false;
}

element {
  padding:          6px 12px;
  background-color: transparent;
}
element selected {
  background-color: @accent;
  text-color:       #000000;
  border-radius:    2px;
}
element-text { text-color: inherit; }
element-icon { size: 16px; padding: 0 8px 0 0; }
ROFI

# ─── 13. DUNST (notifications) ────────────────────────────────────────────────
section "NOTIFICATIONS"
info "Configuring dunst..."
mkdir -p "$DOTDIR/dunst"
cat > "$DOTDIR/dunst/dunstrc" << 'DUNST'
[global]
    monitor         = 0
    follow          = mouse
    geometry        = "320x5-12+40"
    indicate_hidden = yes
    shrink          = no
    transparency    = 10
    notification_height = 0
    separator_height = 2
    padding          = 10
    horizontal_padding = 12
    frame_width      = 2
    frame_color      = "#00aa33"
    separator_color  = "#224422"
    sort             = yes
    idle_threshold   = 120
    font             = IosevkaNFM 9
    line_height      = 0
    markup           = full
    format           = "<b>%s</b>\n%b"
    alignment        = left
    show_age_threshold = 60
    word_wrap        = yes
    ignore_newline   = no
    stack_duplicates = true
    hide_duplicate_count = false
    show_indicators  = yes
    icon_position    = left
    max_icon_size    = 32
    sticky_history   = yes
    history_length   = 20
    browser          = firefox
    always_run_script = true
    title            = Dunst
    class            = Dunst

[urgency_low]
    background = "#0a0a0a"
    foreground = "#00ff41"
    timeout    = 5

[urgency_normal]
    background = "#0a0a0a"
    foreground = "#00ff41"
    timeout    = 8

[urgency_critical]
    background = "#0a0a0a"
    foreground = "#ff2222"
    frame_color = "#ff2222"
    timeout    = 0
DUNST

# ─── 14. NEOFETCH ─────────────────────────────────────────────────────────────
section "NEOFETCH"
info "Configuring neofetch..."
mkdir -p "$DOTDIR/neofetch"
cat > "$DOTDIR/neofetch/config.conf" << 'NEOFETCH'
print_info() {
    info title
    info underline
    info "OS"         distro
    info "Host"       model
    info "Kernel"     kernel
    info "Uptime"     uptime
    info "Packages"   packages
    info "Shell"      shell
    info "Resolution" resolution
    info "WM"         wm
    info "Terminal"   term
    info "Terminal Font" term_font
    info "CPU"        cpu
    info "GPU"        gpu
    info "Memory"     memory
    info cols
}
kernel_shorthand="on"
distro_shorthand="off"
os_arch="on"
uptime_shorthand="tiny"
memory_percent="on"
memory_unit="mib"
package_managers="on"
shell_path="off"
shell_version="on"
cpu_brand="on"
cpu_speed="on"
cpu_cores="logical"
cpu_temp="off"
gpu_brand="on"
gpu_type="all"
colors=(distro)
bold="on"
underline_enabled="on"
underline_char="-"
separator=":"
color_blocks="on"
block_range=(0 15)
block_width=3
block_height=1
ascii_distro="arch"
ascii_colors=(6 6)
ascii_bold="on"
image_backend="ascii"
NEOFETCH

# ─── 15. CAVA ─────────────────────────────────────────────────────────────────
section "AUDIO VISUALIZER"
info "Configuring cava..."
mkdir -p "$DOTDIR/cava"
cat > "$DOTDIR/cava/config" << 'CAVA'
[general]
mode       = normal
framerate  = 60
autosens   = 1
bars       = 50
bar_width  = 2
bar_spacing = 1

[input]
method = pulse
source = auto

[output]
method   = ncurses
channels = mono

[color]
gradient         = 1
gradient_count   = 4
gradient_color_1 = '#001500'
gradient_color_2 = '#006600'
gradient_color_3 = '#00cc44'
gradient_color_4 = '#00ff41'

[smoothing]
monstercat  = 1
waves       = 0
noise_reduction = 77
CAVA

# ─── 16. WALLPAPER ────────────────────────────────────────────────────────────
section "WALLPAPER"
info "Downloading wallpaper..."
mkdir -p "$DOTDIR/bspwm"
wget -q --show-progress \
  "https://raw.githubusercontent.com/terroo/wallpapers/main/images/20.jpg" \
  -O "$DOTDIR/bspwm/wallpaper.jpg" 2>/dev/null || {
  if command -v convert &>/dev/null; then
    convert -size 1920x1080 \
      -define gradient:vector="0,0 1920,1080" \
      gradient:"#000000-#001a00" \
      "$DOTDIR/bspwm/wallpaper.jpg"
    warn "Downloaded wallpaper failed; generated gradient fallback."
  else
    warn "Could not download wallpaper. Place your own at ~/.config/bspwm/wallpaper.jpg"
  fi
}

# ─── 17. GTK DARK THEME ───────────────────────────────────────────────────────
section "GTK THEME"
info "Setting dark GTK theme..."
mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
for d in "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"; do
cat > "$d/settings.ini" << 'GTK'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=IosevkaNFM 10
gtk-cursor-theme-name=Adwaita
gtk-application-prefer-dark-theme=1
GTK
done

# ─── 18. .XINITRC ─────────────────────────────────────────────────────────────
section "XINIT"
info "Writing .xinitrc..."
cat > "$HOME/.xinitrc" << 'XINITRC'
#!/bin/sh
# Compositor pre-start cleanup
pkill picom 2>/dev/null; sleep 0.2

# DPI / display setup
xrandr --dpi 96

# Keyboard tweaks
setxkbmap -option caps:escape
xset b off
xset m 0 0

# Start sxhkd before bspwm
sxhkd &

# Start bspwm
exec bspwm
XINITRC
chmod +x "$HOME/.xinitrc"

# ─── 19. DISPLAY MANAGER CHECK ────────────────────────────────────────────────
section "DISPLAY MANAGER"
if systemctl is-active --quiet gdm || systemctl is-active --quiet sddm || \
   systemctl is-active --quiet lightdm; then
  warn "A display manager is running. After reboot, select 'bspwm' from the session menu."
  # Create .desktop entry for session choosers
  sudo mkdir -p /usr/share/xsessions
  sudo tee /usr/share/xsessions/bspwm.desktop > /dev/null << 'DESKTOP'
[Desktop Entry]
Name=bspwm
Comment=Binary Space Partitioning Window Manager
Exec=bspwm
Type=XSession
DESKTOP
  info "bspwm.desktop created for display manager."
else
  info "No display manager active. Start your session with: startx"
fi

# ─── DONE ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       ARCH LINUX BSPWM HACKER SETUP — COMPLETE           ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  Reboot or restart session, then select bspwm.           ║${NC}"
echo -e "${GREEN}║                                                          ║${NC}"
echo -e "${GREEN}║  KEYBINDS (Super = Win key)                              ║${NC}"
echo -e "${GREEN}║  Super+Enter          → Alacritty terminal               ║${NC}"
echo -e "${GREEN}║  Super+D              → Rofi app launcher                ║${NC}"
echo -e "${GREEN}║  Super+Shift+Q        → Close window                     ║${NC}"
echo -e "${GREEN}║  Super+H/J/K/L        → Focus west/south/north/east      ║${NC}"
echo -e "${GREEN}║  Super+Shift+H/J/K/L  → Swap windows                    ║${NC}"
echo -e "${GREEN}║  Super+Ctrl+H/J/K/L   → Preselect split direction        ║${NC}"
echo -e "${GREEN}║  Super+F              → Fullscreen                       ║${NC}"
echo -e "${GREEN}║  Super+Shift+F        → Toggle floating                  ║${NC}"
echo -e "${GREEN}║  Super+M              → Monocle layout toggle            ║${NC}"
echo -e "${GREEN}║  Super+1..0           → Switch to workspace 1-10         ║${NC}"
echo -e "${GREEN}║  Super+Shift+1..0     → Move window to workspace         ║${NC}"
echo -e "${GREEN}║  Super+Alt+H/J/K/L    → Resize window                   ║${NC}"
echo -e "${GREEN}║  Super+Ctrl+M         → cmatrix (matrix rain)            ║${NC}"
echo -e "${GREEN}║  Super+Ctrl+V         → cava (audio visualizer)          ║${NC}"
echo -e "${GREEN}║  Super+Ctrl+H         → htop                             ║${NC}"
echo -e "${GREEN}║  Super+Ctrl+N         → neofetch                         ║${NC}"
echo -e "${GREEN}║  Print                → Screenshot                       ║${NC}"
echo -e "${GREEN}║                                                          ║${NC}"
echo -e "${GREEN}║  Config files:                                           ║${NC}"
echo -e "${GREEN}║  ~/.config/bspwm/bspwmrc    ← bspwm settings            ║${NC}"
echo -e "${GREEN}║  ~/.config/sxhkd/sxhkdrc   ← all keybindings            ║${NC}"
echo -e "${GREEN}║  ~/.config/polybar/config.ini ← bar config              ║${NC}"
echo -e "${GREEN}║  ~/.config/alacritty/alacritty.toml ← terminal          ║${NC}"
echo -e "${GREEN}║  ~/.config/bspwm/wallpaper.jpg ← replace wallpaper      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
