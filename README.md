# System Backup Repository

This repository contains backups of my Debian system configuration for easy restoration on other machines.

## 🎯 One-Click Recovery

Restore your complete Debian system with a **single command**:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/weifeng-work/system-sync/main/restore-system.sh)
```

**Or manually:**

```bash
git clone git@github.com:weifeng-work/system-sync.git
cd system-sync && bash restore-system.sh
```

## Directory Structure

- `debian-packages/` - APT package lists (dpkg --get-selections, manual packages)
- `etc-system/` - Essential /etc configuration tar.gz (apt, x11, pulse, fcitx5)
- `user-config/` - User home configuration tar.gz (shells, xfce, etc)
- `fcitx5/` - Fcitx5 configuration and source patches
- `large-files/` - Large data files (five-bus dictionary, etc)
- `scripts/` - Backup/restore scripts

## Restoration

Run the restore script from the `scripts/` directory, or use the one-liner above.

## fcitx5 Custom Input Method

This setup includes custom fcitx5 modifications:
- `libime-table-fix.patch` - libime shouldReplaceCandidate fix
- `fcitx5-table-hotkeys.patch` - fcitx5-chinese-addons hotkey enhancements
- `config/table.conf` - Custom hotkeys: Ctrl+Shift+Z (dict), Ctrl+1-9 (promote), Ctrl+Shift+1-9 (forget)

## Backup Process

The backup was created using `backup-system.sh` which captures:
- APT package selections and manual packages
- `/etc` essential configurations (APT sources, X11, Pulse, fcitx5)
- User home configuration (shells, XFCE, fcitx5)
- fcitx5 source code patches for custom input method features
