# Changelog

## Unreleased

- Control center: one tap switches Wi-Fi and Bluetooth (the arrow opens the list); a battery page with health, watts, cycles, energy and the last 24 hours.
- Bluetooth: paired devices are trusted and saved, reconnect after Bluetooth is switched off and on, retry a failed connect, and have their own controls (auto-connect, block, send file, pair again, forget).
- Phone panel over KDE Connect (new `phone` extra): battery, ring, files, clipboard, browse storage, texts.
- Running apps panel and bar pill: every app, including tray and background apps, with focus, menu, quit and force quit; optional no-background-apps mode. Tray icons open their menu on one tap.
- Task manager (Ctrl + Shift + Esc): processes, memory, storage clean-up, recycle bin, drives with mount/eject/format.
- Software centre: repos, AUR and Flathub in one search; installed, updates, developer bundles and a basics check.
- Graphics: NVIDIA-only mode, switch the NVIDIA card off, heavy apps start on it, and a hint when one starts on the integrated card.
- Workspaces: no gaps after closing one, no empty placeholders, sign-in pages bring you to the browser, overview steps with Super + Tab / arrows and scrolls while dragging, windows can be dropped on other screens.
- Projection: every mode can follow every other (mirror and single-screen modes reset cleanly), rescan reports what it found, no extend-left card; screenshots and recordings take the screen under the pointer or a chosen one.
- Fixes: the 12-hour clock on the desktop, lock screen and vertical bar; weather unit and network toggles apply at once; the clock finds a calm, open spot when it can't tuck behind the subject; the emoji picker pastes into the app you were in and opens in its corner; Super + E always opens a new window; the Up arrow leaves the cursor at the end of the line.
- Installer: records the system before the first install and every system file it changes; `--rollback`; `--update` fetches only the newest dotfiles. `uninstall.sh --all` restores the previous system completely.
- Wallpaper pack is now opt-in; the storage page trims unused wallpaper caches.
- Nautilus themed from the wallpaper, with format/disk usage/send-to-phone/admin scripts; security toolkit extra and `kk-cybersec`.
- Added explicit installer update, dry-run, snapshot, and restore modes.
- Added manifest-aware uninstall with a dry-run preview.
- Added package manifest validation and CI workflows.
- Added direct emoji insertion.
- Added a compact traditional emoji picker with categories and recent emojis.
- Added a dedicated projection menu with automatic HDMI/DP extension.
- Added a graphical package search and install/remove manager.
- Added random wallpaper and monitor hot-plug handling.
