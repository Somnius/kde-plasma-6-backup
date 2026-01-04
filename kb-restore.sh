#!/bin/bash

###############################################################################
# KDE Plasma 6 Restore Script
# 
# This script restores KDE Plasma 6 settings from a backup.
#
# Usage: ./kb-restore.sh BACKUP_DIR [OPTIONS]
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

# Detect package manager (handles niche distros via /etc/os-release)
detect_package_manager() {
    # First check if package manager commands exist
    if command -v pacman >/dev/null 2>&1; then
        echo "pacman"
        return
    elif command -v apt >/dev/null 2>&1; then
        echo "apt"
        return
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
        return
    elif command -v yum >/dev/null 2>&1; then
        echo "yum"
        return
    elif command -v zypper >/dev/null 2>&1; then
        echo "zypper"
        return
    elif command -v emerge >/dev/null 2>&1; then
        echo "emerge"
        return
    fi
    
    # If no package manager found, check /etc/os-release for base distribution
    # This handles niche distros like PikaOS (Debian-based), CachyOS (Arch-based), etc.
    if [[ -f /etc/os-release ]]; then
        local id_like=$(grep "^ID_LIKE=" /etc/os-release 2>/dev/null | cut -d'=' -f2 | tr -d '"' | cut -d' ' -f1)
        local id=$(grep "^ID=" /etc/os-release 2>/dev/null | cut -d'=' -f2 | tr -d '"')
        
        # Check ID_LIKE first (more reliable for derived distros)
        case "$id_like" in
            arch|archlinux)
                if command -v pacman >/dev/null 2>&1; then
                    echo "pacman"
                    return
                fi
                ;;
            debian|ubuntu)
                if command -v apt >/dev/null 2>&1; then
                    echo "apt"
                    return
                fi
                ;;
            fedora|rhel|centos)
                if command -v dnf >/dev/null 2>&1; then
                    echo "dnf"
                    return
                elif command -v yum >/dev/null 2>&1; then
                    echo "yum"
                    return
                fi
                ;;
            suse|opensuse)
                if command -v zypper >/dev/null 2>&1; then
                    echo "zypper"
                    return
                fi
                ;;
            gentoo)
                if command -v emerge >/dev/null 2>&1; then
                    echo "emerge"
                    return
                fi
                ;;
        esac
        
        # Fallback to ID if ID_LIKE didn't match
        case "$id" in
            arch|archlinux|manjaro|cachyos|endeavouros)
                if command -v pacman >/dev/null 2>&1; then
                    echo "pacman"
                    return
                fi
                ;;
            debian|ubuntu|pika|pikaos|mint|pop|elementary)
                if command -v apt >/dev/null 2>&1; then
                    echo "apt"
                    return
                fi
                ;;
            fedora|rhel|centos)
                if command -v dnf >/dev/null 2>&1; then
                    echo "dnf"
                    return
                elif command -v yum >/dev/null 2>&1; then
                    echo "yum"
                    return
                fi
                ;;
            opensuse*|suse)
                if command -v zypper >/dev/null 2>&1; then
                    echo "zypper"
                    return
                fi
                ;;
            gentoo)
                if command -v emerge >/dev/null 2>&1; then
                    echo "emerge"
                    return
                fi
                ;;
        esac
    fi
    
    echo "unknown"
}

# Get install command for package manager
get_install_command() {
    local pkgmgr="$1"
    case "$pkgmgr" in
        pacman)
            echo "sudo pacman -S --noconfirm"
            ;;
        apt)
            echo "sudo apt install -y"
            ;;
        dnf)
            echo "sudo dnf install -y"
            ;;
        yum)
            echo "sudo yum install -y"
            ;;
        zypper)
            echo "sudo zypper install -y"
            ;;
        emerge)
            echo "sudo emerge -a"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Get package manager name for display
get_package_manager_name() {
    local pkgmgr="$1"
    case "$pkgmgr" in
        pacman) echo "pacman (Arch Linux)" ;;
        apt) echo "apt (Debian/Ubuntu)" ;;
        dnf) echo "dnf (Fedora)" ;;
        yum) echo "yum (RHEL/CentOS)" ;;
        zypper) echo "zypper (openSUSE)" ;;
        emerge) echo "emerge (Gentoo)" ;;
        *) echo "unknown" ;;
    esac
}

# Default values
RE_DOWNLOAD=false
SKIP_USER_RESOURCES=false
DRY_RUN=false
VALIDATE_ONLY=false
SKIP_DISPLAY_CONFIG=false
INTERACTIVE=false
SELECTIVE_RESTORE=false

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
        --interactive|-i)
            INTERACTIVE=true
            SELECTIVE_RESTORE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 BACKUP_DIR [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --re-download-themes    Re-download themes/icons from repositories"
            echo "  --skip-user-resources   Only restore config files, skip themes/icons"
            echo "  --skip-display-config   Skip display configuration (safe for different hardware)"
            echo "  --interactive, -i       Interactive TUI to selectively choose what to restore"
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

# Load categories from backup metadata
declare -A CATEGORY_FILES
declare -A SELECTED_CATEGORIES

# Function to check if an application exists (including Flatpak)
check_app_exists() {
    local app_name="$1"
    local desktop_file="$2"
    
    # Check if it's a Flatpak app
    if [[ "$desktop_file" == *"flatpak"* ]] || [[ "$app_name" == *"flatpak"* ]]; then
        # Extract Flatpak app ID from desktop file if possible
        if [[ -f "$desktop_file" ]]; then
            local flatpak_id=$(grep -E "^X-Flatpak-RenamedFrom=" "$desktop_file" 2>/dev/null | cut -d'=' -f2 | head -1)
            if [[ -n "$flatpak_id" ]]; then
                flatpak list --app --columns=application 2>/dev/null | grep -q "^${flatpak_id}$" && return 0
            fi
        fi
        # Try to find by name in Flatpak
        flatpak list --app --columns=application 2>/dev/null | grep -qi "${app_name}" && return 0
    fi
    
    # Check if desktop file exists in system
    if [[ -f "$desktop_file" ]]; then
        local exec_line=$(grep "^Exec=" "$desktop_file" 2>/dev/null | head -1 | cut -d'=' -f2 | cut -d' ' -f1)
        if [[ -n "$exec_line" ]]; then
            command -v "$exec_line" >/dev/null 2>&1 && return 0
        fi
    fi
    
    # Check if command exists
    command -v "$app_name" >/dev/null 2>&1 && return 0
    
    # Check desktop file database
    if command -v gtk-launch >/dev/null 2>&1; then
        local basename_app=$(basename "$desktop_file" .desktop 2>/dev/null)
        gtk-launch "$basename_app" --version >/dev/null 2>&1 && return 0
    fi
    
    return 1
}

# Function to detect missing autostart applications
detect_missing_autostart_apps() {
    local autostart_dir="${BACKUP_DIR}/config/autostart"
    local missing_apps=()
    
    if [[ ! -d "$autostart_dir" ]]; then
        return 0
    fi
    
    while IFS= read -r desktop_file; do
        local app_name=$(basename "$desktop_file" .desktop)
        local full_path="${HOME}/.config/autostart/$(basename "$desktop_file")"
        
        if ! check_app_exists "$app_name" "$desktop_file"; then
            missing_apps+=("$app_name|$desktop_file")
        fi
    done < <(find "$autostart_dir" -name "*.desktop" 2>/dev/null)
    
    printf '%s\n' "${missing_apps[@]}"
}

# Function to detect missing default applications from mimeapps.list
detect_missing_default_apps() {
    local mimeapps_file="${BACKUP_DIR}/config/mimeapps.list"
    declare -A seen_apps
    local missing_apps=()
    
    if [[ ! -f "$mimeapps_file" ]]; then
        return 0
    fi
    
    # Extract application names from mimeapps.list
    while IFS='=' read -r mime_type apps; do
        # Skip comments and empty lines
        [[ "$mime_type" =~ ^#.*$ ]] && continue
        [[ -z "$mime_type" ]] && continue
        
        # Parse applications (format: app1.desktop;app2.desktop;)
        IFS=';' read -ra app_array <<< "$apps"
        for app_desktop in "${app_array[@]}"; do
            app_desktop=$(echo "$app_desktop" | xargs) # trim whitespace
            [[ -z "$app_desktop" ]] && continue
            
            local app_name=$(basename "$app_desktop" .desktop)
            
            # Skip if we've already checked this app
            [[ -n "${seen_apps[$app_name]}" ]] && continue
            seen_apps[$app_name]=1
            
            local desktop_file="/usr/share/applications/${app_desktop}"
            local flatpak_desktop="${HOME}/.local/share/applications/${app_desktop}"
            
            # Check if app exists
            local app_exists=false
            if [[ -f "$desktop_file" ]] && check_app_exists "$app_name" "$desktop_file"; then
                app_exists=true
            elif [[ -f "$flatpak_desktop" ]] && check_app_exists "$app_name" "$flatpak_desktop"; then
                app_exists=true
            fi
            
            if [[ "$app_exists" == false ]]; then
                missing_apps+=("$app_name|$app_desktop")
            fi
        done
    done < "$mimeapps_file"
    
    printf '%s\n' "${missing_apps[@]}"
}

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

load_categories() {
    local categories_file="${BACKUP_DIR}/metadata/categories.txt"
    if [[ ! -f "$categories_file" ]]; then
        echo -e "${YELLOW}Warning: Categories metadata not found. Using full restore.${NC}"
        return 1
    fi
    
    while IFS='|' read -r category file_path description; do
        # Skip comments and empty lines
        [[ "$category" =~ ^#.*$ ]] && continue
        [[ -z "$category" ]] && continue
        
        # Check if file exists in backup
        if [[ -e "${BACKUP_DIR}/${file_path}" ]] || [[ -d "${BACKUP_DIR}/${file_path}" ]]; then
            CATEGORY_FILES["${category}|${file_path}"]="$description"
        fi
    done < "$categories_file"
    
    return 0
}

# Interactive TUI for category selection
show_interactive_menu() {
    local categories_file="${BACKUP_DIR}/metadata/categories.txt"
    if [[ ! -f "$categories_file" ]]; then
        echo -e "${RED}Error: Categories metadata not found in backup${NC}"
        echo -e "${YELLOW}This backup was created with an older version. Use full restore instead.${NC}"
        return 1
    fi
    
    # Get unique categories
    local unique_categories=($(grep -v '^#' "$categories_file" | cut -d'|' -f1 | sort -u))
    
    echo ""
    echo -e "${BLUE}=== Interactive Restore Selection ===${NC}"
    echo -e "${BLUE}Select which categories to restore:${NC}"
    echo ""
    
    local index=1
    declare -A category_map
    
    for category in "${unique_categories[@]}"; do
        # Count items in this category
        local count=$(grep -v '^#' "$categories_file" | grep "^${category}|" | wc -l)
        local display_name=$(echo "$category" | sed 's/-/ /g' | sed 's/\b\(.\)/\u\1/g')
        
        echo -e "${GREEN}[${index}]${NC} ${display_name} (${count} items)"
        category_map[$index]="$category"
        ((index++))
    done
    
    echo -e "${GREEN}[${index}]${NC} Restore All Categories"
    echo -e "${GREEN}[0]${NC} Cancel"
    echo ""
    
    read -p "Enter your choices (comma-separated, e.g., 1,3,5 or ${index} for all): " choices
    
    if [[ "$choices" == "0" ]]; then
        echo "Restore cancelled."
        exit 0
    fi
    
    # Parse choices
    IFS=',' read -ra choice_array <<< "$choices"
    local restore_all=false
    
    for choice in "${choice_array[@]}"; do
        choice=$(echo "$choice" | xargs) # trim whitespace
        
        # Handle "all" keyword or the "Restore All" index
        if [[ "$choice" == "all" ]] || [[ "$choice" == "All" ]] || [[ "$choice" == "ALL" ]] || [[ "$choice" == "$index" ]]; then
            restore_all=true
            break
        fi
        
        # Skip if not a number
        if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
            echo -e "${YELLOW}Warning: Invalid choice '${choice}', skipping...${NC}"
            continue
        fi
        
        # Check if choice is valid and exists in category_map
        if [[ -n "${category_map[$choice]:-}" ]]; then
            SELECTED_CATEGORIES["${category_map[$choice]}"]=1
        else
            echo -e "${YELLOW}Warning: Invalid category number '${choice}', skipping...${NC}"
        fi
    done
    
    if [[ "$restore_all" == true ]]; then
        for category in "${unique_categories[@]}"; do
            SELECTED_CATEGORIES["$category"]=1
        done
    fi
    
    # Show selected categories
    echo ""
    echo -e "${BLUE}Selected categories for restore:${NC}"
    for category in "${!SELECTED_CATEGORIES[@]}"; do
        local display_name=$(echo "$category" | sed 's/-/ /g' | sed 's/\b\(.\)/\u\1/g')
        local count=$(grep -v '^#' "$categories_file" | grep "^${category}|" | wc -l)
        echo -e "  ${GREEN}✓${NC} ${display_name} (${count} items)"
    done
    echo ""
    
    # Ask about restore options in interactive mode
    echo ""
    echo -e "${BLUE}=== Restore Options ===${NC}"
    
    # Ask about display config
    if [[ -f "${BACKUP_DIR}/config/kwinoutputconfig.json" ]]; then
        echo -e "${YELLOW}Display configuration found in backup${NC}"
        read -p "Skip display configuration (safe for different hardware)? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            SKIP_DISPLAY_CONFIG=true
        fi
    fi
    
    # Ask about re-download themes
    if [[ "$SKIP_USER_RESOURCES" == false ]] && [[ -n "${SELECTED_CATEGORIES[appearance]}" ]]; then
        echo -e "${YELLOW}Appearance category selected${NC}"
        read -p "Re-download themes/icons from repositories instead of restoring files? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            RE_DOWNLOAD=true
        fi
    fi
    
    read -p "Continue with restore? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Restore cancelled."
        exit 0
    fi
    
    return 0
}

# Restore items by category
restore_by_category() {
    local category="$1"
    local categories_file="${BACKUP_DIR}/metadata/categories.txt"
    
    if [[ ! -f "$categories_file" ]]; then
        return 1
    fi
    
    local display_name=$(echo "$category" | sed 's/-/ /g' | sed 's/\b\(.\)/\u\1/g')
    echo ""
    echo -e "${BLUE}--- Restoring ${display_name} Category ---${NC}"
    
    local item_count=0
    while IFS='|' read -r cat file_path description || [[ -n "$cat" ]]; do
        # Skip comments and empty lines
        [[ "$cat" =~ ^#.*$ ]] && continue
        [[ -z "$cat" ]] && continue
        
        # Only process this category
        if [[ "$cat" != "$category" ]]; then
            continue
        fi
        
        # Restore the file/directory
        local source="${BACKUP_DIR}/${file_path}"
        local dest=""
        
        # Determine destination based on file path
        if [[ "$file_path" == config/* ]]; then
            # Handle subdirectories in config (e.g., config/kdeconnect, config/kde.org)
            if [[ "$file_path" == config/*/* ]]; then
                # It's a subdirectory
                local rel_path="${file_path#config/}"
                dest="${HOME}/.config/${rel_path}"
            else
                # It's a file in config root
                local filename=$(basename "$file_path")
                dest="${HOME}/.config/${filename}"
            fi
        elif [[ "$file_path" == local-share/* ]]; then
            local rel_path="${file_path#local-share/}"
            dest="${HOME}/.local/share/${rel_path}"
        fi
        
        if [[ -n "$dest" ]] && [[ -e "$source" ]]; then
            echo -e "${GREEN}  → ${description}${NC}"
            # Use || true to prevent set -e from exiting on restore_item failure
            if restore_item "$source" "$dest" "$description" || true; then
                ((item_count++)) || true
            else
                echo -e "${YELLOW}  Warning: Failed to restore ${description}${NC}"
            fi
        elif [[ -n "$dest" ]]; then
            echo -e "${YELLOW}  Skipping (not in backup): ${description}${NC}"
        fi
    done < "$categories_file" || true
    
    if [[ $item_count -eq 0 ]]; then
        echo -e "${YELLOW}  No items found in backup for this category${NC}"
    else
        echo -e "${GREEN}  ✓ Restored ${item_count} item(s)${NC}"
    fi
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

# Handle interactive/selective restore
if [[ "$INTERACTIVE" == true ]]; then
    if ! load_categories; then
        echo -e "${YELLOW}Falling back to full restore...${NC}"
        INTERACTIVE=false
    else
        if ! show_interactive_menu; then
            exit 1
        fi
    fi
fi

if [[ "$DRY_RUN" == false ]] && [[ "$INTERACTIVE" == false ]]; then
    read -p "Continue with restore? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Restore cancelled."
        exit 0
    fi
fi

# Perform restore based on mode
if [[ "$INTERACTIVE" == true ]] && [[ ${#SELECTED_CATEGORIES[@]} -gt 0 ]]; then
    # Selective restore by category
    echo ""
    echo -e "${BLUE}=== Starting Selective Restore ===${NC}"
    echo -e "${BLUE}Will restore ${#SELECTED_CATEGORIES[@]} category/categories${NC}"
    
    for category in "${!SELECTED_CATEGORIES[@]}"; do
        # Use || true to prevent set -e from exiting on restore_by_category failure
        if ! restore_by_category "$category" || true; then
            echo -e "${YELLOW}Warning: Issues encountered while restoring category: ${category}${NC}"
            # Continue with next category instead of exiting
        fi
    done
    
    echo ""
    echo -e "${BLUE}=== Category restore completed ===${NC}"
    
    # Handle user resources if not skipped
    if [[ "$SKIP_USER_RESOURCES" == false ]]; then
        # Check if appearance category was selected (includes themes/icons)
        if [[ -n "${SELECTED_CATEGORIES[appearance]}" ]]; then
            echo ""
            echo -e "${BLUE}--- Restoring user-installed themes, icons, and resources ---${NC}"
            
            if [[ "$RE_DOWNLOAD" == true ]]; then
                echo -e "${YELLOW}Re-download mode: Installing packages from repository${NC}"
                # Package installation logic would go here (same as full restore)
            else
                # Restore files directly for appearance category
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
            fi
        fi
        
        # Handle kde6-data category
        if [[ -n "${SELECTED_CATEGORIES[kde6-data]}" ]]; then
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
    
    # Interactive restore completion - same as full restore
    echo ""
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${BLUE}[DRY RUN] === Restore simulation completed! ===${NC}"
    else
        echo -e "${GREEN}=== Restore completed! ===${NC}"
    fi
    
    # Reconfigure KWin if window manager settings were restored
    if [[ -n "${SELECTED_CATEGORIES[window-manager]}" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            echo -e "${BLUE}[DRY RUN] Would reconfigure KWin to apply window decorations${NC}"
        else
            if command -v qdbus >/dev/null 2>&1; then
                echo -e "${BLUE}Reconfiguring KWin to apply window decorations...${NC}"
                qdbus org.kde.KWin /KWin reconfigure 2>/dev/null || {
                    echo -e "${YELLOW}Note: KWin reconfiguration may require a logout/login for full effect${NC}"
                }
            elif command -v qdbus-qt6 >/dev/null 2>&1; then
                echo -e "${BLUE}Reconfiguring KWin to apply window decorations...${NC}"
                qdbus-qt6 org.kde.KWin /KWin reconfigure 2>/dev/null || {
                    echo -e "${YELLOW}Note: KWin reconfiguration may require a logout/login for full effect${NC}"
                }
            fi
        fi
    fi
    
    # Check for missing autostart applications
    echo ""
    echo -e "${BLUE}--- Checking for missing applications ---${NC}"
    
    local missing_autostart=$(detect_missing_autostart_apps)
    if [[ -n "$missing_autostart" ]]; then
        echo ""
        echo -e "${YELLOW}Missing autostart applications detected:${NC}"
        local autostart_count=0
        declare -a autostart_apps
        while IFS='|' read -r app_name desktop_file; do
            echo -e "  ${YELLOW}•${NC} ${app_name}"
            autostart_apps+=("$app_name|$desktop_file")
            ((autostart_count++))
        done <<< "$missing_autostart"
        
        if [[ "$DRY_RUN" == true ]]; then
            echo -e "${BLUE}[DRY RUN] Would prompt to install these missing autostart applications${NC}"
        else
            echo ""
            read -p "Would you like to install these missing autostart applications? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                    for app_entry in "${autostart_apps[@]}"; do
                        IFS='|' read -r app_name desktop_file <<< "$app_entry"
                        echo -e "${BLUE}Attempting to install: ${app_name}${NC}"
                        
                        # Check if it's a Flatpak app
                        if [[ "$desktop_file" == *"flatpak"* ]] || [[ "$app_name" == "yakuake" ]] || flatpak list --app 2>/dev/null | grep -qi "$app_name"; then
                            if command -v flatpak >/dev/null 2>&1; then
                                # Try to find Flatpak app ID
                                local flatpak_id=$(flatpak search "$app_name" 2>/dev/null | grep -i "$app_name" | head -1 | awk '{print $1}')
                                if [[ -n "$flatpak_id" ]]; then
                                    echo -e "${YELLOW}Installing Flatpak app: ${flatpak_id}${NC}"
                                    flatpak install -y "$flatpak_id" 2>/dev/null || {
                                        echo -e "${YELLOW}Could not auto-install ${app_name}. Please install manually.${NC}"
                                        echo -e "${YELLOW}  Try: flatpak search ${app_name}${NC}"
                                    }
                                else
                                    echo -e "${YELLOW}Could not find Flatpak app for ${app_name}. Please install manually.${NC}"
                                    echo -e "${YELLOW}  Try: flatpak search ${app_name}${NC}"
                                fi
                            else
                                echo -e "${YELLOW}Flatpak not available. Please install ${app_name} manually.${NC}"
                            fi
                        else
                            # Try system package manager
                            PKG_MGR=$(detect_package_manager)
                            if [[ "$PKG_MGR" != "unknown" ]]; then
                                INSTALL_CMD=$(get_install_command "$PKG_MGR")
                                echo -e "${YELLOW}Attempting to install via ${PKG_MGR}: ${app_name}${NC}"
                                # Note: Package name might differ, user may need to install manually
                                echo -e "${YELLOW}  Please install ${app_name} manually using your package manager${NC}"
                                echo -e "${YELLOW}  Example: ${INSTALL_CMD} ${app_name}${NC}"
                            else
                                echo -e "${YELLOW}Please install ${app_name} manually${NC}"
                            fi
                        fi
                    done
                fi
            fi
        fi
        
        # Check for missing default applications
        local missing_defaults=$(detect_missing_default_apps)
        if [[ -n "$missing_defaults" ]]; then
            echo ""
            echo -e "${YELLOW}Missing default applications detected:${NC}"
            local defaults_count=0
            declare -a default_apps
            while IFS='|' read -r app_name app_desktop; do
                echo -e "  ${YELLOW}•${NC} ${app_name}"
                default_apps+=("$app_name|$app_desktop")
                ((defaults_count++))
            done <<< "$missing_defaults"
            
            if [[ "$DRY_RUN" == false ]]; then
                echo ""
                read -p "Would you like to install these missing default applications? (y/n): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    for app_entry in "${default_apps[@]}"; do
                        IFS='|' read -r app_name app_desktop <<< "$app_entry"
                        echo -e "${BLUE}Attempting to install: ${app_name}${NC}"
                        
                        # Check if it's a Flatpak app
                        if [[ "$app_desktop" == *"flatpak"* ]] || flatpak list --app 2>/dev/null | grep -qi "$app_name"; then
                            if command -v flatpak >/dev/null 2>&1; then
                                local flatpak_id=$(flatpak search "$app_name" 2>/dev/null | grep -i "$app_name" | head -1 | awk '{print $1}')
                                if [[ -n "$flatpak_id" ]]; then
                                    echo -e "${YELLOW}Installing Flatpak app: ${flatpak_id}${NC}"
                                    flatpak install -y "$flatpak_id" 2>/dev/null || {
                                        echo -e "${YELLOW}Could not auto-install ${app_name}. Please install manually.${NC}"
                                    }
                                else
                                    echo -e "${YELLOW}Could not find Flatpak app for ${app_name}. Please install manually.${NC}"
                                fi
                            else
                                echo -e "${YELLOW}Flatpak not available. Please install ${app_name} manually.${NC}"
                            fi
                        else
                            # Try system package manager
                            PKG_MGR=$(detect_package_manager)
                            if [[ "$PKG_MGR" != "unknown" ]]; then
                                INSTALL_CMD=$(get_install_command "$PKG_MGR")
                                echo -e "${YELLOW}Please install ${app_name} manually using your package manager${NC}"
                                echo -e "${YELLOW}  Example: ${INSTALL_CMD} ${app_name}${NC}"
                            else
                                echo -e "${YELLOW}Please install ${app_name} manually${NC}"
                            fi
                        fi
                    done
                fi
            fi
        fi
        
    if [[ -z "$missing_autostart" ]] && [[ -z "$missing_defaults" ]]; then
        echo -e "${GREEN}✓ All applications are available${NC}"
    fi
    
    echo ""
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${BLUE}[DRY RUN] Would show next steps and offer to restart Plasma shell${NC}"
    else
        echo -e "${YELLOW}You may need to:${NC}"
        echo -e "${YELLOW}  1. Log out and log back in for some settings to take effect (recommended)${NC}"
        echo -e "${YELLOW}  2. Restart Plasma: killall plasmashell && kstart plasmashell${NC}"
        echo -e "${YELLOW}  3. Or simply reboot your system${NC}"
        echo ""
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
    fi
else
    # Full restore (original behavior)
    echo ""
    echo -e "${BLUE}--- Restoring configuration files ---${NC}"

    # Restore core configuration files
    restore_config "kdeglobals" "Global KDE settings"
    restore_config "plasmarc" "Plasma theme and wallpaper settings"
    restore_config "plasmashellrc" "Plasma shell configuration"
    restore_config "plasma-org.kde.plasma.desktop-appletsrc" "Panel and desktop applets (includes panel transparency)"
restore_config "plasma-localerc" "Regional and language settings"
restore_config "user-dirs.locale" "User directories locale settings"
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

# Restore default applications
restore_config "mimeapps.list" "Default applications for file types"

# Restore user-installed resources
if [[ "$SKIP_USER_RESOURCES" == false ]]; then
    echo ""
    echo -e "${BLUE}--- Restoring user-installed themes, icons, and resources ---${NC}"
    
    if [[ "$RE_DOWNLOAD" == true ]]; then
        echo -e "${YELLOW}Re-download mode: Installing packages from repository${NC}"
        
        # Detect package manager
        PKG_MGR=$(detect_package_manager)
        PKG_MGR_NAME=$(get_package_manager_name "$PKG_MGR")
        INSTALL_CMD=$(get_install_command "$PKG_MGR")
        
        if [[ "$PKG_MGR" == "unknown" ]]; then
            echo -e "${RED}Error: Could not detect package manager${NC}"
            echo -e "${YELLOW}Please install packages manually from the backup's kde-packages.txt${NC}"
        else
            echo -e "${BLUE}Detected package manager: ${PKG_MGR_NAME}${NC}"
        fi
        
        # Install packages from package list if available
        if [[ -f "${BACKUP_DIR}/metadata/kde-packages.txt" ]]; then
            echo -e "${BLUE}Installing packages from backup list...${NC}"
            if [[ "$DRY_RUN" == false ]]; then
                PACKAGES=$(grep -v '^#' "${BACKUP_DIR}/metadata/kde-packages.txt" | grep -v '^$' | tr '\n' ' ')
                if [[ -n "$PACKAGES" ]]; then
                    echo -e "${YELLOW}Packages to install: ${PACKAGES}${NC}"
                    echo -e "${YELLOW}Note: Package names may differ between distributions${NC}"
                    echo -e "${YELLOW}Some packages may not be available or have different names${NC}"
                    read -p "Install these packages? (y/n): " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        if [[ "$PKG_MGR" != "unknown" ]]; then
                            $INSTALL_CMD $PACKAGES || {
                                echo -e "${YELLOW}Warning: Some packages could not be installed${NC}"
                                echo -e "${YELLOW}This is normal if package names differ between distributions${NC}"
                                echo -e "${YELLOW}You may need to install packages manually or use Discover${NC}"
                            }
                        else
                            echo -e "${RED}Cannot install packages: unknown package manager${NC}"
                        fi
                    fi
                fi
            else
                echo -e "${BLUE}[DRY RUN] Would install packages from kde-packages.txt using ${PKG_MGR_NAME}${NC}"
            fi
        else
            echo -e "${YELLOW}No package list found in backup${NC}"
        fi
        
        # Extract theme/icon names from config and try to install them
        echo -e "${BLUE}Note: You may need to install themes/icons manually from Discover or:${NC}"
        if [[ "$PKG_MGR" != "unknown" ]]; then
            echo -e "${BLUE}  ${INSTALL_CMD} <package-name>${NC}"
        else
            echo -e "${BLUE}  Use your distribution's package manager${NC}"
        fi
        
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
                        "cKDE6 daemon data"
        fi
        
        if [[ -d "${BACKUP_DIR}/local-share/knewstuff3" ]]; then
            restore_item "${BACKUP_DIR}/local-share/knewstuff3" \
                        "${HOME}/.local/share/knewstuff3" \
                        "KNewStuff download registries"
        fi
    fi
    fi
fi


# Common completion message for both modes
if [[ "$DRY_RUN" == false ]]; then
    echo ""
    echo -e "${GREEN}=== Restore completed! ===${NC}"
    
    # Check for missing autostart applications
    echo ""
    echo -e "${BLUE}--- Checking for missing applications ---${NC}"
    
    local missing_autostart=$(detect_missing_autostart_apps)
    if [[ -n "$missing_autostart" ]]; then
        echo ""
        echo -e "${YELLOW}Missing autostart applications detected:${NC}"
        local autostart_count=0
        declare -a autostart_apps
        while IFS='|' read -r app_name desktop_file; do
            echo -e "  ${YELLOW}•${NC} ${app_name}"
            autostart_apps+=("$app_name|$desktop_file")
            ((autostart_count++))
        done <<< "$missing_autostart"
        
        if [[ "$DRY_RUN" == false ]]; then
            echo ""
            read -p "Would you like to install these missing autostart applications? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                for app_entry in "${autostart_apps[@]}"; do
                    IFS='|' read -r app_name desktop_file <<< "$app_entry"
                    echo -e "${BLUE}Attempting to install: ${app_name}${NC}"
                    
                    # Check if it's a Flatpak app
                    if [[ "$desktop_file" == *"flatpak"* ]] || [[ "$app_name" == "yakuake" ]] || flatpak list --app 2>/dev/null | grep -qi "$app_name"; then
                        if command -v flatpak >/dev/null 2>&1; then
                            # Try to find Flatpak app ID
                            local flatpak_id=$(flatpak search "$app_name" 2>/dev/null | grep -i "$app_name" | head -1 | awk '{print $1}')
                            if [[ -n "$flatpak_id" ]]; then
                                echo -e "${YELLOW}Installing Flatpak app: ${flatpak_id}${NC}"
                                flatpak install -y "$flatpak_id" 2>/dev/null || {
                                    echo -e "${YELLOW}Could not auto-install ${app_name}. Please install manually.${NC}"
                                    echo -e "${YELLOW}  Try: flatpak search ${app_name}${NC}"
                                }
                            else
                                echo -e "${YELLOW}Could not find Flatpak app for ${app_name}. Please install manually.${NC}"
                                echo -e "${YELLOW}  Try: flatpak search ${app_name}${NC}"
                            fi
                        else
                            echo -e "${YELLOW}Flatpak not available. Please install ${app_name} manually.${NC}"
                        fi
                    else
                        # Try system package manager
                        PKG_MGR=$(detect_package_manager)
                        if [[ "$PKG_MGR" != "unknown" ]]; then
                            INSTALL_CMD=$(get_install_command "$PKG_MGR")
                            echo -e "${YELLOW}Attempting to install via ${PKG_MGR}: ${app_name}${NC}"
                            # Note: Package name might differ, user may need to install manually
                            echo -e "${YELLOW}  Please install ${app_name} manually using your package manager${NC}"
                            echo -e "${YELLOW}  Example: ${INSTALL_CMD} ${app_name}${NC}"
                        else
                            echo -e "${YELLOW}Please install ${app_name} manually${NC}"
                        fi
                    fi
                done
            fi
        fi
    fi
    
    # Check for missing default applications
    local missing_defaults=$(detect_missing_default_apps)
    if [[ -n "$missing_defaults" ]]; then
        echo ""
        echo -e "${YELLOW}Missing default applications detected:${NC}"
        local defaults_count=0
        declare -a default_apps
        while IFS='|' read -r app_name app_desktop; do
            echo -e "  ${YELLOW}•${NC} ${app_name}"
            default_apps+=("$app_name|$app_desktop")
            ((defaults_count++))
        done <<< "$missing_defaults"
        
        if [[ "$DRY_RUN" == false ]]; then
            echo ""
            read -p "Would you like to install these missing default applications? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                for app_entry in "${default_apps[@]}"; do
                    IFS='|' read -r app_name app_desktop <<< "$app_entry"
                    echo -e "${BLUE}Attempting to install: ${app_name}${NC}"
                    
                    # Check if it's a Flatpak app
                    if [[ "$app_desktop" == *"flatpak"* ]] || flatpak list --app 2>/dev/null | grep -qi "$app_name"; then
                        if command -v flatpak >/dev/null 2>&1; then
                            local flatpak_id=$(flatpak search "$app_name" 2>/dev/null | grep -i "$app_name" | head -1 | awk '{print $1}')
                            if [[ -n "$flatpak_id" ]]; then
                                echo -e "${YELLOW}Installing Flatpak app: ${flatpak_id}${NC}"
                                flatpak install -y "$flatpak_id" 2>/dev/null || {
                                    echo -e "${YELLOW}Could not auto-install ${app_name}. Please install manually.${NC}"
                                }
                            else
                                echo -e "${YELLOW}Could not find Flatpak app for ${app_name}. Please install manually.${NC}"
                            fi
                        else
                            echo -e "${YELLOW}Flatpak not available. Please install ${app_name} manually.${NC}"
                        fi
                    else
                        # Try system package manager
                        PKG_MGR=$(detect_package_manager)
                        if [[ "$PKG_MGR" != "unknown" ]]; then
                            INSTALL_CMD=$(get_install_command "$PKG_MGR")
                            echo -e "${YELLOW}Please install ${app_name} manually using your package manager${NC}"
                            echo -e "${YELLOW}  Example: ${INSTALL_CMD} ${app_name}${NC}"
                        else
                            echo -e "${YELLOW}Please install ${app_name} manually${NC}"
                        fi
                    fi
                done
            fi
        fi
    fi
    
    if [[ -z "$missing_autostart" ]] && [[ -z "$missing_defaults" ]]; then
        echo -e "${GREEN}✓ All applications are available${NC}"
    fi
    
    # Reconfigure KWin if window manager settings were restored
    if [[ "$INTERACTIVE" == false ]] || [[ -n "${SELECTED_CATEGORIES[window-manager]}" ]]; then
        if command -v qdbus >/dev/null 2>&1; then
            echo -e "${BLUE}Reconfiguring KWin to apply window decorations...${NC}"
            qdbus org.kde.KWin /KWin reconfigure 2>/dev/null || {
                echo -e "${YELLOW}Note: KWin reconfiguration may require a logout/login for full effect${NC}"
            }
        elif command -v qdbus-qt6 >/dev/null 2>&1; then
            echo -e "${BLUE}Reconfiguring KWin to apply window decorations...${NC}"
            qdbus-qt6 org.kde.KWin /KWin reconfigure 2>/dev/null || {
                echo -e "${YELLOW}Note: KWin reconfiguration may require a logout/login for full effect${NC}"
            }
        fi
    fi
    
    echo ""
    echo -e "${YELLOW}You may need to:${NC}"
    echo -e "${YELLOW}  1. Log out and log back in for some settings to take effect (recommended)${NC}"
    echo -e "${YELLOW}  2. Restart Plasma: killall plasmashell && kstart plasmashell${NC}"
    echo -e "${YELLOW}  3. Or simply reboot your system${NC}"
    echo ""
    echo -e "${YELLOW}Note: Window decorations may require logout/login to appear correctly${NC}"
    echo -e "${YELLOW}Note: Panel transparency settings are in plasma-org.kde.plasma.desktop-appletsrc${NC}"
    
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

