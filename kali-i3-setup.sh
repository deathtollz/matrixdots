#!/usr/bin/env bash
# =============================================================================
#  kali-i3-setup.sh  —  Hacker i3 Desktop for Kali Linux
#  Replicates: i3wm · Polybar (crypto/sysinfo) · termite/alacritty ·
#              green-on-black theme · cava · cmatrix · neofetch · oh-my-zsh
# =============================================================================
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; exit 1; }

[[ $EUID -eq 0 ]] && error "Do NOT run as root. Run as your normal user (sudo access required)."

DOTDIR="$HOME/.config"
mkdir -p "$DOTDIR"

# ─── 1. SYSTEM UPDATE + CORE PACKAGES ─────────────────────────────────────────
info "Updating system and installing core packages..."
sudo apt update -qq
sudo apt install -y \
  i3 i3status i3lock i3blocks \
  polybar \
  alacritty \
  zsh \
  neofetch htop \
  cava cmatrix \
  feh picom rofi dunst \
  fonts-font-awesome \
  curl wget git unzip \
  lm-sensors net-tools \
  xorg xinit \
  python3 python3-pip \
  jq bc \
  2>/dev/null || warn "Some packages may have failed — continuing."

# ─── 2. IOSEVKA NERD FONT ─────────────────────────────────────────────────────
info "Installing Iosevka Nerd Font..."
FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"
if ! fc-list | grep -qi "iosevka"; then
  FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/Iosevka.zip"
  wget -q --show-progress -O /tmp/Iosevka.zip "$FONT_URL"
  unzip -q /tmp/Iosevka.zip -d "$FONT_DIR/IosevkaNerd" || true
  fc-cache -fv "$FONT_DIR" > /dev/null 2>&1
  info "Iosevka Nerd Font installed."
else
  info "Iosevka Nerd Font already present."
fi

# ─── 3. OH-MY-ZSH ─────────────────────────────────────────────────────────────
info "Installing oh-my-zsh..."
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  RUNZSH=no CHSH=no sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# Syntax highlighting + autosuggestions plugins
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
[[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]] && \
  git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git \
  "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
[[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]] && \
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git \
  "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

# Change default shell
sudo chsh -s "$(which zsh)" "$USER" 2>/dev/null || warn "Could not change shell automatically. Run: chsh -s \$(which zsh)"

# ─── 4. .ZSHRC ────────────────────────────────────────────────────────────────
info "Writing .zshrc..."
cat > "$HOME/.zshrc" << 'ZSHRC'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="agnoster"
plugins=(git zsh-syntax-highlighting zsh-autosuggestions sudo history)
source $ZSH/oh-my-zsh.sh

# Green prompt tint
export TERM=xterm-256color
export CLICOLOR=1
export LS_COLORS='di=1;32:fi=0;32:ln=1;36:ex=1;31:'

# Aliases
alias ls='ls --color=always'
alias ll='ls -lah --color=always'
alias grep='grep --color=always'
alias tree='tree -C'
alias cls='clear && neofetch'

# Auto-start neofetch on new terminal
neofetch
ZSHRC

# ─── 5. ALACRITTY (green-on-black theme like termite in screenshot) ─────────────
info "Configuring alacritty terminal..."
mkdir -p "$DOTDIR/alacritty"
cat > "$DOTDIR/alacritty/alacritty.toml" << 'ALACRITTY'
[window]
padding = { x = 8, y = 8 }
decorations = "none"
opacity = 0.90
dynamic_title = true

[font]
normal = { family = "IosevkaNFM", style = "Regular" }
bold   = { family = "IosevkaNFM", style = "Bold" }
size   = 10.5

[colors.primary]
background = "#0a0a0a"
foreground = "#00ff41"

[colors.cursor]
text   = "#000000"
cursor = "#00ff41"

[colors.normal]
black   = "#0a0a0a"
red     = "#ff0000"
green   = "#00ff41"
yellow  = "#ffff00"
blue    = "#0080ff"
magenta = "#ff00ff"
cyan    = "#00ffff"
white   = "#aaffaa"

[colors.bright]
black   = "#333333"
red     = "#ff4444"
green   = "#44ff77"
yellow  = "#ffff55"
blue    = "#4499ff"
magenta = "#ff44ff"
cyan    = "#44ffff"
white   = "#ccffcc"

[cursor]
style   = { shape = "Block", blinking = "On" }
ALACRITTY

# ─── 6. NEOFETCH CONFIG ────────────────────────────────────────────────────────
info "Configuring neofetch..."
mkdir -p "$DOTDIR/neofetch"
cat > "$DOTDIR/neofetch/config.conf" << 'NEOFETCH'
print_info() {
    info title
    info underline
    info "OS"        distro
    info "Host"      model
    info "Kernel"    kernel
    info "Uptime"    uptime
    info "Packages"  packages
    info "Shell"     shell
    info "Resolution" resolution
    info "WM"        wm
    info "Terminal"  term
    info "Terminal Font" term_font
    info "CPU"       cpu
    info "GPU"       gpu
    info "Memory"    memory
    info cols
}
kernel_shorthand="on"
distro_shorthand="off"
os_arch="on"
uptime_shorthand="tiny"
memory_percent="off"
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
refresh_rate="off"
gtk_shorthand="off"
colors=(distro)
bold="on"
underline_enabled="on"
underline_char="-"
separator=":"
color_blocks="on"
block_range=(0 15)
block_width=3
block_height=1
col_offset="auto"
bar_char_elapsed="-"
bar_char_total="="
bar_border="on"
bar_length=15
bar_color_elapsed="distro"
bar_color_total="distro"
ascii_distro="kali"
ascii_colors=(2 2)
ascii_bold="on"
image_backend="ascii"
image_source="auto"
NEOFETCH

# ─── 7. CAVA CONFIG (audio visualizer) ────────────────────────────────────────
info "Configuring cava..."
mkdir -p "$DOTDIR/cava"
cat > "$DOTDIR/cava/config" << 'CAVA'
[general]
mode = normal
framerate = 60
autosens = 1
bars = 40
bar_width = 2
bar_spacing = 1

[output]
method = ncurses
channels = mono

[color]
gradient = 1
gradient_count = 3
gradient_color_1 = '#003300'
gradient_color_2 = '#00aa00'
gradient_color_3 = '#00ff41'

[smoothing]
monstercat = 1
waves = 0
CAVA

# ─── 8. POLYBAR ───────────────────────────────────────────────────────────────
info "Configuring polybar..."
mkdir -p "$DOTDIR/polybar"

# Launch script
cat > "$DOTDIR/polybar/launch.sh" << 'LAUNCH'
#!/usr/bin/env bash
killall -q polybar || true
while pgrep -u $UID -x polybar >/dev/null; do sleep 0.5; done
polybar main 2>&1 | tee -a /tmp/polybar-main.log & disown
LAUNCH
chmod +x "$DOTDIR/polybar/launch.sh"

# Crypto price script
cat > "$DOTDIR/polybar/crypto.sh" << 'CRYPTO'
#!/usr/bin/env bash
# Usage: ./crypto.sh BTC | BCH | ETH
COIN="${1:-BTC}"
PRICE=$(curl -sf "https://api.coinbase.com/v2/prices/${COIN}-USD/spot" 2>/dev/null | \
        jq -r '.data.amount' 2>/dev/null | xargs printf "%.0f" 2>/dev/null)
[[ -z "$PRICE" ]] && echo "${COIN} N/A" && exit 0
echo "${COIN} \$${PRICE}"
CRYPTO
chmod +x "$DOTDIR/polybar/crypto.sh"

# Firewall status script
cat > "$DOTDIR/polybar/firewall.sh" << 'FW'
#!/usr/bin/env bash
if sudo ufw status 2>/dev/null | grep -q "Status: active"; then
  echo "FW ON"
else
  echo "FW OFF"
fi
FW
chmod +x "$DOTDIR/polybar/firewall.sh"

# Main polybar config
cat > "$DOTDIR/polybar/config.ini" << 'POLYBAR'
; ══════════════════════════════════════════════════════
;  POLYBAR CONFIG — hacker green theme
; ══════════════════════════════════════════════════════

[colors]
bg         = #cc0a0a0a
fg         = #00ff41
green      = #00ff41
green-dim  = #00aa33
red        = #ff2222
yellow     = #ffff00
cyan       = #00ffff
white      = #aaffaa
dim        = #446644
separator  = #224422

[bar/main]
width            = 100%
height           = 20
offset-x         = 0
offset-y         = 0
radius           = 0
fixed-center     = true
background       = ${colors.bg}
foreground       = ${colors.fg}
line-size        = 2
line-color       = ${colors.green}
border-size      = 0
padding-left     = 1
padding-right    = 1
module-margin-left  = 1
module-margin-right = 1
font-0           = IosevkaNFM:size=9;2
font-1           = FontAwesome:size=9;2
font-2           = IosevkaNFM:size=7;1
separator        = |
separator-foreground = ${colors.separator}
modules-left     = i3
modules-center   = btc bch eth
modules-right    = cpu ram disk net-down net-up firewall ip weather date
wm-restack       = i3
override-redirect = true
cursor-click     = pointer

; ── Workspaces ─────────────────────────────────────────
[module/i3]
type = internal/i3
format = <label-state> <label-mode>
index-sort = true
wrapping-scroll = false
label-mode-padding = 1
label-mode-foreground = ${colors.fg}
label-mode-background = ${colors.bg}
label-focused          = %index%
label-focused-foreground = #000000
label-focused-background = ${colors.green}
label-focused-padding  = 1
label-unfocused        = %index%
label-unfocused-foreground = ${colors.dim}
label-unfocused-padding = 1
label-urgent           = %index%!
label-urgent-foreground = ${colors.red}
label-urgent-padding   = 1

; ── Crypto ──────────────────────────────────────────────
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

; ── System ──────────────────────────────────────────────
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

[module/net-down]
type = internal/network
interface-type = wired
interval = 2
format-connected = <label-connected>
format-connected-prefix = " IN "
format-connected-prefix-foreground = ${colors.green-dim}
label-connected = %downspeed%

[module/net-up]
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
format-prefix = " "

[module/ip]
type = custom/script
exec = ip route get 1 2>/dev/null | awk '{print $7; exit}' || echo "N/A"
interval = 60
format-prefix = " "
format-prefix-foreground = ${colors.green-dim}
format-foreground = ${colors.fg}

[module/weather]
type = custom/script
exec = curl -sf "wttr.in/?format=%c%t" 2>/dev/null || echo "N/A"
interval = 1800
format-prefix = ""
format-foreground = ${colors.fg}

[module/date]
type = internal/date
interval = 1
date       = %A, %d %B %Y
time       = %H:%M:%S
label      = %date%  %time%
format-foreground = ${colors.fg}
POLYBAR

# ─── 9. PICOM (compositor for transparency/shadows) ──────────────────────────
info "Configuring picom compositor..."
mkdir -p "$DOTDIR/picom"
cat > "$DOTDIR/picom/picom.conf" << 'PICOM'
backend = "glx";
vsync = true;
shadow = true;
shadow-radius = 12;
shadow-offset-x = -12;
shadow-offset-y = -12;
shadow-opacity = 0.6;
shadow-color = "#000000";
shadow-exclude = [
  "class_g = 'Polybar'",
  "_NET_WM_STATE@:32a *= '_NET_WM_STATE_HIDDEN'"
];
fading = true;
fade-in-step = 0.03;
fade-out-step = 0.03;
inactive-opacity = 0.85;
active-opacity = 0.95;
frame-opacity = 1.0;
opacity-rule = [
  "100:class_g = 'Polybar'",
  "92:class_g = 'Alacritty'"
];
blur-method = "dual_kawase";
blur-strength = 5;
blur-background = true;
blur-background-exclude = [
  "class_g = 'Polybar'"
];
PICOM

# ─── 10. ROFI (app launcher) ──────────────────────────────────────────────────
info "Configuring rofi..."
mkdir -p "$DOTDIR/rofi"
cat > "$DOTDIR/rofi/config.rasi" << 'ROFI'
configuration {
  modi: "drun,run,window";
  show-icons: true;
  font: "IosevkaNFM 11";
}
* {
  bg:      #0a0a0aee;
  fg:      #00ff41;
  accent:  #00aa33;
  urgent:  #ff2222;
  background-color: @bg;
  text-color:       @fg;
  border-color:     @accent;
}
window {
  border: 2px;
  border-color: @accent;
  border-radius: 0px;
  width: 40%;
}
inputbar { padding: 8px 12px; background-color: #0d200d; }
prompt   { text-color: @accent; }
entry    { text-color: @fg; }
listview { lines: 10; padding: 4px; }
element selected { background-color: @accent; text-color: #000000; }
ROFI

# ─── 11. I3 CONFIG ────────────────────────────────────────────────────────────
info "Writing i3 config..."
mkdir -p "$DOTDIR/i3"
cat > "$DOTDIR/i3/config" << 'I3CONFIG'
# ══════════════════════════════════════════════════════
#  i3 CONFIG — hacker green theme
# ══════════════════════════════════════════════════════

set $mod Mod4
set $term alacritty
set $menu rofi -show drun

font pango:IosevkaNFM 9

# ── Startup ──────────────────────────────────────────
exec_always --no-startup-id ~/.config/polybar/launch.sh
exec_always --no-startup-id picom --config ~/.config/picom/picom.conf -b
exec_always --no-startup-id feh --bg-scale ~/.config/i3/wallpaper.jpg
exec        --no-startup-id dunst
exec        --no-startup-id setxkbmap -option caps:escape

# ── Window Colors (green theme) ──────────────────────
# class                 border   bg       text     indicator child_border
client.focused          #00aa33  #0a0a0a  #00ff41  #00ff41   #00aa33
client.focused_inactive #224422  #0a0a0a  #446644  #224422   #224422
client.unfocused        #111111  #0a0a0a  #336633  #111111   #111111
client.urgent           #ff2222  #0a0a0a  #ff4444  #ff2222   #ff2222

# ── Gaps & Borders ───────────────────────────────────
for_window [class=".*"] border pixel 2
gaps inner 8
gaps outer 4

# ── Key Bindings ─────────────────────────────────────
bindsym $mod+Return      exec $term
bindsym $mod+d           exec $menu
bindsym $mod+Shift+q     kill
bindsym $mod+Shift+r     restart
bindsym $mod+Shift+e     exec "i3-nagbar -t warning -m 'Exit i3?' -B 'Yes' 'i3-msg exit'"

# Focus
bindsym $mod+h focus left
bindsym $mod+j focus down
bindsym $mod+k focus up
bindsym $mod+l focus right
bindsym $mod+Left  focus left
bindsym $mod+Down  focus down
bindsym $mod+Up    focus up
bindsym $mod+Right focus right

# Move
bindsym $mod+Shift+h move left
bindsym $mod+Shift+j move down
bindsym $mod+Shift+k move up
bindsym $mod+Shift+l move right

# Layout
bindsym $mod+s layout stacking
bindsym $mod+w layout tabbed
bindsym $mod+e layout toggle split
bindsym $mod+f fullscreen toggle
bindsym $mod+Shift+space floating toggle
bindsym $mod+space focus mode_toggle

# Splits
bindsym $mod+b split h
bindsym $mod+v split v

# Workspaces
set $ws1  "1"
set $ws2  "2"
set $ws3  "3"
set $ws4  "4"
set $ws5  "5"
set $ws6  "6"
set $ws7  "7"
set $ws8  "8"
set $ws9  "9"
set $ws10 "10"

bindsym $mod+1 workspace number $ws1
bindsym $mod+2 workspace number $ws2
bindsym $mod+3 workspace number $ws3
bindsym $mod+4 workspace number $ws4
bindsym $mod+5 workspace number $ws5
bindsym $mod+6 workspace number $ws6
bindsym $mod+7 workspace number $ws7
bindsym $mod+8 workspace number $ws8
bindsym $mod+9 workspace number $ws9
bindsym $mod+0 workspace number $ws10

bindsym $mod+Shift+1 move container to workspace number $ws1
bindsym $mod+Shift+2 move container to workspace number $ws2
bindsym $mod+Shift+3 move container to workspace number $ws3
bindsym $mod+Shift+4 move container to workspace number $ws4
bindsym $mod+Shift+5 move container to workspace number $ws5
bindsym $mod+Shift+6 move container to workspace number $ws6
bindsym $mod+Shift+7 move container to workspace number $ws7
bindsym $mod+Shift+8 move container to workspace number $ws8
bindsym $mod+Shift+9 move container to workspace number $ws9
bindsym $mod+Shift+0 move container to workspace number $ws10

# Resize mode
mode "resize" {
  bindsym h resize shrink width  10 px or 10 ppt
  bindsym j resize grow   height 10 px or 10 ppt
  bindsym k resize shrink height 10 px or 10 ppt
  bindsym l resize grow   width  10 px or 10 ppt
  bindsym Return mode "default"
  bindsym Escape mode "default"
}
bindsym $mod+r mode "resize"

# ── Quick Launch Shortcuts ────────────────────────────
bindsym $mod+ctrl+m exec $term -e cmatrix -C green
bindsym $mod+ctrl+v exec $term -e cava
bindsym $mod+ctrl+h exec $term -e htop
bindsym $mod+ctrl+n exec $term -e neofetch
# Screenshot
bindsym Print exec scrot ~/Pictures/screenshot_%Y%m%d_%H%M%S.png

# Floating exceptions
for_window [class="Pavucontrol"] floating enable
for_window [class="Nitrogen"]    floating enable
for_window [window_role="pop-up|bubble|dialog"] floating enable

# Bar managed by polybar — disable default i3bar
# (polybar launch.sh handles it)
I3CONFIG

# ─── 12. WALLPAPER ────────────────────────────────────────────────────────────
info "Downloading dark wallpaper..."
mkdir -p "$DOTDIR/i3"
# Dark atmospheric wallpaper
wget -q --show-progress \
  "https://raw.githubusercontent.com/terroo/wallpapers/main/images/20.jpg" \
  -O "$DOTDIR/i3/wallpaper.jpg" 2>/dev/null || \
# Fallback: generate a simple dark green gradient wallpaper via ImageMagick
{
  if command -v convert &>/dev/null; then
    convert -size 1920x1080 gradient:"#000000-#001a00" "$DOTDIR/i3/wallpaper.jpg"
    warn "Downloaded wallpaper failed; generated gradient fallback."
  else
    warn "Could not download wallpaper. Add your own to ~/.config/i3/wallpaper.jpg"
  fi
}

# ─── 13. GTK THEME (dark) ─────────────────────────────────────────────────────
info "Setting dark GTK theme..."
mkdir -p "$HOME/.config/gtk-3.0"
cat > "$HOME/.config/gtk-3.0/settings.ini" << 'GTK'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=IosevkaNFM 10
gtk-cursor-theme-name=Adwaita
gtk-application-prefer-dark-theme=1
GTK

# ─── 14. .XINITRC ─────────────────────────────────────────────────────────────
info "Writing .xinitrc..."
cat > "$HOME/.xinitrc" << 'XINITRC'
#!/bin/sh
# Fix hidpi / DPI
xrandr --dpi 96

# Keyboard bell off
xset b off

# Mouse acceleration off
xset m 0 0

# Start i3
exec i3
XINITRC

# ─── 15. DISPLAY MANAGER HINT ─────────────────────────────────────────────────
info "Checking for display manager..."
if systemctl is-active --quiet gdm || systemctl is-active --quiet lightdm || \
   systemctl is-active --quiet sddm; then
  warn "A display manager is running. After reboot, select 'i3' from the session menu."
else
  info "No display manager detected. Start i3 with: startx"
fi

# ─── DONE ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         KALI i3 HACKER SETUP — COMPLETE              ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  Reboot or restart your session, then select i3.     ║${NC}"
echo -e "${GREEN}║                                                      ║${NC}"
echo -e "${GREEN}║  KEYBINDS (Mod = Super/Win key)                      ║${NC}"
echo -e "${GREEN}║  Mod+Enter        → Open terminal (alacritty)        ║${NC}"
echo -e "${GREEN}║  Mod+D            → App launcher (rofi)              ║${NC}"
echo -e "${GREEN}║  Mod+Ctrl+M       → cmatrix (matrix rain)            ║${NC}"
echo -e "${GREEN}║  Mod+Ctrl+V       → cava (audio visualizer)          ║${NC}"
echo -e "${GREEN}║  Mod+Ctrl+H       → htop                             ║${NC}"
echo -e "${GREEN}║  Mod+Ctrl+N       → neofetch                         ║${NC}"
echo -e "${GREEN}║  Mod+1..0         → Switch workspace                 ║${NC}"
echo -e "${GREEN}║  Mod+Shift+1..0   → Move window to workspace         ║${NC}"
echo -e "${GREEN}║  Mod+R            → Resize mode                      ║${NC}"
echo -e "${GREEN}║  Mod+F            → Fullscreen                       ║${NC}"
echo -e "${GREEN}║  Print            → Screenshot                       ║${NC}"
echo -e "${GREEN}║                                                      ║${NC}"
echo -e "${GREEN}║  Replace wallpaper: ~/.config/i3/wallpaper.jpg       ║${NC}"
echo -e "${GREEN}║  Polybar config:    ~/.config/polybar/config.ini     ║${NC}"
echo -e "${GREEN}║  i3 config:         ~/.config/i3/config              ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
