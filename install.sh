#!/usr/bin/env bash
# =============================================================================
#  ARCH LINUX — BSPWM TURNKEY INSTALLER
#  Supports: UEFI (GPT) and BIOS Legacy (GPT + BIOS-boot partition)
#  Desktop:  BSPWM + SXHKD + Polybar + Rofi + Picom + Dunst + Alacritty
#  Audio:    PipeWire  |  Network: NetworkManager  |  DM: LY
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

# ─── COLORS ────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[0;33m'
BLU='\033[0;34m'; MAG='\033[0;35m'; CYN='\033[0;36m'
BOLD='\033[1m'; RST='\033[0m'

LOG_FILE="/tmp/arch-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# ─── HELPERS ────────────────────────────────────────────────────────────────
info()    { echo -e "${BLU}${BOLD}[INFO]${RST}  $*"; }
ok()      { echo -e "${GRN}${BOLD}[ OK ]${RST}  $*"; }
warn()    { echo -e "${YLW}${BOLD}[WARN]${RST}  $*"; }
err()     { echo -e "${RED}${BOLD}[ERR ]${RST}  $*" >&2; exit 1; }
section() { echo -e "\n${MAG}${BOLD}══════════════════════════════════════════${RST}"; \
            echo -e "${MAG}${BOLD}  $*${RST}"; \
            echo -e "${MAG}${BOLD}══════════════════════════════════════════${RST}\n"; }
prompt()  { echo -en "${CYN}${BOLD}[?]${RST} $* "; }

# ─── ROOT CHECK ─────────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && err "Run this script as root (from Arch live ISO)."

# ─── INTERNET CHECK ─────────────────────────────────────────────────────────
section "Pre-flight Checks"
info "Checking internet connectivity..."
ping -c 2 -W 3 archlinux.org &>/dev/null || err "No internet. Connect first (try: iwctl or dhcpcd)."
ok "Internet OK"

# ─── CLOCK SYNC ─────────────────────────────────────────────────────────────
info "Syncing system clock..."
timedatectl set-ntp true
ok "NTP enabled"

# ─── FIRMWARE MODE ──────────────────────────────────────────────────────────
if [[ -d /sys/firmware/efi/efivars ]]; then
    FIRMWARE="UEFI"
    ok "Boot mode: UEFI"
else
    FIRMWARE="BIOS"
    warn "Boot mode: Legacy BIOS"
fi

# ─── LIST DISKS ─────────────────────────────────────────────────────────────
section "Disk Selection"
echo -e "${BOLD}Available disks:${RST}"
lsblk -dpno NAME,SIZE,MODEL | grep -v "loop\|rom\|airoot"
echo ""

prompt "Target disk (e.g. /dev/sda or /dev/nvme0n1):"; read -r TARGET_DISK
[[ -b "$TARGET_DISK" ]] || err "Disk '$TARGET_DISK' not found."

prompt "Swap size in GiB (0 to skip, recommend 4-8):"; read -r SWAP_SIZE
[[ "$SWAP_SIZE" =~ ^[0-9]+$ ]] || err "Enter a number."

warn "⚠  ALL DATA ON $TARGET_DISK WILL BE DESTROYED ⚠"
prompt "Type 'YES' to continue:"; read -r CONFIRM
[[ "$CONFIRM" == "YES" ]] || err "Aborted."

# ─── USER CONFIG ────────────────────────────────────────────────────────────
section "User & System Configuration"

prompt "Hostname:"; read -r HOSTNAME
[[ -n "$HOSTNAME" ]] || err "Hostname cannot be empty."

prompt "Username:"; read -r USERNAME
[[ -n "$USERNAME" ]] || err "Username cannot be empty."

prompt "User password (input hidden):"; read -rs USER_PASS; echo
[[ -n "$USER_PASS" ]] || err "Password cannot be empty."

prompt "Root password (input hidden):"; read -rs ROOT_PASS; echo
[[ -n "$ROOT_PASS" ]] || err "Root password cannot be empty."

# Timezone
echo ""
info "Common timezones: America/Toronto, America/New_York, America/Los_Angeles,"
info "                  Europe/London, Europe/Berlin, Asia/Tokyo, UTC"
prompt "Timezone [default: America/Toronto]:"; read -r TIMEZONE
TIMEZONE=${TIMEZONE:-America/Toronto}
[[ -f "/usr/share/zoneinfo/$TIMEZONE" ]] || err "Invalid timezone: $TIMEZONE"

# Locale
prompt "Locale [default: en_US.UTF-8]:"; read -r LOCALE
LOCALE=${LOCALE:-en_US.UTF-8}

# Keymap
prompt "Console keymap [default: us]:"; read -r KEYMAP
KEYMAP=${KEYMAP:-us}

# Desktop resolution (for polybar DPI hints)
prompt "Screen resolution (e.g. 1920x1080) [default: 1920x1080]:"; read -r RESOLUTION
RESOLUTION=${RESOLUTION:-1920x1080}

# ─── PARTITIONING ───────────────────────────────────────────────────────────
section "Partitioning $TARGET_DISK"

# Detect nvme naming convention
if [[ "$TARGET_DISK" == *"nvme"* ]]; then
    PART_PREFIX="${TARGET_DISK}p"
else
    PART_PREFIX="${TARGET_DISK}"
fi

info "Wiping disk signatures..."
wipefs -af "$TARGET_DISK" &>/dev/null
sgdisk --zap-all "$TARGET_DISK" &>/dev/null

if [[ "$FIRMWARE" == "UEFI" ]]; then
    info "Creating GPT layout (UEFI)..."
    sgdisk -n 1:0:+512M  -t 1:ef00 -c 1:"EFI"   "$TARGET_DISK"
    if [[ "$SWAP_SIZE" -gt 0 ]]; then
        sgdisk -n 2:0:+${SWAP_SIZE}G -t 2:8200 -c 2:"SWAP" "$TARGET_DISK"
        sgdisk -n 3:0:0      -t 3:8300 -c 3:"ROOT"  "$TARGET_DISK"
        PART_EFI="${PART_PREFIX}1"
        PART_SWAP="${PART_PREFIX}2"
        PART_ROOT="${PART_PREFIX}3"
    else
        sgdisk -n 2:0:0      -t 2:8300 -c 2:"ROOT"  "$TARGET_DISK"
        PART_EFI="${PART_PREFIX}1"
        PART_SWAP=""
        PART_ROOT="${PART_PREFIX}2"
    fi
else
    info "Creating GPT layout (BIOS legacy)..."
    sgdisk -n 1:0:+1M    -t 1:ef02 -c 1:"BIOS"  "$TARGET_DISK"  # BIOS boot
    if [[ "$SWAP_SIZE" -gt 0 ]]; then
        sgdisk -n 2:0:+${SWAP_SIZE}G -t 2:8200 -c 2:"SWAP" "$TARGET_DISK"
        sgdisk -n 3:0:0      -t 3:8300 -c 3:"ROOT"  "$TARGET_DISK"
        PART_SWAP="${PART_PREFIX}2"
        PART_ROOT="${PART_PREFIX}3"
    else
        sgdisk -n 2:0:0      -t 2:8300 -c 2:"ROOT"  "$TARGET_DISK"
        PART_SWAP=""
        PART_ROOT="${PART_PREFIX}2"
    fi
    PART_EFI=""
fi

partprobe "$TARGET_DISK"
sleep 2
ok "Partitions created"

# ─── FORMATTING ─────────────────────────────────────────────────────────────
section "Formatting Partitions"

if [[ "$FIRMWARE" == "UEFI" ]]; then
    info "Formatting EFI partition (FAT32)..."
    mkfs.fat -F32 -n EFI "$PART_EFI"
fi

if [[ -n "$PART_SWAP" ]]; then
    info "Initializing swap..."
    mkswap -L SWAP "$PART_SWAP"
    swapon "$PART_SWAP"
fi

info "Formatting root partition (ext4)..."
mkfs.ext4 -L ROOT -F "$PART_ROOT"
ok "Formatting complete"

# ─── MOUNTING ───────────────────────────────────────────────────────────────
section "Mounting Filesystems"
mount "$PART_ROOT" /mnt

if [[ "$FIRMWARE" == "UEFI" ]]; then
    mkdir -p /mnt/boot/efi
    mount "$PART_EFI" /mnt/boot/efi
fi

ok "Mounted"

# ─── MIRRORS ────────────────────────────────────────────────────────────────
section "Optimizing Mirrors"
info "Installing reflector and ranking mirrors (this may take a moment)..."
pacman -Sy --noconfirm reflector &>/dev/null
reflector --country Canada,US \
          --age 12 \
          --protocol https \
          --sort rate \
          --fastest 10 \
          --save /etc/pacman.d/mirrorlist
ok "Mirrors optimized"

# ─── BASE INSTALL ───────────────────────────────────────────────────────────
section "Installing Base System"

BASE_PKGS=(
    base base-devel linux linux-firmware linux-headers
    grub efibootmgr os-prober
    networkmanager network-manager-applet
    sudo git curl wget nano vim
    man-db man-pages texinfo
    bash-completion
    intel-ucode amd-ucode           # both; grub auto-selects correct one
)

info "Running pacstrap..."
pacstrap -K /mnt "${BASE_PKGS[@]}"
ok "Base system installed"

# ─── FSTAB ──────────────────────────────────────────────────────────────────
section "Generating fstab"
genfstab -U /mnt >> /mnt/etc/fstab
ok "fstab written"
cat /mnt/etc/fstab

# ─── CHROOT SCRIPT ──────────────────────────────────────────────────────────
section "Entering chroot"

# Build the inner chroot script as a heredoc
cat > /mnt/root/chroot-setup.sh << CHROOT_EOF
#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[0;33m'
BLU='\033[0;34m'; MAG='\033[0;35m'; BOLD='\033[1m'; RST='\033[0m'
info()    { echo -e "\${BLU}\${BOLD}[INFO]\${RST}  \$*"; }
ok()      { echo -e "\${GRN}\${BOLD}[ OK ]\${RST}  \$*"; }
section() { echo -e "\n\${MAG}\${BOLD}══ \$* ══\${RST}\n"; }

# ── Timezone & Clock ────────────────────────────────────────────────────────
section "Timezone & Clock"
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc
ok "Clock configured: ${TIMEZONE}"

# ── Locale ──────────────────────────────────────────────────────────────────
section "Locale"
sed -i "s/^#${LOCALE}/${LOCALE}/" /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf
ok "Locale: ${LOCALE}"

# ── Hostname ─────────────────────────────────────────────────────────────────
section "Hostname"
echo "${HOSTNAME}" > /etc/hostname
cat > /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOF
ok "Hostname: ${HOSTNAME}"

# ── Root password ────────────────────────────────────────────────────────────
section "Root Password"
echo "root:${ROOT_PASS}" | chpasswd
ok "Root password set"

# ── Pacman Config ────────────────────────────────────────────────────────────
section "Pacman Configuration"
sed -i 's/^#Color/Color/'             /etc/pacman.conf
sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf
sed -i '/^# Misc options/a ILoveCandy' /etc/pacman.conf
sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf
pacman -Sy &>/dev/null
ok "Pacman: Color, ILoveCandy, ParallelDownloads=5"

# ── BSPWM + Full Desktop Package Install ─────────────────────────────────────
section "Installing Desktop Stack"

DESKTOP_PKGS=(
    # Xorg
    xorg-server xorg-xinit xorg-xrandr xorg-xsetroot xorg-xev xorg-xprop
    xorg-xinput xdg-utils xdg-user-dirs

    # WM + hotkeys
    bspwm sxhkd

    # Compositor
    picom

    # Bar
    polybar

    # Launcher / menus
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

    # File manager
    thunar thunar-archive-plugin thunar-volman
    gvfs gvfs-mtp file-roller

    # Text editors
    nano vim

    # Fonts
    noto-fonts noto-fonts-emoji noto-fonts-cjk
    ttf-jetbrains-mono-nerd ttf-firacode-nerd
    ttf-font-awesome

    # Images / wallpaper
    feh imv gimp

    # Utilities
    htop btop neofetch fastfetch
    zip unzip p7zip
    rsync
    openssh
    acpi acpid
    upower
    polkit lxsession
    xclip xdotool
    brightnessctl
    playerctl
    maim          # screenshots
    slop          # region select for screenshots
    ranger        # terminal file manager
    wget curl

    # Networking
    networkmanager network-manager-applet
    nm-connection-editor

    # Theming
    lxappearance
    gtk2 gtk3
    arc-gtk-theme
    papirus-icon-theme
    xcursor-themes

    # Multimedia
    mpv
    ffmpeg
)

pacman -S --noconfirm --needed "\${DESKTOP_PKGS[@]}"
ok "Desktop packages installed"

# ── User Creation ────────────────────────────────────────────────────────────
section "User: ${USERNAME}"
useradd -m -G wheel,audio,video,input,storage,optical,network,lp,scanner \
        -s /bin/bash "${USERNAME}"
echo "${USERNAME}:${USER_PASS}" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
ok "User ${USERNAME} created"

# ── XDG User Dirs ────────────────────────────────────────────────────────────
su - "${USERNAME}" -c "xdg-user-dirs-update" || true

# ── GRUB Bootloader ──────────────────────────────────────────────────────────
section "Bootloader (GRUB)"

if [[ "${FIRMWARE}" == "UEFI" ]]; then
    grub-install --target=x86_64-efi \
                 --efi-directory=/boot/efi \
                 --bootloader-id=ARCH \
                 --recheck
else
    grub-install --target=i386-pc \
                 --recheck \
                 "${TARGET_DISK}"
fi

sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=3/'                /etc/default/grub
sed -i 's/^#GRUB_DISABLE_OS_PROBER.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg
ok "GRUB installed and configured"

# ── mkinitcpio ───────────────────────────────────────────────────────────────
section "Initramfs"
mkinitcpio -P
ok "Initramfs built"

# ── Enable Services ──────────────────────────────────────────────────────────
section "Enabling Services"
systemctl enable NetworkManager
systemctl enable ly
systemctl enable bluetooth
systemctl enable acpid
ok "Services enabled"

# ── AUR Helper (paru) ────────────────────────────────────────────────────────
section "AUR Helper: paru"
pacman -S --noconfirm --needed rust git base-devel &>/dev/null || true
su - "${USERNAME}" -c "
    git clone https://aur.archlinux.org/paru-bin.git /tmp/paru-bin
    cd /tmp/paru-bin
    makepkg -si --noconfirm
    rm -rf /tmp/paru-bin
" && ok "paru installed" || echo "[WARN] paru install failed — install manually later."

# ── BSPWM Config ─────────────────────────────────────────────────────────────
section "BSPWM Configuration"

BSPWM_DIR="/home/${USERNAME}/.config/bspwm"
SXHKD_DIR="/home/${USERNAME}/.config/sxhkd"
POLYBAR_DIR="/home/${USERNAME}/.config/polybar"
PICOM_DIR="/home/${USERNAME}/.config/picom"
ROFI_DIR="/home/${USERNAME}/.config/rofi"
DUNST_DIR="/home/${USERNAME}/.config/dunst"
ALACRITTY_DIR="/home/${USERNAME}/.config/alacritty"
WALL_DIR="/home/${USERNAME}/.local/share/wallpapers"

mkdir -p "\$BSPWM_DIR" "\$SXHKD_DIR" "\$POLYBAR_DIR" "\$PICOM_DIR" \
         "\$ROFI_DIR" "\$DUNST_DIR" "\$ALACRITTY_DIR" "\$WALL_DIR"

# ── bspwmrc ──────────────────────────────────────────────────────────────────
cat > "\$BSPWM_DIR/bspwmrc" << 'BSPWMRC'
#!/usr/bin/env bash

# ── Monitors & Desktops ─────────────────────────────────────────────────────
MONITOR=\$(bspc query -M --names | head -1)
bspc monitor "\$MONITOR" -d I II III IV V VI VII VIII IX X

# ── SXHKD ───────────────────────────────────────────────────────────────────
pgrep -x sxhkd > /dev/null || sxhkd &

# ── Global Settings ──────────────────────────────────────────────────────────
bspc config border_width          2
bspc config window_gap            10
bspc config top_padding           35   # room for polybar
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

# ── Colors ───────────────────────────────────────────────────────────────────
bspc config normal_border_color   "#3b4252"
bspc config active_border_color   "#4c566a"
bspc config focused_border_color  "#88c0d0"
bspc config presel_feedback_color "#81a1c1"

# ── Rules ────────────────────────────────────────────────────────────────────
bspc rule -a Gimp          desktop='^8' state=floating follow=on
bspc rule -a Thunar        state=floating
bspc rule -a Pavucontrol   state=floating
bspc rule -a Blueman-manager state=floating
bspc rule -a nm-connection-editor state=floating
bspc rule -a '*:float'     state=floating

# ── Autostart ────────────────────────────────────────────────────────────────
# Compositor
pgrep -x picom   > /dev/null || picom --daemon

# Wallpaper
~/.fehbg 2>/dev/null || feh --no-fehbg --bg-fill \
    "$(find ~/.local/share/wallpapers -type f | shuf -n1)" 2>/dev/null || \
    xsetroot -solid '#2e3440'

# Polybar
~/.config/polybar/launch.sh &

# Network tray
pgrep -x nm-applet > /dev/null || nm-applet &

# Notifications
pgrep -x dunst > /dev/null || dunst &

# PipeWire via systemd user
systemctl --user --quiet is-active pipewire 2>/dev/null || \
    { pipewire & pipewire-pulse & wireplumber &; }

# Set cursor theme
xsetroot -cursor_name left_ptr
BSPWMRC

chmod +x "\$BSPWM_DIR/bspwmrc"

# ── sxhkdrc ──────────────────────────────────────────────────────────────────
cat > "\$SXHKD_DIR/sxhkdrc" << 'SXHKDRC'
# ══════════════════════════════════════════════════════
#  SXHKD — Simple X Hotkey Daemon Configuration
# ══════════════════════════════════════════════════════

# ── Applications ─────────────────────────────────────
# Terminal
super + Return
    alacritty

# Launcher
super + d
    rofi -show drun

# Run prompt
super + r
    rofi -show run

# File manager
super + e
    thunar

# Browser (install separately)
super + b
    xdg-open https://

# ── WM Controls ──────────────────────────────────────
# Quit/restart bspwm
super + alt + {q,r}
    bspc {quit,wm -r}

# Reload sxhkd
super + Escape
    pkill -USR1 -x sxhkd

# Kill focused window
super + shift + q
    bspc node -c

# Close focused window
super + q
    bspc node -c

# ── Window State ─────────────────────────────────────
# Toggle fullscreen
super + f
    bspc node -t fullscreen

# Toggle floating
super + shift + space
    bspc node -t \~floating

# Toggle monocle layout
super + m
    bspc desktop -l next

# Toggle pseudo-tiled
super + p
    bspc node -t \~pseudo_tiled

# ── Focus / Swap ─────────────────────────────────────
# Focus node (vim-style + arrow keys)
super + {h,j,k,l}
    bspc node -f {west,south,north,east}

super + {Left,Down,Up,Right}
    bspc node -f {west,south,north,east}

# Swap node
super + shift + {h,j,k,l}
    bspc node -s {west,south,north,east}

super + shift + {Left,Down,Up,Right}
    bspc node -s {west,south,north,east}

# Focus parent/brother/first/second
super + {y,u,i,o}
    bspc node -f @{parent,brother,first,second}

# Focus next/prev window in desktop
super + {_,shift + }c
    bspc node -f {next,prev}.local.!hidden.window

# Focus last node/desktop
super + {grave,Tab}
    bspc {node,desktop} -f last

# Focus older/newer node in history
super + {o,i}
    bspc wm -h off; \
    bspc node {older,newer}; \
    bspc wm -h on

# ── Desktops ─────────────────────────────────────────
# Focus desktop
super + {1-9,0}
    bspc desktop -f '^{1-9,10}'

# Move window to desktop
super + shift + {1-9,0}
    bspc node -d '^{1-9,10}' --follow

# Focus/send to prev/next desktop
super + bracket{left,right}
    bspc desktop -f {prev,next}.local

super + shift + bracket{left,right}
    bspc node -d {prev,next}.local --follow

# ── Resize ───────────────────────────────────────────
# Preselect direction
super + ctrl + {h,j,k,l}
    bspc node -p {west,south,north,east}

super + ctrl + {Left,Down,Up,Right}
    bspc node -p {west,south,north,east}

# Preselect ratio
super + ctrl + {1-9}
    bspc node -o 0.{1-9}

# Cancel preselection (focused node)
super + ctrl + space
    bspc node -p cancel

# Cancel preselection (focused desktop)
super + ctrl + shift + space
    bspc query -N -d | xargs -I id -n 1 bspc node id -p cancel

# Expand a window (hold + press)
super + alt + {h,j,k,l}
    bspc node -z {left -20 0,bottom 0 20,top 0 -20,right 20 0}

# Contract a window
super + alt + shift + {h,j,k,l}
    bspc node -z {right -20 0,top 0 20,bottom 0 -20,left 20 0}

# Move floating window
super + {_,shift + } pointer{1,3}
    bspc pointer -g {move,resize_{side,corner}}

# ── Media Keys ───────────────────────────────────────
# Volume
XF86Audio{RaiseVolume,LowerVolume}
    pactl set-sink-volume @DEFAULT_SINK@ {+5%,-5%}

XF86AudioMute
    pactl set-sink-mute @DEFAULT_SINK@ toggle

XF86AudioMicMute
    pactl set-source-mute @DEFAULT_SOURCE@ toggle

# Brightness
XF86MonBrightness{Up,Down}
    brightnessctl set {10%+,10%-}

# Media
XF86Audio{Play,Pause}
    playerctl play-pause

XF86Audio{Next,Prev}
    playerctl {next,previous}

# ── Screenshots ──────────────────────────────────────
# Full screen
Print
    maim ~/Pictures/screenshot_\$(date +%Y%m%d_%H%M%S).png && \
    notify-send "Screenshot" "Saved to ~/Pictures"

# Select region
super + Print
    maim -s ~/Pictures/screenshot_\$(date +%Y%m%d_%H%M%S).png && \
    notify-send "Screenshot" "Region saved to ~/Pictures"

# Copy to clipboard
shift + Print
    maim | xclip -selection clipboard -t image/png && \
    notify-send "Screenshot" "Copied to clipboard"
SXHKDRC

# ── Picom Config ─────────────────────────────────────────────────────────────
cat > "\$PICOM_DIR/picom.conf" << 'PICOMRC'
# ══════════════════════════════════════════════════════
#  Picom Compositor Configuration
# ══════════════════════════════════════════════════════

# ── Backend ──────────────────────────────────────────
backend = "glx";
glx-no-stencil = true;
glx-copy-from-front = false;
use-damage = true;

# ── Shadows ──────────────────────────────────────────
shadow = true;
shadow-radius = 12;
shadow-offset-x = -7;
shadow-offset-y = -7;
shadow-opacity = 0.6;
shadow-exclude = [
    "name = 'Notification'",
    "class_g = 'Conky'",
    "class_g ?= 'Notify-osd'",
    "class_g = 'Cairo-clock'",
    "_GTK_FRAME_EXTENTS@:c",
    "bspwm_monocle = 1"
];

# ── Fading ────────────────────────────────────────────
fading = true;
fade-in-step = 0.03;
fade-out-step = 0.03;
fade-delta = 4;

# ── Opacity ───────────────────────────────────────────
inactive-opacity = 0.92;
active-opacity = 1.0;
frame-opacity = 1.0;
inactive-opacity-override = false;

opacity-rule = [
    "100:class_g = 'Alacritty' && focused",
    "90:class_g = 'Alacritty' && !focused",
    "100:class_g = 'Thunar'",
    "100:class_g = 'Gimp'"
];

# ── Blur ─────────────────────────────────────────────
blur-background = false;

# ── Corners ───────────────────────────────────────────
corner-radius = 8;
rounded-corners-exclude = [
    "class_g = 'Polybar'"
];

# ── General ──────────────────────────────────────────
mark-wmwin-focused = true;
mark-ovredir-focused = true;
detect-rounded-corners = true;
detect-client-opacity = true;
detect-transient = true;
detect-client-leader = true;
refresh-rate = 0;
PICOMRC

# ── Polybar ──────────────────────────────────────────────────────────────────
cat > "\$POLYBAR_DIR/launch.sh" << 'LAUNCHSH'
#!/usr/bin/env bash
killall -q polybar
while pgrep -u \$UID -x polybar > /dev/null; do sleep 1; done
for m in \$(polybar --list-monitors | cut -d":" -f1); do
    MONITOR=\$m polybar --reload main 2>&1 | tee -a /tmp/polybar.log & disown
done
LAUNCHSH
chmod +x "\$POLYBAR_DIR/launch.sh"

cat > "\$POLYBAR_DIR/config.ini" << 'POLYBARRC'
; ══════════════════════════════════════════════════════
;  Polybar Configuration — Nord-inspired dark theme
; ══════════════════════════════════════════════════════

[colors]
bg        = #CC2e3440
bg-alt    = #3b4252
fg        = #eceff4
fg-alt    = #4c566a
primary   = #88c0d0
secondary = #81a1c1
alert     = #bf616a
good      = #a3be8c
warn      = #ebcb8b

[bar/main]
monitor          = \${env:MONITOR:}
width            = 100%
height           = 30
radius           = 0
fixed-center     = true

background       = \${colors.bg}
foreground       = \${colors.fg}

line-size        = 2
line-color       = \${colors.primary}

border-size      = 0
padding-left     = 1
padding-right    = 1
module-margin    = 1

font-0           = "JetBrainsMono Nerd Font:size=10:weight=bold;2"
font-1           = "Font Awesome 6 Free Solid:size=10;2"
font-2           = "Noto Color Emoji:scale=10;2"

modules-left     = bspwm xwindow
modules-center   = date
modules-right    = cpu memory temperature pulseaudio battery network tray

wm-restack       = bspwm
override-redirect = true
cursor-click     = pointer
cursor-scroll    = ns-resize

[module/bspwm]
type = internal/bspwm
label-focused              = %name%
label-focused-background   = \${colors.primary}
label-focused-foreground   = \${colors.bg}
label-focused-padding      = 2
label-occupied             = %name%
label-occupied-padding     = 2
label-occupied-foreground  = \${colors.fg}
label-urgent               = %name%!
label-urgent-background    = \${colors.alert}
label-urgent-padding       = 2
label-empty                = %name%
label-empty-foreground     = \${colors.fg-alt}
label-empty-padding        = 2

[module/xwindow]
type             = internal/xwindow
label            = %title:0:50:…%
label-foreground = \${colors.fg-alt}

[module/date]
type             = internal/date
interval         = 1
date             = " %a %b %d"
time             = " %H:%M:%S"
label            = %date%  %time%
label-foreground = \${colors.primary}

[module/cpu]
type                     = internal/cpu
interval                 = 2
format-prefix            = " "
format-prefix-foreground = \${colors.secondary}
label                    = %percentage:2%%
label-foreground         = \${colors.fg}

[module/memory]
type                     = internal/memory
interval                 = 2
format-prefix            = " "
format-prefix-foreground = \${colors.secondary}
label                    = %percentage_used%%

[module/temperature]
type             = internal/temperature
thermal-zone     = 0
warn-temperature = 80
format           = <label>
format-prefix    = " "
format-prefix-foreground = \${colors.secondary}
format-warn      = <label-warn>
label            = %temperature-c%
label-warn       = %temperature-c%
label-warn-foreground = \${colors.alert}

[module/pulseaudio]
type             = internal/pulseaudio
format-volume    = <ramp-volume> <label-volume>
label-volume     = %percentage%%
label-muted      = 婢 muted
label-muted-foreground = \${colors.fg-alt}
ramp-volume-0    = 
ramp-volume-1    = 
ramp-volume-2    = 
ramp-volume-foreground = \${colors.good}
click-right      = pavucontrol

[module/battery]
type                     = internal/battery
battery                  = BAT0
adapter                  = AC
full-at                  = 98
format-charging          = <animation-charging> <label-charging>
format-discharging       = <ramp-capacity> <label-discharging>
format-full-prefix       = " "
format-full-prefix-foreground = \${colors.good}
ramp-capacity-0          = 
ramp-capacity-1          = 
ramp-capacity-2          = 
ramp-capacity-3          = 
ramp-capacity-4          = 
ramp-capacity-foreground = \${colors.good}
animation-charging-0     = 
animation-charging-1     = 
animation-charging-2     = 
animation-charging-3     = 
animation-charging-4     = 
animation-charging-foreground = \${colors.warn}
animation-charging-framerate  = 750
label-discharging        = %percentage%%
label-charging           = %percentage%%

[module/network]
type             = internal/network
interface-type   = wireless
interval         = 3
format-connected = <label-connected>
format-connected-prefix    = "直 "
format-connected-prefix-foreground = \${colors.good}
format-disconnected        = <label-disconnected>
format-disconnected-prefix = "睊 "
format-disconnected-prefix-foreground = \${colors.alert}
label-connected            = %essid%
label-disconnected         = offline
label-disconnected-foreground = \${colors.fg-alt}

[module/tray]
type        = internal/tray
tray-size   = 18
tray-spacing = 4px
POLYBARRC

# ── Rofi Config ──────────────────────────────────────────────────────────────
cat > "\$ROFI_DIR/config.rasi" << 'ROFIRC'
configuration {
    modi:               "drun,run,window";
    show-icons:         true;
    icon-theme:         "Papirus";
    font:               "JetBrainsMono Nerd Font 11";
    drun-display-format:"{name}";
    display-drun:       "Apps";
    display-run:        "Run";
    display-window:     "Windows";
    kb-cancel:          "Escape,super+d";
}

* {
    bg:      #2e3440;
    bg-alt:  #3b4252;
    fg:      #eceff4;
    fg-alt:  #4c566a;
    primary: #88c0d0;
    urgent:  #bf616a;

    border-color:              @primary;
    background-color:          transparent;
    text-color:                @fg;
}

window {
    width:            500px;
    border:           2px;
    border-color:     @primary;
    border-radius:    8px;
    background-color: @bg;
    padding:          0;
}

mainbox { background-color: transparent; }

inputbar {
    background-color: @bg-alt;
    border-radius:    6px 6px 0 0;
    padding:          8px 12px;
    children:         [ prompt, textbox-prompt-colon, entry ];
}

prompt { text-color: @primary; }
textbox-prompt-colon { text-color: @primary; margin: 0 6px 0 0; }
entry  { placeholder-color: @fg-alt; }

listview {
    padding:          6px;
    spacing:          2px;
    background-color: transparent;
}

element {
    padding:          8px 10px;
    border-radius:    4px;
    background-color: transparent;
}
element selected {
    background-color: @primary;
    text-color:       @bg;
}
element-icon  { size: 22px; margin: 0 8px 0 0; }
element-text  { vertical-align: 0.5; }

mode-switcher { background-color: @bg-alt; padding: 4px; }
button        { padding: 6px 12px; border-radius: 4px; }
button selected { background-color: @primary; text-color: @bg; }
ROFIRC

# ── Dunst Config ─────────────────────────────────────────────────────────────
cat > "\$DUNST_DIR/dunstrc" << 'DUNSTRC'
[global]
    monitor              = 0
    follow               = mouse
    width                = 320
    height               = 100
    origin               = top-right
    offset               = 12x46
    scale                = 0
    notification_limit   = 5
    progress_bar         = true
    indicate_hidden      = yes
    transparency         = 8
    separator_height     = 2
    padding              = 10
    horizontal_padding   = 12
    text_icon_padding    = 8
    frame_width          = 2
    frame_color          = "#88c0d0"
    sort                 = yes
    idle_threshold       = 120
    font                 = JetBrainsMono Nerd Font 10
    line_height          = 0
    markup               = full
    format               = "<b>%s</b>\n%b"
    alignment            = left
    vertical_alignment   = center
    show_age_threshold   = 60
    ellipsize            = middle
    ignore_newline       = no
    stack_duplicates     = true
    hide_duplicate_count = false
    show_indicators      = yes
    icon_theme           = Papirus
    enable_recursive_icon_lookup = true
    sticky_history       = yes
    history_length       = 20
    dmenu                = /usr/bin/rofi -p dunst
    browser              = /usr/bin/xdg-open
    always_run_script    = true
    corner_radius        = 6
    ignore_dbusclose     = false
    mouse_left_click     = close_current
    mouse_middle_click   = do_action, close_current
    mouse_right_click    = close_all

[urgency_low]
    background           = "#2e3440"
    foreground           = "#eceff4"
    frame_color          = "#4c566a"
    timeout              = 5

[urgency_normal]
    background           = "#2e3440"
    foreground           = "#eceff4"
    frame_color          = "#88c0d0"
    timeout              = 8

[urgency_critical]
    background           = "#2e3440"
    foreground           = "#bf616a"
    frame_color          = "#bf616a"
    timeout              = 0
DUNSTRC

# ── Alacritty Config ─────────────────────────────────────────────────────────
cat > "\$ALACRITTY_DIR/alacritty.toml" << 'ALACRITTYRC'
[window]
padding = { x = 14, y = 12 }
decorations = "full"
opacity = 0.92
blur = false
startup_mode = "Windowed"
title = "Alacritty"
dynamic_title = true
resize_increments = false

[scrolling]
history = 10000
multiplier = 3

[font]
normal = { family = "JetBrainsMono Nerd Font", style = "Regular" }
bold   = { family = "JetBrainsMono Nerd Font", style = "Bold" }
italic = { family = "JetBrainsMono Nerd Font", style = "Italic" }
size   = 11.0

[cursor]
style = { shape = "Block", blinking = "On" }
blink_interval = 500

# Nord color theme
[colors.primary]
background = "#2e3440"
foreground = "#d8dee9"
dim_foreground = "#a5abb6"

[colors.cursor]
text   = "#2e3440"
cursor = "#d8dee9"

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
key = "V" ; mods = "Control|Shift" ; action = "Paste"
[[keyboard.bindings]]
key = "C" ; mods = "Control|Shift" ; action = "Copy"
[[keyboard.bindings]]
key = "Plus" ; mods = "Control" ; action = "IncreaseFontSize"
[[keyboard.bindings]]
key = "Minus" ; mods = "Control" ; action = "DecreaseFontSize"
[[keyboard.bindings]]
key = "Key0" ; mods = "Control" ; action = "ResetFontSize"
ALACRITTYRC

# ── .xinitrc ─────────────────────────────────────────────────────────────────
cat > "/home/${USERNAME}/.xinitrc" << 'XINITRC'
#!/usr/bin/env bash
# Load X resources
[[ -f ~/.Xresources ]] && xrdb -merge ~/.Xresources

# Keyboard repeat rate
xset r rate 300 50

# Disable screen blanking
xset s off
xset -dpms
xset s noblank

exec bspwm
XINITRC
chmod +x "/home/${USERNAME}/.xinitrc"

# ── GTK Theme ────────────────────────────────────────────────────────────────
mkdir -p "/home/${USERNAME}/.config/gtk-3.0"
cat > "/home/${USERNAME}/.config/gtk-3.0/settings.ini" << 'GTKRC'
[Settings]
gtk-theme-name        = Arc-Dark
gtk-icon-theme-name   = Papirus-Dark
gtk-font-name         = Noto Sans 10
gtk-cursor-theme-name = Adwaita
gtk-cursor-theme-size = 16
gtk-toolbar-style     = GTK_TOOLBAR_ICONS
gtk-button-images     = 0
gtk-menu-images       = 0
gtk-enable-event-sounds  = 0
gtk-enable-input-feedback-sounds = 0
gtk-xft-antialias     = 1
gtk-xft-hinting       = 1
gtk-xft-hintstyle     = hintslight
gtk-xft-rgba          = rgb
GTKRC

cat > "/home/${USERNAME}/.gtkrc-2.0" << 'GTK2RC'
gtk-theme-name        = "Arc-Dark"
gtk-icon-theme-name   = "Papirus-Dark"
gtk-font-name         = "Noto Sans 10"
gtk-cursor-theme-name = "Adwaita"
GTK2RC

# ── .bashrc extras ───────────────────────────────────────────────────────────
cat >> "/home/${USERNAME}/.bashrc" << 'BASHRC'

# ── Aliases ─────────────────────────────────────────────────────────────────
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias grep='grep --color=auto'
alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -Iv'
alias mkdir='mkdir -pv'
alias df='df -h'
alias du='du -sh'
alias free='free -m'
alias pacup='sudo pacman -Syu'
alias pacsearch='pacman -Ss'
alias pacin='sudo pacman -S'
alias pacrem='sudo pacman -Rns'
alias paci='pacman -Si'

# ── Prompt ────────────────────────────────────────────────────────────────
RESET='\[\e[0m\]'
BOLD='\[\e[1m\]'
BLUE='\[\e[34m\]'
CYAN='\[\e[36m\]'
GREEN='\[\e[32m\]'
PS1="\${BOLD}\${CYAN}[\${BLUE}\u\${CYAN}@\${GREEN}\h\${CYAN}] \${BLUE}\w\${RESET}\$ "

# neofetch on new terminal
command -v fastfetch &>/dev/null && fastfetch
BASHRC

# ── Generate a default wallpaper ─────────────────────────────────────────────
# Create a simple SVG wallpaper in case no wallpaper is available
cat > "\$WALL_DIR/default.svg" << 'WALLSVG'
<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%"   stop-color="#2e3440"/>
      <stop offset="100%" stop-color="#1a1e28"/>
    </linearGradient>
  </defs>
  <rect width="1920" height="1080" fill="url(#bg)"/>
  <circle cx="960" cy="540" r="200" fill="none" stroke="#3b4252" stroke-width="1"/>
  <circle cx="960" cy="540" r="400" fill="none" stroke="#3b4252" stroke-width="0.5" stroke-dasharray="4,8"/>
  <text x="960" y="530" font-family="monospace" font-size="14" fill="#4c566a" text-anchor="middle">arch linux</text>
  <text x="960" y="560" font-family="monospace" font-size="10" fill="#434c5e" text-anchor="middle">bspwm</text>
</svg>
WALLSVG

# Convert SVG to PNG if imagemagick is available
command -v convert &>/dev/null && \
    convert "\$WALL_DIR/default.svg" "\$WALL_DIR/default.png" 2>/dev/null && \
    rm "\$WALL_DIR/default.svg" || true

# ── Fix ownership ─────────────────────────────────────────────────────────────
chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}"

# ── Screenshot dir ────────────────────────────────────────────────────────────
mkdir -p "/home/${USERNAME}/Pictures"
chown "${USERNAME}:${USERNAME}" "/home/${USERNAME}/Pictures"

# ── LY display manager config ────────────────────────────────────────────────
if [[ -f /etc/ly/config.ini ]]; then
    sed -i 's/^#animate.*/animate = true/' /etc/ly/config.ini 2>/dev/null || true
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "\${GRN}\${BOLD}╔══════════════════════════════════════════╗\${RST}"
echo -e "\${GRN}\${BOLD}║      ARCH LINUX BSPWM INSTALL DONE      ║\${RST}"
echo -e "\${GRN}\${BOLD}╠══════════════════════════════════════════╣\${RST}"
echo -e "\${GRN}\${BOLD}║\${RST}  Host    : ${HOSTNAME}"
echo -e "\${GRN}\${BOLD}║\${RST}  User    : ${USERNAME}"
echo -e "\${GRN}\${BOLD}║\${RST}  Disk    : ${TARGET_DISK}"
echo -e "\${GRN}\${BOLD}║\${RST}  Boot    : ${FIRMWARE}"
echo -e "\${GRN}\${BOLD}║\${RST}  TZ      : ${TIMEZONE}"
echo -e "\${GRN}\${BOLD}║\${RST}  WM      : BSPWM + SXHKD"
echo -e "\${GRN}\${BOLD}║\${RST}  Bar     : Polybar (Nord)"
echo -e "\${GRN}\${BOLD}║\${RST}  Term    : Alacritty"
echo -e "\${GRN}\${BOLD}║\${RST}  DM      : LY"
echo -e "\${GRN}\${BOLD}╚══════════════════════════════════════════╝\${RST}"
echo ""
echo -e "\${YLW}\${BOLD}Key bindings (quick ref):\${RST}"
echo "  super+Return     → terminal (alacritty)"
echo "  super+d          → app launcher (rofi)"
echo "  super+q          → close window"
echo "  super+f          → fullscreen"
echo "  super+shift+space → toggle floating"
echo "  super+m          → monocle layout"
echo "  super+1-0        → switch desktops"
echo "  super+hjkl       → focus window (vim keys)"
echo "  super+alt+hjkl   → resize window"
echo "  super+shift+q    → kill window"
echo "  super+alt+r      → restart bspwm"
echo "  super+alt+q      → quit bspwm"
echo ""
echo -e "\${CYN}Post-install tips:\${RST}"
echo "  - Install a browser:  paru -S firefox  OR  paru -S chromium"
echo "  - AUR packages:       paru -S <package>"
echo "  - Change wallpaper:   feh --bg-fill ~/path/to/image.jpg"
echo "  - GTK theme:          lxappearance"
echo ""
CHROOT_EOF

chmod +x /mnt/root/chroot-setup.sh

# ─── PASS VARIABLES INTO CHROOT ─────────────────────────────────────────────
arch-chroot /mnt /bin/bash -c "
export FIRMWARE='${FIRMWARE}'
export TARGET_DISK='${TARGET_DISK}'
/root/chroot-setup.sh
"

# ─── CLEANUP ────────────────────────────────────────────────────────────────
rm -f /mnt/root/chroot-setup.sh
info "Chroot script removed"

# ─── UNMOUNT ────────────────────────────────────────────────────────────────
section "Unmounting"
sync
[[ -n "${PART_EFI:-}" ]] && umount /mnt/boot/efi 2>/dev/null || true
[[ -n "${PART_SWAP:-}" ]] && swapoff "$PART_SWAP" 2>/dev/null || true
umount -R /mnt

ok "All filesystems unmounted"

# ─── DONE ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${GRN}${BOLD}╔══════════════════════════════════════════════╗${RST}"
echo -e "${GRN}${BOLD}║  Installation complete! Safe to reboot.      ║${RST}"
echo -e "${GRN}${BOLD}║                                              ║${RST}"
echo -e "${GRN}${BOLD}║  Remove your USB/ISO, then:                  ║${RST}"
echo -e "${GRN}${BOLD}║    reboot                                    ║${RST}"
echo -e "${GRN}${BOLD}╚══════════════════════════════════════════════╝${RST}"
echo ""
echo -e "Full install log saved to: ${LOG_FILE}"
echo -e "Copy it before rebooting if needed:"
echo -e "  cp ${LOG_FILE} /mnt/home/${USERNAME}/install.log  (already unmounted)"
echo ""
