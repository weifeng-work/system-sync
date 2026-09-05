#!/bin/bash
# System Restore Script for system-sync repository
# 一键恢复 Debian 系统配置

set -uo pipefail  # More forgiving than -e

echo "=== System Restore Starting ==="
echo "Restoring from: https://github.com/weifeng-work/system-sync"

# Determine user home
USER_HOME="${SUDO_HOME:-/home/$SUDO_USER}"
[ -z "$USER_HOME" ] && USER_HOME="/home/$(logname)"

echo "User home: $USER_HOME"

# 1. Restore APT packages
echo ""
echo ">>> Step 1: Restoring APT packages..."

# Read package list and install
if [ -f "debian-packages/packages-full.txt" ]; then
    echo "Found package list with $(wc -l < debian-packages/packages-full.txt) entries"
    
    # Install packages, skipping those already installed
    count=0
    failed=0
    while read -r pkg; do
        # Skip empty lines and comments
        [ -z "$pkg" ] && continue
        # Skip deinstall marked packages
        echo "$pkg" | grep -q '^deinstall' && continue
        
        # Check if already installed
        if ! dpkg -s "$pkg" >/dev/null 2>&1; then
            count=$((count + 1))
            if [ $count -le 5 ] || [ $count -gt $((count + 10)) ]; then
                echo "Installing: $pkg"
            fi
            apt-get install -y "$pkg" 2>/dev/null || {
                failed=$((failed + 1))
                [ $count -le 5 ] && echo "  WARNING: Failed to install $pkg"
            }
        fi
    done < debian-packages/packages-full.txt
    
    echo "APT: Installed $count packages, $failed failed (may be already installed or missing)"
    
    # Fix any broken dependencies
    apt-get -f install -y 2>/dev/null || echo "Warning: apt-get -f install had issues"
else
    echo "WARNING: debian-packages/packages-full.txt not found!"
fi

# 2. Restore fcitx5 configuration
echo ""
echo ">>> Step 2: Restoring fcitx5 configuration..."

FCITX5_BACKUP="fcitx5-backup.tar.gz"
if [ -f "$FCITX5_BACKUP" ]; then
    # Extract to user config directory
    tar xzf "$FCITX5_BACKUP" -C "$USER_HOME/.config/" 2>/dev/null || {
        echo "Warning: Could not extract fcitx5 backup to .config"
        # Try alternative location
        tar xzf "$FCITX5_BACKUP" -C /home/$(logname)/.config/ 2>/dev/null
    }
    
    # Fix permissions
    if [ -f "$USER_HOME/.config/fcitx5/config" ]; then
        chmod 600 "$USER_HOME/.config/fcitx5/config" 2>/dev/null
        chown -R "$(whoami):$(whoami)" "$USER_HOME/.config/fcitx5" 2>/dev/null
        echo "fcitx5 config permissions fixed"
    fi
    
    # Restart input method
    fcitx5 -r 2>/dev/null || echo "Note: fcitx5 -r failed, you can run manually later"
    echo "fcitx5 configuration restored!"
else
    echo "WARNING: fcitx5-backup.tar.gz not found in current directory"
    echo "Looking in repository paths..."
    # Try to find it
    find . -name "fcitx5-backup.tar.gz" 2>/dev/null | head -3
fi

# 3. Restore /etc essential configuration
echo ""
echo ">>> Step 3: Restoring /etc essential configuration..."
if [ -f "etc-system/etc-essential.tar.gz" ]; then
    tar xzf etc-system/etc-essential.tar.gz -C / 2>/dev/null && echo "/etc restored" || echo "Warning: /etc restore had issues"
else
    echo "WARNING: etc-system/etc-essential.tar.gz not found"
fi

# 4. Restore user shell configuration
echo ""
echo ">>> Step 4: Restoring user shell configuration..."
if [ -f "user-config/user-config-shells.tar.gz" ]; then
    tar xzf user-config-user-config-shells.tar.gz -C "$USER_HOME" 2>/dev/null || \
    tar xzf user-config/user-config-shells.tar.gz -C "$USER_HOME" 2>/dev/null
    chown -R "$(whoami):$(whoami)" "$USER_HOME/.bashrc" "$USER_HOME/.profile" "$USER_HOME/.gitconfig" 2>/dev/null
    echo "Shell configuration restored"
else
    echo "WARNING: user-config shells not found"
fi

# 5. Restore XFCE configuration
echo ""
echo ">>> Step 5: Restoring XFCE configuration..."
if [ -f "user-config/user-config-xfce.tar.gz" ]; then
    tar xzf user-config/user-config-xfce.tar.gz -C "$USER_HOME" 2>/dev/null || \
    tar xzf user-config/user-config-xfce.tar.gz -C "$USER_HOME" 2>/dev/null
    chown -R "$(whoami):$(whoami)" "$USER_HOME/.config/xfce4" 2>/dev/null
    echo "XFCE configuration restored"
else
    echo "WARNING: XFCE config not found"
fi

# 6. Final summary
echo ""
echo "=== Restore Complete ==="
echo ""
echo "Restored components:"
echo "  ✓ APT packages (from packages-full.txt)"
echo "  ✓ fcitx5 configuration (hotkeys, table, profile)"
echo "  ✓ /etc essential configuration (apt, x11, pulse)"
echo "  ✓ User shell configuration (bashrc, profile, gitconfig)"
echo "  ✓ XFCE desktop configuration"
echo ""
echo "Important: Please log out and log back in, or run: fcitx5 -r"
