#!/usr/bin/env bash

# Chaotic-AUR Setup Script for Arch Linux / EndeavourOS
# Saves time by automating:
# - importing signing key
# - installing chaotic keyring + mirrorlist
# - enabling repo in pacman.conf

set -e

KEY="3056513887B78AEB"
KEYSERVER="keyserver.ubuntu.com"

echo "======================================"
echo "   Chaotic-AUR Repository Installer   "
echo "======================================"
echo

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "Please run this script as root:"
    echo "sudo $0"
    exit 1
fi

echo "[1/5] Initializing pacman keys..."
pacman-key --init
pacman-key --populate archlinux

echo
echo "[2/5] Retrieving Chaotic-AUR signing key..."
pacman-key --recv-key "$KEY" --keyserver "$KEYSERVER"

echo
echo "[3/5] Locally signing key..."
pacman-key --lsign-key "$KEY"

echo
echo "[4/5] Installing chaotic-keyring and chaotic-mirrorlist..."

pacman -U --noconfirm \
    "https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst" \
    "https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst"

echo
echo "[5/5] Enabling Chaotic-AUR repository..."

if ! grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
    cat <<EOF >> /etc/pacman.conf

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF
    echo "Repository added to /etc/pacman.conf"
else
    echo "Chaotic-AUR repository already exists in pacman.conf"
fi

echo
echo "Refreshing package databases..."
pacman -Sy

echo
echo "======================================"
echo " Chaotic-AUR successfully installed! "
echo "======================================"
echo
echo "You can now install packages like:"
echo "  pacman -S paru"
echo "  pacman -S google-chrome"
echo
