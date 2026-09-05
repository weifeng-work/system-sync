#!/bin/bash
# System Restore Script for system-sync repository
# 一键恢复 Debian 系统配置

set -euo pipefail

# Configuration
REPO_DIR="/tmp/system-sync-clone"  # 或者改为当前目录
USER_HOME="/home/$(logname)"

echo "=== System Restore Starting ==="
echo "This script will restore your system from the backup repository."

# 1. Restore APT packages
echo ""
echo ">>> Step 1: Restoring APT packages..."
echo "Please ensure you have network access to Debian mirrors."

# Read and install packages
if [ -f "$REPO_DIR/debian-packages/packages-full.txt" ]; then
    echo "Installing packages from backup list..."
    # 逐个安装包，跳过已安装的
    while read -r pkg; do
        if ! dpkg -s "$pkg" >/dev/null 2>&1; then
            apt-get install -y "$pkg" 2>&1 | tail -1 || echo "Failed: $pkg"
        fi
    done < <(grep -v '^$' "$REPO_DIR/debian-packages/packages-full.txt")
    
    # Accept any remaining dependencies
    apt-get -f install -y 2>&1 | tail -3
fi

# 2. Restore fcitx5 configuration (关键步骤)
echo ""
echo ">>> Step 2: Restoring fcitx5 configuration..."

FCITX5_BACKUP="$REPO_DIR/fcitx5-backup.tar.gz"
if [ -f "$FCITX5_BACKUP" ]; then
    # 提取 fcitx5 配置到用户配置目录
    tar xzf "$FCITX5_BACKUP" -C "$USER_HOME/.config/"
    
    # 确保权限正确
    chmod 600 "$USER_HOME/.config/fcitx5/config" "$USER_HOME/.config/fcitx5/profile" 2>/dev/null
    chown -R "$(logname):$(logname)" "$USER_HOME/.config/fcitx5" 2>/dev/null
    
    # 重启输入法
    fcitx5 -r 2>/dev/null || echo "fcitx5 restart failed, please run manually"
    echo "fcitx5 configuration restored!"
else
    echo "fcitx5 backup not found, skipping..."
fi

# 3. Restore /etc essential configuration
echo ""
echo ">>> Step 3: Restoring /etc essential configuration..."
ETC_BACKUP="$REPO_DIR/etc-system/etc-essential.tar.gz"
if [ -f "$ETC_BACKUP" ]; then
    tar xzf "$ETC_BACKUP" -C /
    echo "/etc configuration restored!"
else
    echo "/etc backup not found, skipping..."
fi

# 4. Restore user shell configuration
echo ""
echo ">>> Step 4: Restoring user shell configuration..."
SHELL_BACKUP="$REPO_DIR/user-config/user-config-shells.tar.gz"
if [ -f "$SHELL_BACKUP" ]; then
    tar xzf "$SHELL_BACKUP" -C "$USER_HOME"
    chown -R "$(logname):$(logname)" "$USER_HOME/.bashrc" "$USER_HOME/.profile" "$USER_HOME/.gitconfig" 2>/dev/null
    echo "Shell configuration restored!"
fi

# 5. Restore XFCE configuration
XFCE_BACKUP="$REPO_DIR/user-config/user-config-xfce.tar.gz"
if [ -f "$XFCE_BACKUP" ]; then
    tar xzf "$XFCE_BACKUP" -C "$USER_HOME"
    chown -R "$(logname):$(logname)" "$USER_HOME/.config/xfce4" 2>/dev/null
    echo "XFCE configuration restored!"
fi

# 6. Final steps
echo ""
echo "=== Restore Complete ==="
echo "Please log out and log back in, or run: fcitx5 -r"
echo ""
echo "Restored components:"
echo "  - APT packages (from packages-full.txt)"
echo "  - fcitx5 configuration (hotkeys, table, profile)"
echo "  - /etc essential configuration (apt, x11, pulse)"
echo "  - User shell configuration (bashrc, profile, gitconfig)"
echo "  - XFCE desktop configuration"
