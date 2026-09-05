# System Backup Repository

This repository contains backups of my Debian system configuration for easy restoration on other machines.

## Directory Structure

- `debian-packages/` - APT package lists (dpkg --get-selections, manual packages)
- `etc-system/` - Essential /etc configuration tar.gz (apt, x11, pulse, fcitx5)
- `user-config/` - User home configuration tar.gz (shells, xfce, etc)
- `fcitx5/` - Fcitx5 configuration and source patches
- `large-files/` - Large data files (five-bus dictionary, etc)
- `scripts/` - Backup/restore scripts

## Restoration

Run the restore script from the `scripts/` directory.

## fcitx5 Custom Input Method

This setup includes custom fcitx5 modifications:
- `libime-table-fix.patch` - libime shouldReplaceCandidate fix
- `fcitx5-table-hotkeys.patch` - fcitx5-chinese-addons hotkey enhancements
- `config/table.conf` - Custom hotkeys: Ctrl+Shift+Z (dict), Ctrl+1-9 (promote), Ctrl+Shift+1-9 (forget)
