#!/bin/bash
# =============================================================
#   clone-to-usb.sh
#   Clones your entire running Linux system to a USB drive
#   as a bootable live ISO with a built-in installer.
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
echo "  ║   Clones your live system to USB      ║"
echo "  ╚═══════════════════════════════════════╝"
echo -e "${NC}"

# ---------------------------------------------------------------
# DEPENDENCY CHECK
# ---------------------------------------------------------------
header "Checking dependencies"
DEPS=(squashfs-tools grub-efi-amd64-bin grub-pc-bin xorriso mtools rsync)
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

# Check live-boot
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
lsblk -o NAME,SIZE,TYPE,TRAN,VENDOR,MODEL | grep -E "disk|NAME"
echo ""

warn "ALL DATA ON THE SELECTED USB WILL BE ERASED"
echo ""
read -rp "Enter USB device (e.g. /dev/sdb): " USB

# Validate
[[ -z "$USB" ]] && error "No device specified"
[[ ! -b "$USB" ]] && error "$USB is not a valid block device"

# Safety check — make sure it's not the system disk
SYSTEM_DISK=$(df / | tail -1 | awk '{print $1}' | sed 's/[0-9]*$//')
if [[ "$USB" == "$SYSTEM_DISK"* ]]; then
    error "That looks like your system disk ($SYSTEM_DISK). Aborting."
fi

USB_SIZE=$(lsblk -bno SIZE "$USB" | head -1)
USB_SIZE_GB=$(echo "scale=1; $USB_SIZE / 1073741824" | bc)
USED_SPACE=$(df -B1 --total / | grep total | awk '{print $3}')
USED_GB=$(echo "scale=1; $USED_SPACE / 1073741824" | bc)

echo ""
info "USB size:       ${USB_SIZE_GB} GB"
info "System used:    ${USED_GB} GB"
echo ""

if (( $(echo "$USED_SPACE > $USB_SIZE" | bc -l) )); then
    error "Your system (${USED_GB}GB used) is larger than the USB (${USB_SIZE_GB}GB). Use a bigger USB."
fi

echo -e "${RED}${BOLD}WARNING: This will completely erase $USB (${USB_SIZE_GB}GB)${NC}"
read -rp "Type YES to continue: " CONFIRM
[[ "$CONFIRM" != "YES" ]] && echo "Aborted." && exit 0

# ---------------------------------------------------------------
# WORK DIRECTORY
# ---------------------------------------------------------------
WORK_DIR="/tmp/usb-clone"
ISO_DIR="$WORK_DIR/iso"
mkdir -p "$ISO_DIR"/{boot/grub,live,EFI/BOOT}
info "Working directory: $WORK_DIR"

# ---------------------------------------------------------------
# BAKE IN INSTALLER SCRIPT
# ---------------------------------------------------------------
header "Preparing installer script"

cat > /usr/local/bin/install-to-disk << 'INSTALLER'
#!/bin/bash
# =====================================================
#   install-to-disk — run this in the live session
#   to install the system to a local disk
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

DISK_SIZE=$(lsblk -bno SIZE "$DISK" | head -1)
DISK_SIZE_GB=$(echo "scale=1; $DISK_SIZE / 1073741824" | bc)

echo ""
warn "This will ERASE $DISK (${DISK_SIZE_GB}GB) and install the system"
read -rp "Type YES to continue: " CONFIRM
[[ "$CONFIRM" != "YES" ]] && echo "Aborted." && exit 0

# Partition
info "Partitioning $DISK..."
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart ESP fat32 1MiB 512MiB
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart primary ext4 512MiB 100%
partprobe "$DISK"
sleep 2

# Determine partition names (handles /dev/sda1 and /dev/nvme0n1p1)
if [[ "$DISK" =~ nvme|mmcblk ]]; then
    EFI_PART="${DISK}p1"
    ROOT_PART="${DISK}p2"
else
    EFI_PART="${DISK}1"
    ROOT_PART="${DISK}2"
fi

# Format
info "Formatting partitions..."
mkfs.fat -F32 "$EFI_PART"
mkfs.ext4 -L linux-root "$ROOT_PART"

# Mount
info "Mounting..."
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot/efi
mount "$EFI_PART" /mnt/boot/efi

# Copy system
info "Copying system to disk (this will take a while)..."
rsync -aAXHv \
    --exclude="/proc/*" \
    --exclude="/sys/*" \
    --exclude="/dev/*" \
    --exclude="/tmp/*" \
    --exclude="/run/*" \
    --exclude="/mnt/*" \
    --exclude="/media/*" \
    --exclude="/lost+found" \
    / /mnt/

# Generate fstab
info "Writing fstab..."
ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART")
EFI_UUID=$(blkid -s UUID -o value "$EFI_PART")
cat > /mnt/etc/fstab << FSTAB
# <file system>  <mount point>  <type>  <options>          <dump>  <pass>
UUID=$ROOT_UUID  /              ext4    errors=remount-ro  0       1
UUID=$EFI_UUID   /boot/efi      vfat    umask=0077         0       1
FSTAB

# Bootloader
info "Installing GRUB bootloader..."
mount --bind /dev  /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys  /mnt/sys
mount --bind /run  /mnt/run

chroot /mnt grub-install \
    --target=x86_64-efi \
    --efi-directory=/boot/efi \
    --bootloader-id=linux \
    --recheck

chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# Cleanup
umount /mnt/dev /mnt/proc /mnt/sys /mnt/run
umount /mnt/boot/efi
umount /mnt

echo ""
success "Installation complete!"
info "Remove the USB and reboot into your new system."
INSTALLER

chmod +x /usr/local/bin/install-to-disk
success "Installer script baked in at /usr/local/bin/install-to-disk"

# ---------------------------------------------------------------
# SQUASH THE SYSTEM
# ---------------------------------------------------------------
header "Squashing filesystem (this will take a while...)"
info "Compressing your system with xz — go get a coffee ☕"
echo ""

mksquashfs / "$ISO_DIR/live/filesystem.squashfs" \
    -e boot \
    -e proc \
    -e sys \
    -e dev \
    -e tmp \
    -e run \
    -e mnt \
    -e media \
    -e lost+found \
    -e "tmp/usb-clone" \
    -comp xz \
    -Xbcj x86 \
    -b 1M \
    -wildcards

SQUASH_SIZE=$(du -sh "$ISO_DIR/live/filesystem.squashfs" | cut -f1)
success "Squashfs created ($SQUASH_SIZE)"

# ---------------------------------------------------------------
# KERNEL & INITRAMFS
# ---------------------------------------------------------------
header "Copying kernel and initramfs"

KERNEL_VER=$(uname -r)
info "Kernel version: $KERNEL_VER"

# Rebuild initramfs with live hooks
update-initramfs -u -k "$KERNEL_VER" 2>/dev/null || true

cp /boot/vmlinuz-"$KERNEL_VER" "$ISO_DIR/boot/vmlinuz"

# Try both naming conventions
if [[ -f /boot/initrd.img-"$KERNEL_VER" ]]; then
    cp /boot/initrd.img-"$KERNEL_VER" "$ISO_DIR/boot/initrd"
elif [[ -f /boot/initramfs-"$KERNEL_VER".img ]]; then
    cp /boot/initramfs-"$KERNEL_VER".img "$ISO_DIR/boot/initrd"
else
    error "Could not find initramfs for kernel $KERNEL_VER"
fi

success "Kernel and initramfs copied"

# ---------------------------------------------------------------
# GRUB CONFIG
# ---------------------------------------------------------------
header "Writing GRUB config"

HOSTNAME=$(hostname)

cat > "$ISO_DIR/boot/grub/grub.cfg" << EOF
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
# BUILD ISO
# ---------------------------------------------------------------
header "Building ISO"

ISO_PATH="$WORK_DIR/system-clone.iso"

grub-mkrescue \
    -o "$ISO_PATH" \
    "$ISO_DIR" \
    -- \
    -volid "LINUX_CLONE" \
    -joliet \
    -rational-rock 2>/dev/null

ISO_SIZE=$(du -sh "$ISO_PATH" | cut -f1)
success "ISO built ($ISO_SIZE): $ISO_PATH"

# ---------------------------------------------------------------
# WRITE TO USB
# ---------------------------------------------------------------
header "Writing ISO to USB ($USB)"

# Unmount any mounted partitions on the USB
for part in "$USB"*; do
    umount "$part" 2>/dev/null || true
done

info "Writing to $USB — do not remove the drive..."
dd if="$ISO_PATH" of="$USB" bs=4M status=progress oflag=sync
sync

success "Done! ISO written to $USB"

# ---------------------------------------------------------------
# DONE
# ---------------------------------------------------------------
echo ""
echo -e "${BOLD}${GREEN}"
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║              Clone Complete!                 ║"
echo "  ╠══════════════════════════════════════════════╣"
echo "  ║  Your USB is ready. To use it:               ║"
echo "  ║                                              ║"
echo "  ║  1. Boot the target machine from the USB     ║"
echo "  ║  2. Your desktop will load as normal         ║"
echo "  ║  3. Open a terminal and run:                 ║"
echo "  ║                                              ║"
echo "  ║     sudo install-to-disk                     ║"
echo "  ║                                              ║"
echo "  ║  4. Follow the prompts to install            ║"
echo "  ╚══════════════════════════════════════════════╝"
echo -e "${NC}"

# Offer to keep or remove the ISO
echo ""
read -rp "Keep the ISO file at $ISO_PATH? (y/n): " KEEP_ISO
if [[ "$KEEP_ISO" != "y" ]]; then
    rm -rf "$WORK_DIR"
    info "Work directory cleaned up"
else
    info "ISO saved at: $ISO_PATH"
fi
