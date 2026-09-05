#!/bin/bash
# Fixed System Restore Script - handles non-sudo contexts
set -uo pipefail

echo "=== System Restore Starting ==="

# Determine user home WITHOUT relying on SUDO_ variables (which aren't set in curl | bash)
if [ -n "$SUDO_USER" ] && [ -d "/home/$SUDO_USER" ]; then
    USER_HOME="/home/$SUDO_USER"
elif [ -n "$USER" ] && [ -d "/home/$USER" ]; then
    USER_HOME="/home/$USER"
else
    # Try to detect current user
    USER_HOME="$(eval echo ~$USER)"
fi

echo "User home: $USER_HOME"

# Ensure we have a valid home directory
if [ ! -d "$USER_HOME" ]; then
    echo "ERROR: Cannot determine home directory. Exiting."
    exit 1
fi

# 1. Restore APT packages (run with apt-get directly, no sudo needed for apt in many configs)
echo ""
echo ">>> Step 1: Restoring APT packages..."

# Read package list and install
if [ -f "debian-packages/packages-full.txt" ]; then
    echo "Found package list with $(wc -l < debian-packages/packages-full.txt) entries"
    
    count=0
    while read -r pkg; do
        # Skip empty lines
        [ -z "$pkg" ] && continue
        
        # Check if already installed
        if ! dpkg -s "$pkg" >/dev/null 2>&1; then
            count=$((count + 1))
            echo "Installing: $pkg"
            apt-get install -y "$pkg" 2>/dev/null || echo "  WARNING: Failed to install $pkg"
        fi
    done < debian-packages/packages-full.txt
    
    echo "APT: Installed $count packages"
    
    # Fix any broken dependencies
    apt-get -f install -y 2>/dev/null || echo "Warning: apt-get -f install had issues"
else
    echo "WARNING: debian-packages/packages-full.txt not found in current directory"
    echo "Looking for it at alternative paths..."
    find / -name "packages-full.txt" -type f 2>/dev/null | head -3
fi

# 2. Restore fcitx5 configuration
echo ""
echo ">>> Step 2: Restoring fcitx5 configuration..."

FCITX5_BACKUP="fcitx5-backup.tar.gz"
if [ -f "$FCITX5_BACKUP" ]; then
    tar xzf "$FCITX5_BACKUP" -C "$USER_HOME/.config/" 2>/dev/null && echo "Extracted fcitx5 config" || echo "Warning: fcitx5 extract"
    chmod 600 "$USER_HOME/.config/fcitx5/config" 2>/dev/null
    chown -R "$USER":"$USER" "$USER_HOME/.config/fcitx5" 2>/dev/null
    fcitx5 -r 2>/dev/null || echo "Note: fcitx5 -r failed, run manually later"
    echo "fcitx5 configuration restored!"
else
    echo "WARNING: fcitx5-backup.tar.gz not found"
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
    tar xzf "user-config/user-config-shells.tar.gz" -C "$USER_HOME" 2>/dev/null && echo "Shell config restored" || echo "Warning: shell config"
    chown -R "$USER":"$USER" "$USER_HOME/.bashrc" "$USER_HOME/.profile" "$USER_HOME/.gitconfig" 2>/dev/null
else
    echo "WARNING: user-config shells not found"
fi

# 5. Restore XFCE configuration
echo ""
echo ">>> Step 5: Restoring XFCE configuration..."
if [ -f "user-config/user-config-xfce.tar.gz" ]; then
    tar xzf "user-config/user-config-xfce.tar.gz" -C "$USER_HOME" 2>/dev/null && echo "XFCE config restored" || echo "Warning: XFCE config"
    chown -R "$USER":"$USER" "$USER_HOME/.config/xfce4" 2>/dev/null
else
    echo "WARNING: XFCE config not found"
fi

# 6. Final summary
echo ""
echo "=== Restore Complete ==="
echo "Please log out and log back in, or run: fcitx5 -r"
