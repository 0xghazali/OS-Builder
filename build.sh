#!/usr/bin/env bash
# ==============================================================
#  Universal Debian Live ISO Builder (VIP)
#  Creates a branded Debian-based Live/Install ISO with GUI
#  Author / Signature: 0x
#  NOTE: Run this on a Debian-based build machine (Debian 12 Bookworm recommended)
# ==============================================================

set -euo pipefail
IFS=$'\n\t'

# -------------------------
# Configuration / Defaults
# -------------------------
LB_REQUIRED_PKGS=(live-build syslinux-utils xorriso squashfs-tools debootstrap git)
BUILD_DIR="$(pwd)"
WORK_DIR="$BUILD_DIR/work"            # not used for mkarchiso, but reserved
OUT_ISO_DEFAULT_PREFIX="live-image-amd64.hybrid.iso"
DEFAULT_THEME_PKGS=(arc-theme papirus-icon-theme)
GUI_PKGS=(xfce4 xfce4-goodies lightdm task-xfce-desktop)
VM_PKGS=(open-vm-tools virtualbox-guest-x11 qemu-guest-agent)
NETWORK_PKGS=(network-manager firmware-linux firmware-misc-nonfree)
# Build timestamp suffix (helps avoid cache issues)
TS="$(date +%Y%m%d%H%M%S)"

# -------------------------
# Helper functions
# -------------------------
echo_header(){ printf "\n\n==== %s ====\n" "$1"; }
fatal(){ echo "FATAL: $*" >&2; exit 1; }
confirm(){ # usage: confirm "Message"
  read -r -p "$1 [y/N]: " REPLY
  case "$REPLY" in
    [Yy]|[Yy][Ee][Ss]) return 0 ;;
    *) return 1 ;;
  esac
}

# Check we are on Debian-ish system
if ! command -v apt >/dev/null 2>&1; then
  fatal "This script expects a Debian-based build system with 'apt'. Run it on Debian/Ubuntu."
fi

# -------------------------
# 1) Gather input from user
# -------------------------
echo_header "0x VIP ISO Builder"
echo "This script will build a Debian-based Live/Install ISO with GUI (XFCE) and user-selected tools."
echo "Make sure you are running on a Debian-based VM with internet and at least 20GB free disk."

read -r -p "Enter your custom OS name (example: 0xOS) : " OS_NAME_RAW
if [ -z "$OS_NAME_RAW" ]; then
  fatal "OS name cannot be empty."
fi
# sanitize for filenames (lowercase, remove spaces)
OS_NAME="$(echo "$OS_NAME_RAW" | tr '[:upper:]' '[:lower:]' | tr -s ' ' '-' )"
ISO_NAME="${OS_NAME}.iso"

echo ""
read -r -p "Enter packages/tools to include (space-separated), or leave empty for default: " USER_PACKAGES
# If user left empty, put a sensible default toolset (can be edited)
if [ -z "$USER_PACKAGES" ]; then
  USER_PACKAGES="nmap git curl wget htop net-tools"
fi

echo ""
echo "Summary:"
echo "  OS Name: $OS_NAME_RAW  (file: $ISO_NAME)"
echo "  Packages to embed: $USER_PACKAGES"
echo ""

confirm "Proceed with these settings?" || { echo "Aborted by user."; exit 0; }

# -------------------------
# 2) Ensure dependencies (live-build etc.)
# -------------------------
echo_header "Checking build dependencies (live-build etc.)"
MISSING=()
for p in "${LB_REQUIRED_PKGS[@]}"; do
  if ! dpkg -s "$p" >/dev/null 2>&1; then
    MISSING+=("$p")
  fi
done

# Also ensure sudo exists
if ! command -v sudo >/dev/null 2>&1; then
  fatal "sudo is required. Install it and re-run this script."
fi

if [ ${#MISSING[@]} -ne 0 ]; then
  echo "Missing packages required for build: ${MISSING[*]}"
  if confirm "Install missing packages now using apt? (requires sudo)"; then
    sudo apt update
    sudo apt install -y "${MISSING[@]}"
  else
    fatal "Please install required packages and re-run."
  fi
else
  echo "All required build packages are present."
fi

# -------------------------
# 3) Prepare build workspace
# -------------------------
echo_header "Preparing workspace"
mkdir -p "$BUILD_DIR/config/bootloaders/isolinux"
mkdir -p "$BUILD_DIR/config/package-lists"
mkdir -p "$BUILD_DIR/config/includes.chroot/usr/share/backgrounds/0xos"
mkdir -p "$BUILD_DIR/out"

# Clean any previous live-build config if user wants
if [ -d "$BUILD_DIR/config" ] && [ -f "$BUILD_DIR/config" ] && confirm "Do you want to purge previous live-build config first?"; then
  sudo lb clean --purge || true
fi

# -------------------------
# 4) Create branding: splash.svg
# -------------------------
echo_header "Writing splash.svg (boot splash)"
cat > "$BUILD_DIR/config/bootloaders/isolinux/splash.svg" <<EOF
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg width="800" height="600" viewBox="0 0 800 600" xmlns="http://www.w3.org/2000/svg">
  <rect width="100%" height="100%" fill="#0b0b0b"/>
  <text x="50%" y="38%" font-family="monospace" font-size="76" fill="#00ff66" text-anchor="middle" font-weight="bold">$OS_NAME_RAW</text>
  <text x="50%" y="50%" font-family="monospace" font-size="22" fill="#cccccc" text-anchor="middle">Custom Debian live image</text>
  <text x="50%" y="88%" font-family="monospace" font-size="16" fill="#666666" text-anchor="middle">Built by 0x • $(date +%Y)</text>
</svg>
EOF

# small default wallpaper to include in installed system (simple SVG -> PNG conversion not required, but we include SVG)
cat > "$BUILD_DIR/config/includes.chroot/usr/share/backgrounds/0xos/0x-wallpaper.svg" <<EOF
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg width="1920" height="1080" xmlns="http://www.w3.org/2000/svg">
  <rect width="100%" height="100%" fill="#0b0b0b"/>
  <text x="50%" y="50%" font-family="monospace" font-size="160" fill="#00ff66" text-anchor="middle" font-weight="bold">$OS_NAME_RAW</text>
</svg>
EOF

# -------------------------
# 5) Create boot menu (stdmenu.cfg)
# -------------------------
echo_header "Writing boot menu (stdmenu.cfg)"
cat > "$BUILD_DIR/config/bootloaders/isolinux/stdmenu.cfg" <<EOF
menu hshift 0
menu width 80
menu margin 0
menu title Boot Menu - $OS_NAME_RAW

label live
    menu label ^Live system ($OS_NAME_RAW)
    kernel /live/vmlinuz
    append initrd=/live/initrd.img boot=live quiet splash

label install
    menu label ^Install $OS_NAME_RAW
    kernel /install/vmlinuz
    append initrd=/install/initrd.gz quiet
EOF

# -------------------------
# 6) Create package list (includes GUI, VM support, user tools)
# -------------------------
echo_header "Creating package list"
PACKAGE_LIST_FILE="$BUILD_DIR/config/package-lists/${OS_NAME}.list.chroot"
cat > "$PACKAGE_LIST_FILE" <<EOF
# Desktop environment + display manager
${GUI_PKGS[@]}

# Themes and icons for nicer look
${DEFAULT_THEME_PKGS[@]}

# Networking and drivers
${NETWORK_PKGS[@]}

# VM & guest support (VMware/VirtualBox/QEMU)
${VM_PKGS[@]}

# User requested tools
$USER_PACKAGES
EOF

echo "Package list written to: $PACKAGE_LIST_FILE"
echo ""
echo "Preview (first 30 lines):"
sed -n '1,30p' "$PACKAGE_LIST_FILE"

# -------------------------
# 7) Configure live-build
# -------------------------
echo_header "Running lb config (this creates config/ structure live-build expects)"
sudo lb config \
  --distribution bookworm \
  --debian-installer live \
  --binary-images iso-hybrid \
  --archive-areas "main contrib non-free non-free-firmware" \
  --mirror-bootstrap "http://deb.debian.org/debian" \
  --mirror-binary "http://deb.debian.org/debian"

# Ensure our boot overrides are used (copy just in case)
mkdir -p config/bootloaders/isolinux
cp -f "$BUILD_DIR/config/bootloaders/isolinux/splash.svg" config/bootloaders/isolinux/splash.svg
cp -f "$BUILD_DIR/config/bootloaders/isolinux/stdmenu.cfg" config/bootloaders/isolinux/stdmenu.cfg

# include wallpaper (installed OS will have it available)
mkdir -p config/includes.chroot/usr/share/backgrounds/0xos
cp -f "$BUILD_DIR/config/includes.chroot/usr/share/backgrounds/0xos/0x-wallpaper.svg" config/includes.chroot/usr/share/backgrounds/0xos/0x-wallpaper.svg

# -------------------------
# 8) (Optional) Provide a default /etc/hostname and /etc/motd for the live system
# -------------------------
echo_header "Adding default hostname and MOTD"
echo "$OS_NAME_RAW" | sudo tee config/includes.chroot/etc/hostname >/dev/null
sudo tee config/includes.chroot/etc/motd >/dev/null <<EOF
Welcome to $OS_NAME_RAW
Built with 0x's VIP Builder
Authorized use only
EOF

# Ensure permission correctness
sudo chmod 644 config/includes.chroot/etc/motd || true
sudo chmod 644 config/includes.chroot/etc/hostname || true

# -------------------------
# 9) Start build
# -------------------------
echo_header "Starting the ISO build. This may take a while (downloads + packaging)."
echo "Tip: If you have slow internet, sit back — first build is the slowest."

# Run lb build
sudo lb build

# -------------------------
# 10) Rename output ISO to user-friendly name
# -------------------------
echo_header "Finalizing output"
if [ -f live-image-amd64.hybrid.iso ]; then
  TARGET="$BUILD_DIR/out/${ISO_NAME}"
  mv -f live-image-amd64.hybrid.iso "$TARGET"
  echo "[+] Success: ISO built -> $TARGET"
  echo "[+] Timestamp: $TS"
else
  echo "[-] Build finished but expected ISO not found. Listing files for debug:"
  ls -lah
  fatal "ISO not found. Check live-build logs above."
fi

# -------------------------
# 11) Summary & next steps
# -------------------------
echo ""
echo "====================================="
echo "  Build complete: $ISO_NAME"
echo "  Location     : $TARGET"
echo ""
echo "  Next steps:"
echo "   - Test in VM (VMware/VirtualBox): attach the ISO and boot"
echo "   - For USB: dd if=$TARGET of=/dev/sdX bs=4M status=progress && sync"
echo "   - If you want persistence on USB, create a partition labelled 'persistence' and add '/ union' in persistence.conf"
echo ""
echo "  Tip: If some packages failed (404/unable to locate), run 'sudo apt update' inside the live system or adjust mirror in the script and rebuild."
echo ""
echo "  Script / builder signature: 0x"
echo "====================================="
