#!/bin/bash
# ==================================================
#  Custom Debian-Based OS Builder Script
#  Author: 0x
#  Description:
#    This script automates building a Debian remix ISO
#    with custom branding, splash screen, boot menu,
#    and user-selected tools.
# ==================================================

set -e

echo "====================================="
echo "      Debian Custom OS Builder       "
echo "          by 0x (github.com/0xghazali)      "
echo "====================================="
echo ""

# --- Ask for OS Name ---
read -p "Enter your custom OS name (e.g., 0xOS): " OS_NAME
BUILD_NAME="${OS_NAME,,}.iso"   # lowercase filename

# --- Ask for Tools ---
echo ""
echo "Enter a list of tools/packages you want to include (space separated):"
echo "Example: nmap git wireshark aircrack-ng hydra"
read -p "Packages: " USER_PACKAGES

echo ""
echo "[*] Your OS will be called: $OS_NAME"
echo "[*] Packages to include: $USER_PACKAGES"
echo ""

# --- Clean old build ---
echo "[*] Cleaning old build..."
sudo lb clean --purge || true

# --- Configure live-build ---
echo "[*] Configuring live-build..."
sudo lb config \
  --distribution bookworm \
  --debian-installer live \
  --binary-images iso-hybrid \
  --archive-areas "main contrib non-free-firmware"

# --- Branding Files ---
echo "[*] Setting up branding..."
mkdir -p config/bootloaders/isolinux
mkdir -p config/package-lists

# --- Splash Screen ---
cat > config/bootloaders/isolinux/splash.svg <<EOF
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg
   width="800"
   height="600"
   viewBox="0 0 800 600"
   version="1.1"
   xmlns="http://www.w3.org/2000/svg">

  <rect width="100%" height="100%" fill="#000000"/>

  <text
     x="50%"
     y="40%"
     font-family="monospace"
     font-size="64"
     fill="#00FF00"
     text-anchor="middle">
    $OS_NAME
  </text>

  <text
     x="50%"
     y="55%"
     font-family="monospace"
     font-size="28"
     fill="#FFFFFF"
     text-anchor="middle">
    Powered by Debian 12
  </text>

  <text
     x="50%"
     y="90%"
     font-family="monospace"
     font-size="20"
     fill="#888888"
     text-anchor="middle">
    Boot Menu - Use Arrow Keys to Select
  </text>
</svg>
EOF

# --- Boot Menu ---
cat > config/bootloaders/isolinux/stdmenu.cfg <<EOF
menu hshift 0
menu width 80
menu margin 0
menu title Boot Menu - $OS_NAME

label live
    menu label ^Live system ($OS_NAME)
    kernel /live/vmlinuz
    append initrd=/live/initrd.img boot=live

label install
    menu label ^Install $OS_NAME
    kernel /install/vmlinuz
    append initrd=/install/initrd.gz
EOF

# --- Packages ---
echo "[*] Creating package list..."
cat > config/package-lists/${OS_NAME}.list.chroot <<EOF
$USER_PACKAGES
EOF

# --- Build ISO ---
echo "[*] Building ISO..."
sudo lb build

# --- Rename ISO ---
if [ -f live-image-amd64.hybrid.iso ]; then
    mv -f live-image-amd64.hybrid.iso "$BUILD_NAME"
    echo "[+] Build complete: $BUILD_NAME"
else
    echo "[!] Build failed - ISO not created."
    exit 1
fi

echo ""
echo "====================================="
echo "     Build Finished Successfully     "
echo "     Your custom OS: $BUILD_NAME     "
echo "         Script by: 0x               "
echo "====================================="
