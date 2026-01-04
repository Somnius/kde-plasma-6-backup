#!/bin/bash

###############################################################################
# KDE Plasma 6 Backup Validation Script
# 
# Validates backup integrity and compatibility before restore.
#
# Usage: ./kb-validate.sh BACKUP_DIR
###############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

BACKUP_DIR="${1:-}"

if [[ -z "$BACKUP_DIR" ]]; then
    echo -e "${RED}Error: Backup directory not specified${NC}"
    echo "Usage: $0 BACKUP_DIR"
    exit 1
fi

# Handle compressed backups
if [[ -f "$BACKUP_DIR" ]] && [[ "$BACKUP_DIR" == *.tar.gz ]]; then
    echo -e "${BLUE}Detected compressed backup${NC}"
    echo -e "${YELLOW}Note: Validation of compressed backups requires extraction${NC}"
    echo -e "${YELLOW}Run: tar -tzf ${BACKUP_DIR} | head -20${NC} to preview contents"
    exit 0
fi

if [[ ! -d "$BACKUP_DIR" ]]; then
    echo -e "${RED}Error: Backup directory not found: ${BACKUP_DIR}${NC}"
    exit 1
fi

echo -e "${BLUE}=== KDE Plasma 6 Backup Validation ===${NC}"
echo -e "${BLUE}Backup directory: ${BACKUP_DIR}${NC}"
echo ""

errors=0
warnings=0
info=0

# Check backup structure
echo -e "${BLUE}--- Checking Backup Structure ---${NC}"
if [[ ! -d "${BACKUP_DIR}/config" ]]; then
    echo -e "${RED}✗ ERROR: Missing config/ directory${NC}"
    errors=$((errors + 1))
else
    echo -e "${GREEN}✓ config/ directory found${NC}"
    info=$((info + 1))
fi

if [[ ! -d "${BACKUP_DIR}/local-share" ]]; then
    echo -e "${YELLOW}⚠ WARNING: Missing local-share/ directory (no user resources)${NC}"
    warnings=$((warnings + 1))
else
    echo -e "${GREEN}✓ local-share/ directory found${NC}"
    info=$((info + 1))
fi

if [[ ! -d "${BACKUP_DIR}/metadata" ]]; then
    echo -e "${YELLOW}⚠ WARNING: Missing metadata/ directory${NC}"
    warnings=$((warnings + 1))
else
    echo -e "${GREEN}✓ metadata/ directory found${NC}"
    info=$((info + 1))
fi

# Check essential configuration files
echo ""
echo -e "${BLUE}--- Checking Essential Files ---${NC}"
essential_files=(
    "config/kdeglobals:Global KDE settings"
    "config/plasmarc:Plasma theme settings"
)

for file_desc in "${essential_files[@]}"; do
    file="${file_desc%%:*}"
    desc="${file_desc##*:}"
    if [[ -f "${BACKUP_DIR}/${file}" ]]; then
        size=$(stat -f%z "${BACKUP_DIR}/${file}" 2>/dev/null || stat -c%s "${BACKUP_DIR}/${file}" 2>/dev/null || echo "0")
        if [[ $size -gt 0 ]]; then
            echo -e "${GREEN}✓ ${desc} (${file})${NC}"
            info=$((info + 1))
        else
            echo -e "${RED}✗ ERROR: ${desc} (${file}) is empty${NC}"
            errors=$((errors + 1))
        fi
    else
        echo -e "${RED}✗ ERROR: Missing ${desc} (${file})${NC}"
        errors=$((errors + 1))
    fi
done

# Check optional but important files
optional_files=(
    "config/kglobalshortcutsrc:Keyboard shortcuts"
    "config/kwinrc:Window manager settings"
    "config/kxkbrc:Keyboard layout"
    "config/plasma-org.kde.plasma.desktop-appletsrc:Panel configuration"
)

for file_desc in "${optional_files[@]}"; do
    file="${file_desc%%:*}"
    desc="${file_desc##*:}"
    if [[ -f "${BACKUP_DIR}/${file}" ]]; then
        echo -e "${GREEN}✓ ${desc} found${NC}"
        info=$((info + 1))
    else
        echo -e "${YELLOW}⚠ ${desc} not found (optional)${NC}"
        warnings=$((warnings + 1))
    fi
done

# Check metadata
echo ""
echo -e "${BLUE}--- Checking Metadata ---${NC}"
if [[ -f "${BACKUP_DIR}/metadata/system-info.txt" ]]; then
    echo -e "${GREEN}✓ System info found${NC}"
    echo -e "${BLUE}  Backup information:${NC}"
    cat "${BACKUP_DIR}/metadata/system-info.txt" | sed 's/^/    /'
    info=$((info + 1))
else
    echo -e "${YELLOW}⚠ System info metadata missing${NC}"
    warnings=$((warnings + 1))
fi

if [[ -f "${BACKUP_DIR}/metadata/manifest.txt" ]]; then
    echo -e "${GREEN}✓ Backup manifest found${NC}"
    FILE_COUNT=$(grep -c "^config/" "${BACKUP_DIR}/metadata/manifest.txt" 2>/dev/null || echo "0")
    RESOURCE_COUNT=$(grep -c "^local-share/" "${BACKUP_DIR}/metadata/manifest.txt" 2>/dev/null || echo "0")
    echo -e "${BLUE}  Files in backup: ${FILE_COUNT} config files, ${RESOURCE_COUNT} resource files${NC}"
    info=$((info + 1))
else
    echo -e "${YELLOW}⚠ Backup manifest missing${NC}"
    warnings=$((warnings + 1))
fi

# Check for hardware-specific files
echo ""
echo -e "${BLUE}--- Checking Hardware-Specific Settings ---${NC}"
if [[ -f "${BACKUP_DIR}/config/kwinoutputconfig.json" ]]; then
    echo -e "${YELLOW}⚠ Display configuration found (kwinoutputconfig.json)${NC}"
    echo -e "${YELLOW}  WARNING: This is hardware-specific!${NC}"
    echo -e "${YELLOW}  Restoring on different hardware may cause display issues${NC}"
    echo -e "${YELLOW}  Recommendation: Use --skip-display-config when restoring${NC}"
    warnings=$((warnings + 1))
else
    echo -e "${GREEN}✓ No display configuration (safe for different hardware)${NC}"
    info=$((info + 1))
fi

# Check autostart entries
echo ""
echo -e "${BLUE}--- Checking Autostart Entries ---${NC}"
if [[ -d "${BACKUP_DIR}/config/autostart" ]]; then
    AUTOSTART_FILES=($(find "${BACKUP_DIR}/config/autostart" -name "*.desktop" 2>/dev/null || true))
    if [[ ${#AUTOSTART_FILES[@]} -gt 0 ]]; then
        echo -e "${BLUE}Found ${#AUTOSTART_FILES[@]} autostart entry(ies):${NC}"
        for file in "${AUTOSTART_FILES[@]}"; do
            app_name=$(basename "$file" .desktop)
            echo -e "${BLUE}  - ${app_name}${NC}"
        done
        echo -e "${YELLOW}  Verify these applications exist on the target system${NC}"
        warnings=$((warnings + 1))
    else
        echo -e "${GREEN}✓ No autostart entries${NC}"
        info=$((info + 1))
    fi
else
    echo -e "${GREEN}✓ No autostart directory${NC}"
    info=$((info + 1))
fi

# Check user resources
echo ""
echo -e "${BLUE}--- Checking User Resources ---${NC}"
if [[ -d "${BACKUP_DIR}/local-share/plasma/desktoptheme" ]]; then
    THEME_COUNT=$(find "${BACKUP_DIR}/local-share/plasma/desktoptheme" -maxdepth 1 -type d 2>/dev/null | wc -l)
    THEME_COUNT=$((THEME_COUNT - 1)) # Subtract the directory itself
    if [[ $THEME_COUNT -gt 0 ]]; then
        echo -e "${GREEN}✓ Found ${THEME_COUNT} Plasma theme(s)${NC}"
        info=$((info + 1))
    fi
fi

if [[ -d "${BACKUP_DIR}/local-share/icons" ]]; then
    ICON_COUNT=$(find "${BACKUP_DIR}/local-share/icons" -maxdepth 1 -type d 2>/dev/null | wc -l)
    ICON_COUNT=$((ICON_COUNT - 1))
    if [[ $ICON_COUNT -gt 0 ]]; then
        echo -e "${GREEN}✓ Found ${ICON_COUNT} icon theme(s)${NC}"
        info=$((info + 1))
    fi
fi

# Check file permissions and readability
echo ""
echo -e "${BLUE}--- Checking File Permissions ---${NC}"
PERM_ERRORS=0
find "${BACKUP_DIR}/config" -type f 2>/dev/null | while read -r file; do
    if [[ ! -r "$file" ]]; then
        echo -e "${RED}✗ ERROR: Cannot read file: ${file}${NC}"
        PERM_ERRORS=$((PERM_ERRORS + 1))
    fi
done

if [[ $PERM_ERRORS -eq 0 ]]; then
    echo -e "${GREEN}✓ All files are readable${NC}"
    info=$((info + 1))
else
    errors=$((errors + PERM_ERRORS))
fi

# Check for Plasma version compatibility
echo ""
echo -e "${BLUE}--- Checking Version Compatibility ---${NC}"
if [[ -f "${BACKUP_DIR}/metadata/system-info.txt" ]]; then
    BACKUP_PLASMA=$(grep -i "plasma version" "${BACKUP_DIR}/metadata/system-info.txt" 2>/dev/null | head -1 || echo "")
    if [[ -n "$BACKUP_PLASMA" ]]; then
        echo -e "${BLUE}Backup created on: ${BACKUP_PLASMA}${NC}"
        
        CURRENT_PLASMA=$(plasmashell --version 2>/dev/null | head -1 || echo "Unknown")
        if [[ "$CURRENT_PLASMA" != "Unknown" ]]; then
            echo -e "${BLUE}Current system: ${CURRENT_PLASMA}${NC}"
            
            # Extract major versions
            BACKUP_MAJOR=$(echo "$BACKUP_PLASMA" | grep -oE '[0-9]+\.[0-9]+' | cut -d. -f1 || echo "")
            CURRENT_MAJOR=$(echo "$CURRENT_PLASMA" | grep -oE '[0-9]+\.[0-9]+' | cut -d. -f1 || echo "")
            
            if [[ -n "$BACKUP_MAJOR" ]] && [[ -n "$CURRENT_MAJOR" ]]; then
                if [[ "$BACKUP_MAJOR" == "$CURRENT_MAJOR" ]]; then
                    echo -e "${GREEN}✓ Plasma version compatible (both ${BACKUP_MAJOR}.x)${NC}"
                    info=$((info + 1))
                else
                    echo -e "${RED}✗ ERROR: Major version mismatch!${NC}"
                    echo -e "${RED}  Backup: Plasma ${BACKUP_MAJOR}.x, Current: Plasma ${CURRENT_MAJOR}.x${NC}"
                    echo -e "${YELLOW}  Some settings may not be compatible${NC}"
                    errors=$((errors + 1))
                fi
            fi
        else
            echo -e "${YELLOW}⚠ Cannot determine current Plasma version${NC}"
            warnings=$((warnings + 1))
        fi
    fi
fi

# Summary
echo ""
echo -e "${BLUE}=== Validation Summary ===${NC}"
echo -e "${GREEN}✓ Passed checks: ${info}${NC}"
if [[ $warnings -gt 0 ]]; then
    echo -e "${YELLOW}⚠ Warnings: ${warnings}${NC}"
fi
if [[ $errors -gt 0 ]]; then
    echo -e "${RED}✗ Errors: ${errors}${NC}"
fi
echo ""

if [[ $errors -eq 0 ]] && [[ $warnings -eq 0 ]]; then
    echo -e "${GREEN}✓✓✓ Backup validation PASSED - Safe to restore${NC}"
    exit 0
elif [[ $errors -eq 0 ]]; then
    echo -e "${YELLOW}⚠ Backup validation PASSED with warnings${NC}"
    echo -e "${YELLOW}  Review warnings above before restoring${NC}"
    exit 0
else
    echo -e "${RED}✗ Backup validation FAILED${NC}"
    echo -e "${RED}  Fix errors before attempting restore${NC}"
    exit 1
fi

