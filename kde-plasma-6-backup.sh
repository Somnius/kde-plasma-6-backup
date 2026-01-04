#!/bin/bash

###############################################################################
# KDE Plasma 6 Backup Script
# 
# This script backs up all KDE Plasma 6 settings including:
# - Themes, decorations, colors, icons
# - Keyboard shortcuts, language, regional settings
# - Window manager settings, panel configurations
# - User-installed themes/icons/color schemes
#
# Usage: ./kde-plasma-6-backup.sh [OPTIONS]
#   --output-dir DIR    Specify backup directory (default: ./backup-YYYYMMDD-HHMMSS)
#   --no-compress       Don't compress the backup
#   --include-packages  Include package list for reinstallation
###############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detect package manager
detect_package_manager() {
    if command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    elif command -v apt >/dev/null 2>&1; then
        echo "apt"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v yum >/dev/null 2>&1; then
        echo "yum"
    elif command -v zypper >/dev/null 2>&1; then
        echo "zypper"
    elif command -v emerge >/dev/null 2>&1; then
        echo "emerge"
    else
        echo "unknown"
    fi
}

# Get package list command for package manager
get_package_list_command() {
    local pkgmgr="$1"
    case "$pkgmgr" in
        pacman)
            echo "pacman -Q | grep -E '(plasma|kde)' | grep -E '(theme|icon|color|desktop)' | awk '{print \$1}'"
            ;;
        apt)
            echo "dpkg -l | grep -E '(plasma|kde)' | grep -E '(theme|icon|color|desktop)' | awk '{print \$2}'"
            ;;
        dnf|yum)
            echo "rpm -qa | grep -E '(plasma|kde)' | grep -E '(theme|icon|color|desktop)'"
            ;;
        zypper)
            echo "zypper search --installed-only | grep -E '(plasma|kde)' | grep -E '(theme|icon|color|desktop)' | awk '{print \$3}'"
            ;;
        emerge)
            echo "qlist -I | grep -E '(plasma|kde)' | grep -E '(theme|icon|color|desktop)' | sed 's/.*\\///'"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Get install command hint for package manager
get_install_hint() {
    local pkgmgr="$1"
    case "$pkgmgr" in
        pacman)
            echo "sudo pacman -S"
            ;;
        apt)
            echo "sudo apt install"
            ;;
        dnf)
            echo "sudo dnf install"
            ;;
        yum)
            echo "sudo yum install"
            ;;
        zypper)
            echo "sudo zypper install"
            ;;
        emerge)
            echo "sudo emerge"
            ;;
        *)
            echo "your package manager"
            ;;
    esac
}

# Default values
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_BASE_DIR="${SCRIPT_DIR}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="${BACKUP_BASE_DIR}/backup-${TIMESTAMP}"
COMPRESS=true
INCLUDE_PACKAGES=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --output-dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        --no-compress)
            COMPRESS=false
            shift
            ;;
        --no-packages)
            INCLUDE_PACKAGES=false
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --output-dir DIR    Specify backup directory"
            echo "  --no-compress       Don't compress the backup"
            echo "  --no-packages       Don't include package list"
            echo "  -h, --help          Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}Error: This script should not be run as root${NC}"
    exit 1
fi

echo -e "${BLUE}=== KDE Plasma 6 Backup Script ===${NC}"
echo -e "${BLUE}Backup directory: ${BACKUP_DIR}${NC}"
echo ""

# Create backup directory structure
mkdir -p "${BACKUP_DIR}"/{config,local-share,metadata}

# Function to backup a directory or file
backup_item() {
    local source="$1"
    local dest="$2"
    local description="$3"
    
    if [[ -e "$source" ]]; then
        echo -e "${GREEN}Backing up: ${description}${NC}"
        mkdir -p "$(dirname "$dest")"
        cp -r "$source" "$dest" 2>/dev/null || {
            echo -e "${YELLOW}Warning: Could not backup ${source}${NC}"
            return 1
        }
        return 0
    else
        echo -e "${YELLOW}Skipping (not found): ${description}${NC}"
        return 1
    fi
}

# Function to backup a config file
backup_config() {
    local filename="$1"
    local description="${2:-$filename}"
    backup_item "${HOME}/.config/${filename}" "${BACKUP_DIR}/config/${filename}" "$description"
}

echo -e "${BLUE}--- Backing up configuration files ---${NC}"

# Core KDE Plasma configuration files
backup_config "kdeglobals" "Global KDE settings (themes, colors, fonts)"
backup_config "plasmarc" "Plasma theme and wallpaper settings"
backup_config "plasmashellrc" "Plasma shell configuration"
backup_config "plasma-org.kde.plasma.desktop-appletsrc" "Panel and desktop applets configuration"
backup_config "plasma-localerc" "Regional and language settings"
backup_config "plasma-workspace" "Workspace environment settings"
backup_config "plasmanotifyrc" "Notification settings"

# Window manager (KWin)
backup_config "kwinrc" "Window manager settings"
backup_config "kwinrulesrc" "Window rules"
backup_config "kwinoutputconfig.json" "Display/output configuration"

# Keyboard and input
backup_config "kglobalshortcutsrc" "Global keyboard shortcuts"
backup_config "kxkbrc" "Keyboard layout and switcher settings"
backup_config "kcminputrc" "Input device settings"

# KDE services
backup_config "kded6rc" "KDE daemon configuration (Plasma 6)"
backup_config "kded5rc" "KDE daemon configuration (legacy)"

# Activity manager
backup_config "kactivitymanagerdrc" "Activity manager settings"
backup_config "kactivitymanagerd-statsrc" "Activity manager statistics"

# Desktop portal
backup_config "xdg-desktop-portal-kderc" "Desktop portal settings (file dialog sizes, etc.)"

# KDE Connect
backup_item "${HOME}/.config/kdeconnect" "${BACKUP_DIR}/config/kdeconnect" "KDE Connect settings"

# KDE defaults (if they exist)
if [[ -d "${HOME}/.config/kdedefaults" ]]; then
    backup_item "${HOME}/.config/kdedefaults" "${BACKUP_DIR}/config/kdedefaults" "KDE default settings (includes ksplashrc)"
fi

# KDE.org application settings
if [[ -d "${HOME}/.config/kde.org" ]]; then
    backup_item "${HOME}/.config/kde.org" "${BACKUP_DIR}/config/kde.org" "KDE application settings"
fi

# Autostart entries
if [[ -d "${HOME}/.config/autostart" ]]; then
    backup_item "${HOME}/.config/autostart" "${BACKUP_DIR}/config/autostart" "Autostart applications"
fi

echo ""
echo -e "${BLUE}--- Backing up user-installed themes, icons, and resources ---${NC}"

# Plasma themes (desktop themes)
if [[ -d "${HOME}/.local/share/plasma/desktoptheme" ]]; then
    backup_item "${HOME}/.local/share/plasma/desktoptheme" \
                "${BACKUP_DIR}/local-share/plasma/desktoptheme" \
                "Plasma desktop themes"
fi

# Look and feel packages
if [[ -d "${HOME}/.local/share/plasma/look-and-feel" ]]; then
    backup_item "${HOME}/.local/share/plasma/look-and-feel" \
                "${BACKUP_DIR}/local-share/plasma/look-and-feel" \
                "Plasma look-and-feel packages"
fi

# Color schemes
if [[ -d "${HOME}/.local/share/color-schemes" ]]; then
    backup_item "${HOME}/.local/share/color-schemes" \
                "${BACKUP_DIR}/local-share/color-schemes" \
                "Color schemes"
fi

# Icon themes
if [[ -d "${HOME}/.local/share/icons" ]]; then
    backup_item "${HOME}/.local/share/icons" \
                "${BACKUP_DIR}/local-share/icons" \
                "Icon themes"
fi

# Aurorae window decorations
if [[ -d "${HOME}/.local/share/aurorae/themes" ]]; then
    backup_item "${HOME}/.local/share/aurorae/themes" \
                "${BACKUP_DIR}/local-share/aurorae/themes" \
                "Aurorae window decorations"
fi

# Wallpapers
if [[ -d "${HOME}/.local/share/wallpapers" ]]; then
    backup_item "${HOME}/.local/share/wallpapers" \
                "${BACKUP_DIR}/local-share/wallpapers" \
                "User wallpapers"
fi

# KDE6 specific data
if [[ -d "${HOME}/.local/share/kded6" ]]; then
    backup_item "${HOME}/.local/share/kded6" \
                "${BACKUP_DIR}/local-share/kded6" \
                "KDE6 daemon data"
fi

# KNewStuff registries (downloaded content metadata)
if [[ -d "${HOME}/.local/share/knewstuff3" ]]; then
    backup_item "${HOME}/.local/share/knewstuff3" \
                "${BACKUP_DIR}/local-share/knewstuff3" \
                "KNewStuff download registries"
fi

echo ""
echo -e "${BLUE}--- Creating metadata ---${NC}"

# Save system information
{
    echo "Backup created: $(date)"
    echo "User: $(whoami)"
    echo "Hostname: $(hostname)"
    echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2 || echo 'Unknown')"
    echo "KDE Plasma version: $(plasmashell --version 2>/dev/null | head -1 || echo 'Unknown')"
    echo "KWin version: $(kwin --version 2>/dev/null | head -1 || echo 'Unknown')"
    echo ""
    echo "Hardware information:"
    echo "  CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs || echo 'Unknown')"
    echo "  GPU: $(lspci | grep -i vga | cut -d: -f3 | xargs || echo 'Unknown')"
    echo "  Displays: $(xrandr --listmonitors 2>/dev/null | grep -c 'Monitors:' || echo 'Unknown')"
} > "${BACKUP_DIR}/metadata/system-info.txt"

# Extract current theme/icon/color scheme settings
if [[ -f "${HOME}/.config/kdeglobals" ]]; then
    echo ""
    echo -e "${BLUE}Current settings:${NC}"
    grep -E "^(Theme|ColorScheme|IconTheme|Font)" "${HOME}/.config/kdeglobals" 2>/dev/null | \
        tee "${BACKUP_DIR}/metadata/current-theme-settings.txt" || true
fi

if [[ -f "${HOME}/.config/plasmarc" ]]; then
    grep -E "^(name|Theme)" "${HOME}/.config/plasmarc" 2>/dev/null | \
        tee -a "${BACKUP_DIR}/metadata/current-theme-settings.txt" || true
fi

# Create package list if requested
if [[ "$INCLUDE_PACKAGES" == true ]]; then
    echo ""
    echo -e "${BLUE}--- Creating package list ---${NC}"
    
    # Detect package manager
    PKG_MGR=$(detect_package_manager)
    INSTALL_HINT=$(get_install_hint "$PKG_MGR")
    LIST_CMD=$(get_package_list_command "$PKG_MGR")
    
    # List installed KDE/Plasma theme/icon packages
    {
        echo "# KDE Plasma theme and icon packages"
        echo "# Package manager: ${PKG_MGR}"
        echo "# Install with: ${INSTALL_HINT} \$(grep -v '^#' kde-packages.txt)"
        echo "# Note: Package names may differ between distributions"
        echo ""
        if [[ "$PKG_MGR" != "unknown" ]]; then
            eval "$LIST_CMD" | sort -u
        else
            echo "# Could not detect package manager - package list not generated"
        fi
    } > "${BACKUP_DIR}/metadata/kde-packages.txt" 2>/dev/null || true
    
    if [[ "$PKG_MGR" != "unknown" ]]; then
        echo -e "${GREEN}Package list saved to metadata/kde-packages.txt (${PKG_MGR})${NC}"
    else
        echo -e "${YELLOW}Warning: Could not detect package manager - package list not generated${NC}"
    fi
fi

# Create a manifest of all backed up items
echo ""
echo -e "${BLUE}--- Creating backup manifest ---${NC}"
{
    echo "KDE Plasma 6 Backup Manifest"
    echo "Created: $(date)"
    echo ""
    echo "=== Configuration Files ==="
    find "${BACKUP_DIR}/config" -type f 2>/dev/null | sed "s|${BACKUP_DIR}/||" | sort
    echo ""
    echo "=== User Resources ==="
    find "${BACKUP_DIR}/local-share" -type f 2>/dev/null | sed "s|${BACKUP_DIR}/||" | sort
} > "${BACKUP_DIR}/metadata/manifest.txt"

echo -e "${GREEN}Manifest saved to metadata/manifest.txt${NC}"

# Compress if requested
if [[ "$COMPRESS" == true ]]; then
    echo ""
    echo -e "${BLUE}--- Compressing backup ---${NC}"
    cd "${BACKUP_BASE_DIR}"
    tar -czf "backup-${TIMESTAMP}.tar.gz" "backup-${TIMESTAMP}"
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Backup compressed to: backup-${TIMESTAMP}.tar.gz${NC}"
        echo -e "${YELLOW}You can remove the uncompressed directory if desired${NC}"
    else
        echo -e "${RED}Warning: Compression failed, keeping uncompressed backup${NC}"
    fi
fi

echo ""
echo -e "${GREEN}=== Backup completed successfully! ===${NC}"
echo -e "${BLUE}Backup location: ${BACKUP_DIR}${NC}"
if [[ "$COMPRESS" == true ]]; then
    echo -e "${BLUE}Compressed archive: ${BACKUP_BASE_DIR}/backup-${TIMESTAMP}.tar.gz${NC}"
fi
echo ""
echo -e "${YELLOW}To restore this backup, run:${NC}"
echo -e "${YELLOW}  ./kde-plasma-6 restore ${BACKUP_DIR}${NC}"

