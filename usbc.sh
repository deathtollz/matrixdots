#!/bin/bash
# =============================================================
#   clone-to-usb.sh
#   Clones your entire running Linux system directly to a USB.
#   No intermediate ISO — writes straight to the drive.
#
#   Usage: sudo bash clone-to-usb.sh
# =============================================================

set -e

# ---------------------------------------------------------------
# COLORS
# ---------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${CYAN}[*]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }
header()  { echo -e "\n${BOLD}${CYAN}=== $1 ===${NC}"; }

# ---------------------------------------------------------------
# ROOT CHECK
# ---------------------------------------------------------------
[[ $EUID -ne 0 ]] && error "Run this script as root: sudo bash clone-to-usb.sh"

# ---------------------------------------------------------------
# BANNER
# ---------------------------------------------------------------
clear
echo -e "${BOLD}${CYAN}"
echo "  ╔═══════════════════════════════════════╗"
echo "  ║        Linux USB System Cloner        ║"
echo "  ║   Writes directly to USB — no ISO     ║"
echo "  ╚═══════════════════════════════════════╝"
echo -e "${NC}"

# ---------------------------------------------------------------
# DEPENDENCY CHECK
# ---------------------------------------------------------------
header "Checking dependencies"
DEPS=(squashfs-tools grub-efi-amd64-bin grub-pc-bin rsync parted dosfstools)
MISSING=()

for dep in "${DEPS[@]}"; do
    if ! dpkg -l "$dep" &>/dev/null; then
        MISSING+=("$dep")
    fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    warn "Missing packages: ${MISSING[*]}"
    info "Installing missing packages..."
    apt update -qq
    apt install -y "${MISSING[@]}" || error "Failed to install dependencies"
fi

if ! dpkg -l live-boot &>/dev/null; then
    info "Installing live-boot..."
    apt install -y live-boot live-boot-initramfs-tools
    update-initramfs -u -k "$(uname -r)"
fi

success "All dependencies satisfied"

# ---------------------------------------------------------------
# SELECT USB DRIVE
# ---------------------------------------------------------------
header "Select target USB drive"
echo ""
echo -e "${YELLOW}Available drives:${NC}"
lsblk -o NAME,SIZE,TYPE,TRAN,VENDOR,MODEL
echo ""

warn "ALL DATA ON THE SELECTED USB WILL BE ERASED"
echo ""
read -rp "Enter USB device (e.g. /dev/sdb): " USB

[[ -z "$USB" ]]   && error "No device specified"
[[ ! -b "$USB" ]] && error "$USB is not a valid block device"

# Safety — prevent wiping the system disk
SYSTEM_DISK=$(df / | tail -1 | awk '{print $1}' | sed 's/[0-9]*$//')
[[ "$USB" == "$SYSTEM_DISK"* ]] && \
    error "That looks like your system disk ($SYSTEM_DISK). Aborting."

# Size checks
USB_SIZE=$(lsblk -bno SIZE "$USB" | head -1)
USB_SIZE_GB=$(awk "BEGIN {printf \"%.1f\", $USB_SIZE / 1073741824}")
USED_SPACE=$(df -B1 --total / | grep total | awk '{print $3}')
USED_GB=$(awk "BEGIN {printf \"%.1f\", $USED_SPACE / 1073741824}")
FREE_SPACE=$(df -B1 / | tail -1 | awk '{print $4}')
FREE_GB=$(awk "BEGIN {printf \"%.1f\", $FREE_SPACE / 1073741824}")

echo ""
info "USB size:         ${USB_SIZE_GB} GB"
info "System used:      ${USED_GB} GB  (this goes to USB)"
info "Local free space: ${FREE_GB} GB  (only ~500MB temp space needed)"
echo ""

(( USED_SPACE > USB_SIZE )) && \
    error "Your system (${USED_GB}GB) is larger than the USB (${USB_SIZE_GB}GB). Use a bigger USB."

echo -e "${RED}${BOLD}WARNING: This will completely erase $USB (${USB_SIZE_GB}GB)${NC}"
read -rp "Type YES to continue: " CONFIRM
[[ "$CONFIRM" != "YES" ]] && echo "Aborted." && exit 0

# ---------------------------------------------------------------
# DETERMINE PARTITION NAMES
# ---------------------------------------------------------------
if [[ "$USB" =~ nvme|mmcblk ]]; then
    EFI_PART="${USB}p1"
    LIVE_PART="${USB}p2"
else
    EFI_PART="${USB}1"
    LIVE_PART="${USB}2"
fi

# ---------------------------------------------------------------
# UNMOUNT ANYTHING ON THE USB
# ---------------------------------------------------------------
header "Preparing USB drive"
info "Unmounting any existing partitions on $USB..."
for part in "${USB}"*[0-9]; do
    umount "$part" 2>/dev/null || true
done
sleep 1

# ---------------------------------------------------------------
# PARTITION THE USB
# ---------------------------------------------------------------
info "Partitioning $USB..."
parted -s "$USB" mklabel gpt
parted -s "$USB" mkpart EFI  fat32  1MiB    512MiB
parted -s "$USB" set 1 esp on
parted -s "$USB" mkpart LIVE ext4   512MiB  100%
partprobe "$USB"
sleep 2

# ---------------------------------------------------------------
# FORMAT
# ---------------------------------------------------------------
info "Formatting partitions..."
mkfs.fat -F32 -n "EFI"  "$EFI_PART"
mkfs.ext4 -L  "LIVE"    "$LIVE_PART" -F
success "Partitions formatted"

# ---------------------------------------------------------------
# MOUNT USB
# ---------------------------------------------------------------
USB_MNT="/mnt/usb-live"
mkdir -p "$USB_MNT"
mount "$LIVE_PART" "$USB_MNT"
mkdir -p "$USB_MNT"/{live,boot/grub,boot/efi}
mount "$EFI_PART" "$USB_MNT/boot/efi"
success "USB mounted at $USB_MNT"

# ---------------------------------------------------------------
# BAKE IN INSTALLER SCRIPT
# ---------------------------------------------------------------
header "Preparing installer script"

cat > /usr/local/bin/install-to-disk << 'INSTALLER'
#!/bin/bash
# =====================================================
#   install-to-disk
#   Run from the live USB to install to a local disk.
#   Usage: sudo install-to-disk
# =====================================================
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'
YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[*]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }

[[ $EUID -ne 0 ]] && error "Run as root: sudo install-to-disk"

clear
echo -e "${BOLD}${CYAN}"
echo "  ╔═══════════════════════════════════════╗"
echo "  ║       Live System Installer           ║"
echo "  ╚═══════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${YELLOW}Available disks:${NC}"
lsblk -o NAME,SIZE,TYPE,MODEL
echo ""

read -rp "Target disk to install to (e.g. /dev/sda): " DISK
[[ ! -b "$DISK" ]] && error "$DISK is not a valid block device"

# Prevent overwriting the live USB
LIVE_DEV=$(df / | tail -1 | awk '{print $1}' | sed 's/[0-9p]*$//')
[[ "$DISK" == "$LIVE_DEV"* ]] && error "That's the live USB itself. Pick a different disk."

DISK_SIZE=$(lsblk -bno SIZE "$DISK" | head -1)
DISK_SIZE_GB=$(awk "BEGIN {printf \"%.1f\", $DISK_SIZE / 1073741824}")

echo ""
warn "This will ERASE $DISK (${DISK_SIZE_GB}GB) and install the system."
read -rp "Type YES to continue: " CONFIRM
[[ "$CONFIRM" != "YES" ]] && echo "Aborted." && exit 0

# Partition naming
if [[ "$DISK" =~ nvme|mmcblk ]]; then
    EFI_PART="${DISK}p1"
    ROOT_PART="${DISK}p2"
else
    EFI_PART="${DISK}1"
    ROOT_PART="${DISK}2"
fi

# Unmount anything on target
for part in "${DISK}"*[0-9]; do
    umount "$part" 2>/dev/null || true
done

# Partition
info "Partitioning $DISK..."
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart ESP  fat32  1MiB    512MiB
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart ROOT ext4   512MiB  100%
partprobe "$DISK"
sleep 2

# Format
info "Formatting..."
mkfs.fat -F32 "$EFI_PART"
mkfs.ext4 -L linux-root "$ROOT_PART" -F

# Mount target
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot/efi
mount "$EFI_PART" /mnt/boot/efi

# Copy system
info "Copying system to disk (this will take a while)..."
rsync -aAXH \
    --info=progress2 \
    --exclude="/proc/*" \
    --exclude="/sys/*" \
    --exclude="/dev/*" \
    --exclude="/tmp/*" \
    --exclude="/run/*" \
    --exclude="/mnt/*" \
    --exclude="/media/*" \
    --exclude="/lost+found" \
    / /mnt/

# fstab
info "Writing fstab..."
ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART")
EFI_UUID=$(blkid  -s UUID -o value "$EFI_PART")
cat > /mnt/etc/fstab << FSTAB
# <file system>  <mount point>  <type>  <options>          <dump>  <pass>
UUID=$ROOT_UUID  /              ext4    errors=remount-ro  0       1
UUID=$EFI_UUID   /boot/efi      vfat    umask=0077         0       1
FSTAB

# Bootloader
info "Installing GRUB..."
mount --bind /dev  /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys  /mnt/sys
mount --bind /run  /mnt/run

chroot /mnt grub-install \
    --target=x86_64-efi \
    --efi-directory=/boot/efi \
    --bootloader-id=linux \
    --recheck 2>/dev/null || warn "EFI GRUB install failed, trying BIOS..."

chroot /mnt grub-install \
    --target=i386-pc \
    "$DISK" 2>/dev/null || warn "BIOS GRUB install skipped"

chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# Cleanup
umount /mnt/dev /mnt/proc /mnt/sys /mnt/run
umount /mnt/boot/efi
umount /mnt

echo ""
success "Installation complete! Remove the USB and reboot."
INSTALLER

chmod +x /usr/local/bin/install-to-disk
success "Installer script baked in"

# ---------------------------------------------------------------
# SQUASH DIRECTLY TO USB
# ---------------------------------------------------------------
header "Squashing filesystem directly to USB"
info "Compressing your system with xz — this is the slow part ☕"
info "Nothing large is written to your local disk."
echo ""

mksquashfs / "$USB_MNT/live/filesystem.squashfs" \
    -e boot \
    -e proc \
    -e sys \
    -e dev \
    -e tmp \
    -e run \
    -e mnt \
    -e media \
    -e lost+found \
    -comp xz \
    -Xbcj x86 \
    -b 1M \
    -wildcards

SQUASH_SIZE=$(du -sh "$USB_MNT/live/filesystem.squashfs" | cut -f1)
success "Squashfs written to USB ($SQUASH_SIZE)"

# ---------------------------------------------------------------
# KERNEL & INITRAMFS
# ---------------------------------------------------------------
header "Copying kernel and initramfs"

KERNEL_VER=$(uname -r)
info "Kernel: $KERNEL_VER"

update-initramfs -u -k "$KERNEL_VER" 2>/dev/null || true

cp /boot/vmlinuz-"$KERNEL_VER" "$USB_MNT/boot/vmlinuz"

if [[ -f /boot/initrd.img-"$KERNEL_VER" ]]; then
    cp /boot/initrd.img-"$KERNEL_VER" "$USB_MNT/boot/initrd"
elif [[ -f /boot/initramfs-"$KERNEL_VER".img ]]; then
    cp /boot/initramfs-"$KERNEL_VER".img "$USB_MNT/boot/initrd"
else
    error "Could not find initramfs for kernel $KERNEL_VER"
fi

success "Kernel and initramfs copied"

# ---------------------------------------------------------------
# GRUB CONFIG
# ---------------------------------------------------------------
header "Writing GRUB config"
HOSTNAME=$(hostname)

cat > "$USB_MNT/boot/grub/grub.cfg" << EOF
set default=0
set timeout=10

menuentry "$HOSTNAME Live" {
    linux /boot/vmlinuz boot=live components username=kali hostname=$HOSTNAME quiet splash
    initrd /boot/initrd
}

menuentry "$HOSTNAME Live (nomodeset)" {
    linux /boot/vmlinuz boot=live components username=kali hostname=$HOSTNAME quiet nomodeset
    initrd /boot/initrd
}

menuentry "$HOSTNAME Live (verbose)" {
    linux /boot/vmlinuz boot=live components username=kali hostname=$HOSTNAME
    initrd /boot/initrd
}
EOF

success "GRUB config written"

# ---------------------------------------------------------------
# INSTALL GRUB TO USB
# ---------------------------------------------------------------
header "Installing GRUB to USB"

grub-install \
    --target=x86_64-efi \
    --efi-directory="$USB_MNT/boot/efi" \
    --boot-directory="$USB_MNT/boot" \
    --removable \
    --recheck 2>/dev/null \
    && success "GRUB EFI installed" \
    || warn "EFI GRUB install failed — USB may not boot on UEFI systems"

grub-install \
    --target=i386-pc \
    --boot-directory="$USB_MNT/boot" \
    "$USB" 2>/dev/null \
    && success "GRUB BIOS installed" \
    || warn "BIOS GRUB install failed — USB may not boot on legacy systems"

# ---------------------------------------------------------------
# SYNC AND UNMOUNT
# ---------------------------------------------------------------
header "Finalising"
info "Syncing to USB (please wait)..."
sync

umount "$USB_MNT/boot/efi"
umount "$USB_MNT"
success "USB unmounted cleanly"

# ---------------------------------------------------------------
# DONE
# ---------------------------------------------------------------
echo ""
echo -e "${BOLD}${GREEN}"
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║                Clone Complete!                   ║"
echo "  ╠══════════════════════════════════════════════════╣"
echo "  ║  Your USB is ready. To use it:                   ║"
echo "  ║                                                  ║"
echo "  ║  1. Boot the target machine from the USB         ║"
echo "  ║  2. Your desktop will load as normal             ║"
echo "  ║  3. Open a terminal and run:                     ║"
echo "  ║                                                  ║"
echo "  ║       sudo install-to-disk                       ║"
echo "  ║                                                  ║"
echo "  ║  4. Follow the prompts to install to the disk    ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo -e "${NC}"
