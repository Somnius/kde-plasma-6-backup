#!/bin/bash

###############################################################################
# KDE Plasma 6 Restore Script
# 
# This script restores KDE Plasma 6 settings from a backup.
#
# Usage: ./kde-plasma-6-restore.sh BACKUP_DIR [OPTIONS]
#   --re-download-themes    Re-download themes/icons from repositories instead of restoring files
#   --skip-user-resources   Skip restoring user-installed themes/icons (only restore config)
#   --dry-run               Show what would be restored without making changes
###############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
RE_DOWNLOAD=false
SKIP_USER_RESOURCES=false
DRY_RUN=false
VALIDATE_ONLY=false
SKIP_DISPLAY_CONFIG=false

# Parse arguments
BACKUP_DIR=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --re-download-themes)
            RE_DOWNLOAD=true
            shift
            ;;
        --skip-user-resources)
            SKIP_USER_RESOURCES=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --validate-only)
            VALIDATE_ONLY=true
            DRY_RUN=true
            shift
            ;;
        --skip-display-config)
            SKIP_DISPLAY_CONFIG=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 BACKUP_DIR [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --re-download-themes    Re-download themes/icons from repositories"
            echo "  --skip-user-resources   Only restore config files, skip themes/icons"
            echo "  --skip-display-config   Skip display configuration (safe for different hardware)"
            echo "  --dry-run               Show what would be restored (no changes)"
            echo "  --validate-only         Validate backup integrity and compatibility"
            echo "  -h, --help              Show this help message"
            exit 0
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
        *)
            if [[ -z "$BACKUP_DIR" ]]; then
                BACKUP_DIR="$1"
            else
                echo -e "${RED}Multiple backup directories specified${NC}"
                exit 1
            fi
            shift
            ;;
    esac
done

# Check if backup directory is provided
if [[ -z "$BACKUP_DIR" ]]; then
    echo -e "${RED}Error: Backup directory not specified${NC}"
    echo "Usage: $0 BACKUP_DIR [OPTIONS]"
    exit 1
fi

# Handle compressed backups
if [[ -f "$BACKUP_DIR" ]] && [[ "$BACKUP_DIR" == *.tar.gz ]]; then
    echo -e "${BLUE}Detected compressed backup, extracting...${NC}"
    EXTRACT_DIR="${BACKUP_DIR%.tar.gz}"
    if [[ "$DRY_RUN" == false ]]; then
        mkdir -p "$EXTRACT_DIR"
        tar -xzf "$BACKUP_DIR" -C "$(dirname "$EXTRACT_DIR")"
        BACKUP_DIR="$EXTRACT_DIR"
    else
        echo -e "${YELLOW}[DRY RUN] Would extract $BACKUP_DIR to $EXTRACT_DIR${NC}"
        BACKUP_DIR="$EXTRACT_DIR"
    fi
fi

# Check if backup directory exists
if [[ ! -d "$BACKUP_DIR" ]]; then
    echo -e "${RED}Error: Backup directory not found: ${BACKUP_DIR}${NC}"
    exit 1
fi

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}Error: This script should not be run as root${NC}"
    exit 1
fi

echo -e "${BLUE}=== KDE Plasma 6 Restore Script ===${NC}"
echo -e "${BLUE}Backup directory: ${BACKUP_DIR}${NC}"
if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}[DRY RUN MODE - No changes will be made]${NC}"
fi
if [[ "$RE_DOWNLOAD" == true ]]; then
    echo -e "${YELLOW}Mode: Re-download themes/icons from repositories${NC}"
fi
if [[ "$SKIP_USER_RESOURCES" == true ]]; then
    echo -e "${YELLOW}Mode: Skipping user-installed resources${NC}"
fi
if [[ "$SKIP_DISPLAY_CONFIG" == true ]]; then
    echo -e "${YELLOW}Mode: Skipping display configuration (hardware-safe)${NC}"
fi
if [[ "$VALIDATE_ONLY" == true ]]; then
    echo -e "${YELLOW}Mode: Validation only - checking backup integrity${NC}"
fi
echo ""

# Validation function
validate_backup() {
    local errors=0
    local warnings=0
    
    echo -e "${BLUE}=== Validating Backup ===${NC}"
    
    # Check backup structure
    if [[ ! -d "${BACKUP_DIR}/config" ]] && [[ ! -d "${BACKUP_DIR}/local-share" ]]; then
        echo -e "${RED}ERROR: Invalid backup structure - missing config/ or local-share/${NC}"
        ((errors++))
    fi
    
    # Check for essential files
    local essential_files=("kdeglobals" "plasmarc")
    for file in "${essential_files[@]}"; do
        if [[ ! -f "${BACKUP_DIR}/config/${file}" ]]; then
            echo -e "${YELLOW}WARNING: Essential file missing: config/${file}${NC}"
            ((warnings++))
        fi
    done
    
    # Check metadata
    if [[ ! -f "${BACKUP_DIR}/metadata/system-info.txt" ]]; then
        echo -e "${YELLOW}WARNING: System info metadata missing${NC}"
        ((warnings++))
    fi
    
    # Check Plasma version compatibility
    if [[ -f "${BACKUP_DIR}/metadata/system-info.txt" ]]; then
        BACKUP_PLASMA_VERSION=$(grep -i "plasma version" "${BACKUP_DIR}/metadata/system-info.txt" 2>/dev/null | head -1 || echo "")
        CURRENT_PLASMA_VERSION=$(plasmashell --version 2>/dev/null | head -1 || echo "Unknown")
        
        if [[ -n "$BACKUP_PLASMA_VERSION" ]] && [[ -n "$CURRENT_PLASMA_VERSION" ]]; then
            echo -e "${BLUE}Backup Plasma version: ${BACKUP_PLASMA_VERSION}${NC}"
            echo -e "${BLUE}Current Plasma version: ${CURRENT_PLASMA_VERSION}${NC}"
            
            # Extract major version numbers
            BACKUP_MAJOR=$(echo "$BACKUP_PLASMA_VERSION" | grep -oE '[0-9]+\.[0-9]+' | cut -d. -f1 || echo "")
            CURRENT_MAJOR=$(echo "$CURRENT_PLASMA_VERSION" | grep -oE '[0-9]+\.[0-9]+' | cut -d. -f1 || echo "")
            
            if [[ -n "$BACKUP_MAJOR" ]] && [[ -n "$CURRENT_MAJOR" ]] && [[ "$BACKUP_MAJOR" != "$CURRENT_MAJOR" ]]; then
                echo -e "${RED}WARNING: Major version mismatch! Backup is from Plasma ${BACKUP_MAJOR}, current is ${CURRENT_MAJOR}${NC}"
                echo -e "${YELLOW}  Some settings may not be compatible${NC}"
                ((warnings++))
            fi
        fi
    fi
    
    # Check for hardware-specific files
    if [[ -f "${BACKUP_DIR}/config/kwinoutputconfig.json" ]]; then
        echo -e "${YELLOW}WARNING: Display configuration found (kwinoutputconfig.json)${NC}"
        echo -e "${YELLOW}  This is hardware-specific and may cause issues on different systems${NC}"
        echo -e "${YELLOW}  Consider using --skip-display-config if restoring on different hardware${NC}"
        ((warnings++))
    fi
    
    # Check autostart entries
    if [[ -d "${BACKUP_DIR}/config/autostart" ]]; then
        AUTOSTART_COUNT=$(find "${BACKUP_DIR}/config/autostart" -name "*.desktop" 2>/dev/null | wc -l)
        if [[ $AUTOSTART_COUNT -gt 0 ]]; then
            echo -e "${BLUE}Found ${AUTOSTART_COUNT} autostart entries${NC}"
            echo -e "${YELLOW}  Verify these applications exist on the target system${NC}"
            ((warnings++))
        fi
    fi
    
    # Check file permissions
    local permission_errors=0
    find "${BACKUP_DIR}/config" -type f 2>/dev/null | while read -r file; do
        if [[ ! -r "$file" ]]; then
            echo -e "${RED}ERROR: Cannot read file: ${file}${NC}"
            ((permission_errors++))
        fi
    done
    
    if [[ $permission_errors -gt 0 ]]; then
        ((errors += permission_errors))
    fi
    
    # Summary
    echo ""
    if [[ $errors -eq 0 ]] && [[ $warnings -eq 0 ]]; then
        echo -e "${GREEN}✓ Backup validation passed with no issues${NC}"
        return 0
    elif [[ $errors -eq 0 ]]; then
        echo -e "${YELLOW}✓ Backup validation passed with ${warnings} warning(s)${NC}"
        return 0
    else
        echo -e "${RED}✗ Backup validation failed with ${errors} error(s) and ${warnings} warning(s)${NC}"
        return 1
    fi
}

# Run validation
if ! validate_backup; then
    if [[ "$VALIDATE_ONLY" == true ]]; then
        exit 1
    else
        echo -e "${YELLOW}Validation found issues. Continue anyway? (y/n): ${NC}"
        read -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Restore cancelled."
            exit 1
        fi
    fi
fi

if [[ "$VALIDATE_ONLY" == true ]]; then
    echo ""
    echo -e "${GREEN}Validation complete. Use without --validate-only to perform restore.${NC}"
    exit 0
fi

# Function to restore a file or directory
restore_item() {
    local source="$1"
    local dest="$2"
    local description="$3"
    
    if [[ ! -e "$source" ]]; then
        echo -e "${YELLOW}Skipping (not in backup): ${description}${NC}"
        return 1
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${BLUE}[DRY RUN] Would restore: ${description}${NC}"
        echo -e "${BLUE}  From: ${source}${NC}"
        echo -e "${BLUE}  To: ${dest}${NC}"
        return 0
    fi
    
    echo -e "${GREEN}Restoring: ${description}${NC}"
    mkdir -p "$(dirname "$dest")"
    
    # Backup existing file if it exists
    if [[ -e "$dest" ]]; then
        mv "$dest" "${dest}.backup-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
    fi
    
    cp -r "$source" "$dest" 2>/dev/null || {
        echo -e "${RED}Error: Could not restore ${source}${NC}"
        return 1
    }
    return 0
}

# Function to restore a config file
restore_config() {
    local filename="$1"
    local description="${2:-$filename}"
    restore_item "${BACKUP_DIR}/config/${filename}" "${HOME}/.config/${filename}" "$description"
}

# Read current theme settings from backup
if [[ -f "${BACKUP_DIR}/metadata/current-theme-settings.txt" ]]; then
    echo -e "${BLUE}--- Backup theme settings ---${NC}"
    cat "${BACKUP_DIR}/metadata/current-theme-settings.txt"
    echo ""
fi

# Read system info
if [[ -f "${BACKUP_DIR}/metadata/system-info.txt" ]]; then
    echo -e "${BLUE}--- Backup information ---${NC}"
    cat "${BACKUP_DIR}/metadata/system-info.txt"
    echo ""
fi

if [[ "$DRY_RUN" == false ]]; then
    read -p "Continue with restore? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Restore cancelled."
        exit 0
    fi
fi

echo ""
echo -e "${BLUE}--- Restoring configuration files ---${NC}"

# Restore core configuration files
restore_config "kdeglobals" "Global KDE settings"
restore_config "plasmarc" "Plasma theme settings"
restore_config "plasmashellrc" "Plasma shell configuration"
restore_config "plasma-org.kde.plasma.desktop-appletsrc" "Panel and desktop applets"
restore_config "plasma-localerc" "Regional and language settings"
restore_config "plasma-workspace" "Workspace environment"
restore_config "plasmanotifyrc" "Notification settings"

# Restore window manager settings
restore_config "kwinrc" "Window manager settings"
restore_config "kwinrulesrc" "Window rules"

# Display configuration is hardware-specific - skip if requested or on different hardware
if [[ "$SKIP_DISPLAY_CONFIG" == false ]]; then
    if [[ -f "${BACKUP_DIR}/config/kwinoutputconfig.json" ]]; then
        echo -e "${YELLOW}WARNING: Restoring display configuration (kwinoutputconfig.json)${NC}"
        echo -e "${YELLOW}  This may cause display issues on different hardware${NC}"
        if [[ "$DRY_RUN" == false ]]; then
            read -p "  Continue with display config restore? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                restore_config "kwinoutputconfig.json" "Display configuration"
            else
                echo -e "${YELLOW}Skipping display configuration${NC}"
            fi
        else
            restore_config "kwinoutputconfig.json" "Display configuration"
        fi
    fi
else
    echo -e "${YELLOW}Skipping display configuration (hardware-safe mode)${NC}"
fi

# Restore keyboard and input
restore_config "kglobalshortcutsrc" "Global keyboard shortcuts"
restore_config "kxkbrc" "Keyboard layout settings"
restore_config "kcminputrc" "Input device settings"

# Restore KDE services
restore_config "kded6rc" "KDE daemon configuration"
restore_config "kded5rc" "KDE daemon configuration (legacy)"

# Restore activity manager
restore_config "kactivitymanagerdrc" "Activity manager settings"
restore_config "kactivitymanagerd-statsrc" "Activity manager statistics"

# Restore desktop portal
restore_config "xdg-desktop-portal-kderc" "Desktop portal settings"

# Restore other config directories
if [[ -d "${BACKUP_DIR}/config/kdeconnect" ]]; then
    restore_item "${BACKUP_DIR}/config/kdeconnect" "${HOME}/.config/kdeconnect" "KDE Connect"
fi

if [[ -d "${BACKUP_DIR}/config/kdedefaults" ]]; then
    restore_item "${BACKUP_DIR}/config/kdedefaults" "${HOME}/.config/kdedefaults" "KDE defaults"
fi

if [[ -d "${BACKUP_DIR}/config/kde.org" ]]; then
    restore_item "${BACKUP_DIR}/config/kde.org" "${HOME}/.config/kde.org" "KDE application settings"
fi

if [[ -d "${BACKUP_DIR}/config/autostart" ]]; then
    restore_item "${BACKUP_DIR}/config/autostart" "${HOME}/.config/autostart" "Autostart applications"
fi

# Restore user-installed resources
if [[ "$SKIP_USER_RESOURCES" == false ]]; then
    echo ""
    echo -e "${BLUE}--- Restoring user-installed themes, icons, and resources ---${NC}"
    
    if [[ "$RE_DOWNLOAD" == true ]]; then
        echo -e "${YELLOW}Re-download mode: Installing packages from repository${NC}"
        
        # Install packages from package list if available
        if [[ -f "${BACKUP_DIR}/metadata/kde-packages.txt" ]]; then
            echo -e "${BLUE}Installing packages from backup list...${NC}"
            if [[ "$DRY_RUN" == false ]]; then
                PACKAGES=$(grep -v '^#' "${BACKUP_DIR}/metadata/kde-packages.txt" | grep -v '^$' | tr '\n' ' ')
                if [[ -n "$PACKAGES" ]]; then
                    echo -e "${YELLOW}Packages to install: ${PACKAGES}${NC}"
                    read -p "Install these packages? (y/n): " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        sudo apt install -y $PACKAGES || {
                            echo -e "${YELLOW}Warning: Some packages could not be installed${NC}"
                        }
                    fi
                fi
            else
                echo -e "${BLUE}[DRY RUN] Would install packages from kde-packages.txt${NC}"
            fi
        else
            echo -e "${YELLOW}No package list found in backup${NC}"
        fi
        
        # Extract theme/icon names from config and try to install them
        echo -e "${BLUE}Note: You may need to install themes/icons manually from Discover or:${NC}"
        echo -e "${BLUE}  sudo apt install <package-name>${NC}"
        
    else
        # Restore files directly
        if [[ -d "${BACKUP_DIR}/local-share/plasma/desktoptheme" ]]; then
            restore_item "${BACKUP_DIR}/local-share/plasma/desktoptheme" \
                        "${HOME}/.local/share/plasma/desktoptheme" \
                        "Plasma desktop themes"
        fi
        
        if [[ -d "${BACKUP_DIR}/local-share/plasma/look-and-feel" ]]; then
            restore_item "${BACKUP_DIR}/local-share/plasma/look-and-feel" \
                        "${HOME}/.local/share/plasma/look-and-feel" \
                        "Plasma look-and-feel packages"
        fi
        
        if [[ -d "${BACKUP_DIR}/local-share/color-schemes" ]]; then
            restore_item "${BACKUP_DIR}/local-share/color-schemes" \
                        "${HOME}/.local/share/color-schemes" \
                        "Color schemes"
        fi
        
        if [[ -d "${BACKUP_DIR}/local-share/icons" ]]; then
            restore_item "${BACKUP_DIR}/local-share/icons" \
                        "${HOME}/.local/share/icons" \
                        "Icon themes"
        fi
        
        if [[ -d "${BACKUP_DIR}/local-share/aurorae/themes" ]]; then
            restore_item "${BACKUP_DIR}/local-share/aurorae/themes" \
                        "${HOME}/.local/share/aurorae/themes" \
                        "Aurorae window decorations"
        fi
        
        if [[ -d "${BACKUP_DIR}/local-share/wallpapers" ]]; then
            restore_item "${BACKUP_DIR}/local-share/wallpapers" \
                        "${HOME}/.local/share/wallpapers" \
                        "User wallpapers"
        fi
        
        if [[ -d "${BACKUP_DIR}/local-share/kded6" ]]; then
            restore_item "${BACKUP_DIR}/local-share/kded6" \
                        "${HOME}/.local/share/kded6" \
                        "KDE6 daemon data"
        fi
        
        if [[ -d "${BACKUP_DIR}/local-share/knewstuff3" ]]; then
            restore_item "${BACKUP_DIR}/local-share/knewstuff3" \
                        "${HOME}/.local/share/knewstuff3" \
                        "KNewStuff download registries"
        fi
    fi
fi

if [[ "$DRY_RUN" == false ]]; then
    echo ""
    echo -e "${GREEN}=== Restore completed! ===${NC}"
    echo -e "${YELLOW}You may need to:${NC}"
    echo -e "${YELLOW}  1. Log out and log back in for some settings to take effect${NC}"
    echo -e "${YELLOW}  2. Restart Plasma: killall plasmashell && kstart plasmashell${NC}"
    echo -e "${YELLOW}  3. Or simply reboot your system${NC}"
    
    # Offer to restart Plasma
    read -p "Restart Plasma shell now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        killall plasmashell 2>/dev/null || true
        sleep 1
        kstart plasmashell 2>/dev/null || {
            echo -e "${YELLOW}Could not restart plasmashell automatically. Please log out and back in.${NC}"
        }
    fi
else
    echo ""
    echo -e "${BLUE}[DRY RUN] Restore simulation completed${NC}"
fi

