# kajukatli

A desktop shell for Arch Linux and Hyprland that builds its colours and clock from the active wallpaper.

## Preview

| | | |
|---|---|---|
| ![Kajukatli desktop with a player widget](assets/screenshots/kajukatli-preview-1.png) | ![Kajukatli desktop with the November clock](assets/screenshots/kajukatli-preview-2.png) | ![Kajukatli desktop with a media card](assets/screenshots/kajukatli-preview-3.png) |

## Features

- Wallpaper-aware **Material You-style themes**: vibrant, tonal, or monochrome; dark, light, or automatic.
- **Six clock layouts** with optional depth compositing behind the subject of an anime or photo wallpaper.
- A responsive **desktop shell** with docks, floating bars, islands, rails, widgets, panels, notifications, and a lock screen.
- **Live visuals**: Cava waves, bars, or mirrors; lyrics, calendars, system stats, weather, and media controls.
- **Seven looks** that configure the whole desktop in one click.
- **Automatic power saving** on battery, including disabling blur, shadows, live wallpapers, and cursor parallax.
- A **guided installer** that separates essential packages from optional extras and asks before changing system files.

## Looks

Switch with `Super + I`, `Super + Shift + T`, or `kk-look <name>`:

| Look | Bar | Desktop |
|---|---|---|
| `tide` | Floating pill, top | Stacked clock, audio wave, dock |
| `ronin` | Left rail | Giant date, visualiser, player card |
| `komorebi` | Floating pill, top | Hollow-seconds clock, calendar, dock |
| `currents` | Long bar, bottom | Weather, time chip, weekday, lyrics card |
| `dreamer` | Three islands, top | Line clock, system stats, tall player |
| `grove` | None | Serif clock, dock |
| `print` | Long bar, top | Original monochrome Kajukatli style |

Every setting can be changed independently after choosing a look. Use `Super + Shift + E` to drag desktop widgets; positions are stored as fractions of the screen.

## Installation

### 1. Prepare Arch Linux

For a fresh Arch installation, boot the ISO, connect to the internet, and run:

```sh
archinstall
```

Choose a minimal profile, create a regular user with `sudo`, enable NetworkManager, and enable PipeWire for audio.

### 2. Install Kajukatli

```sh
sudo pacman -S --needed git
git clone https://github.com/yashmish18/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

The installer creates a backup before linking configuration and offers these extras:

| # | Extra | Contents |
|---|---|---|
| 1 | Apps | File manager, browser, video player, mixer, Bluetooth and Wi-Fi tools |
| 2 | Capture | Screenshot editor, recorder, and colour picker |
| 3 | Visualiser | Cava |
| 4 | Live wallpapers | MP4, WebM, MKV, MOV, and GIF support through mpvpaper |
| 5 | Terminal | Starship, Fastfetch, Eza, Bat, Zoxide, FZF, and Btop |
| 6 | CJK fonts | Chinese, Japanese, and Korean text |
| 7 | KDE helpers | Archive manager and Qt thumbnails |
| 8 | Greeter | greetd and tuigreet login screen |
| 9 | Wallpaper pack | Public-domain paintings |
| 10 | Wallpaper AI | Subject cut-out and optional 3D depth |

Useful installer flags:

```sh
./install.sh --yes                 # Recommended defaults
./install.sh --minimal             # Essentials only
./install.sh --extras=3,5,10       # Selected extras
./install.sh --links               # Reapply configuration links
./install.sh --shaders             # Reinstall shaders
./install.sh --fonts               # Reinstall fonts
./install.sh --walls               # Reinstall wallpapers
./install.sh --ai                  # Reconfigure subject detection
```

After installation, reboot, log in, and press `Super + W` to open the wallpaper picker. Run `kk-doctor` if any component is missing or misconfigured.

> Nvidia cards from the GTX 10 series and older may not support `nvidia-open`. Decline that option and install `nvidia-580xx-dkms` from the AUR if needed.

## Keybindings

Press `Super + /` to show the live keybinding overlay.

| Shortcut | Action |
|---|---|
| `Super + Enter` | Terminal |
| `Super + E` | Files |
| `Super + B` | Browser |
| `Super + Space` | Launcher |
| `Super + A` | Control centre |
| `Super + I` | Kajukatli settings |
| `Super + N` | Notifications |
| `Super + V` | Clipboard history |
| `Super + W` | Wallpaper picker |
| `Super + Tab` | Workspace overview |
| `Super + L` | Lock |
| `Super + Escape` | Lock, sleep, log out, restart, or shut down |
| `Super + Q` | Close window |
| `Super + F` | Fullscreen |
| `Super + Shift + F` | Maximize |
| `Super + T` | Toggle floating/tiled |
| `Super + Arrow` | Focus window |
| `Super + Shift + Arrow` | Move window |
| `Super + Alt + Arrow` | Resize window |
| `Super + 1–0` | Switch workspace |
| `Super + Shift + 1–0` | Move window to workspace |
| `Print` | Screenshot an area |
| `Super + Shift + Print` | Screenshot the whole screen |
| `Super + Shift + R` | Start/stop screen recording |
| `Super + Shift + C` | Colour picker |
| `Super + Shift + B` | Hide/show the bar |
| `Super + Shift + T` | Next look |
| `Super + Shift + E` | Arrange desktop widgets |

## Wallpaper engine

Wallpaper processing is cached per file:

```text
wallpaper
  -> display copy for the screen
  -> subject cut-out
  -> ink/drawing order map
  -> seed colour and palette
  -> shell theme and clock compositing
```

Supported formats:

- **Photos and images:** JPG, PNG, WebP, BMP, TIFF
- **Live wallpapers:** MP4, WebM, MKV, MOV, GIF

GIF files are converted to MP4 because direct GIF playback is expensive. The first use of a wallpaper prepares a cache; subsequent switches are nearly instant.

To use a specific model or preset:

```sh
kk-wall set ~/Pictures/wallpapers/rain.jpg
kk-wall random
kk-wall redetect anime
kk-prep ~/Pictures/wallpapers/rain.jpg --force --model isnet-anime
```

- `isnet-anime` is tuned for illustrations.
- `birefnet-general-lite` is intended for photographs.
- Press `A` in the wallpaper picker to re-detect the subject.

## Configuration

Main settings:

```text
~/.config/kajukatli/settings.json
~/.config/hypr/modules/user.lua
~/.config/hypr/modules/monitors.lua
~/.config/hypr/modules/binds.lua
```

Important settings:

| Key | Default | Purpose |
|---|---|---|
| `look` | `tide` | Preset look |
| `themeScheme` | `vibrant` | `vibrant`, `tonal`, or `mono` |
| `themeMode` | `dark` | `dark`, `light`, or `auto` |
| `barStyle` | `pill` | `pill`, `bar`, `islands`, `rail`, or `none` |
| `barPosition` | `top` | `top` or `bottom` |
| `clockStyle` | `stack` | `stack`, `hero`, `serif`, `line`, `day`, `date`, or `off` |
| `clockDepth` | `true` | Place the clock behind the wallpaper subject |
| `visualizer` | `wave` | `off`, `wave`, `bars`, or `mirror` |
| `mediaWidget` | `off` | `off`, `lyrics`, `card`, or `portrait` |
| `wallpaperDir` | `~/Pictures/wallpapers` | Wallpaper picker directory |
| `subjectModel` | `isnet-anime` | `isnet-anime`, `birefnet-general-lite`, or `u2net` |
| `aiOnBattery` | `false` | Run subject detection on battery |
| `videoOnBattery` | `false` | Keep live wallpapers animated on battery |
| `parallax` | `true` | Enable 3D depth parallax |
| `cursorParallax` | `true` | Tilt the scene toward the cursor |

Hyprland settings in `modules/user.lua` are loaded last and are never overwritten by the installer.

## Repository layout

```text
dotfiles/
├── bin/                         User commands
├── config/                      Links into ~/.config
├── fonts/                       Bundled fonts
├── packages/                    Package lists
├── system/                      Login and system configuration
├── assets/screenshots/          README screenshots
├── assets/videos/               README demos
├── install.sh                   Installer
└── uninstall.sh                 Uninstaller
```

## Troubleshooting

| Problem | Command |
|---|---|
| Run a full diagnosis | `kk-doctor` |
| View shell errors | `pkill qs; qs -c kajukatli` |
| Check Hyprland config | `hyprctl configerrors` |
| Reinstall shaders | `./install.sh --shaders` |
| Reprocess a wallpaper | `kk-prep ~/Pictures/wallpapers/x.jpg --force` |
| Reapply colours | `kk-theme --reapply` |
| Reset links and shell files | `./install.sh --links --shaders` |
| Lock-screen PAM fails | Check `~/.config/quickshell/kajukatli/pam/password.conf` |
| Wi-Fi is missing | `systemctl status NetworkManager` |

## Updating

```sh
cd ~/dotfiles
git pull
./install.sh --links --shaders
```

Run `./install.sh --ai` after changing wallpaper detection models or dependencies.

## Uninstall

```sh
./uninstall.sh
```

This removes Kajukatli links and restores backed-up configuration files. It reports which packages and system settings remain for manual removal.

## Credits

Built on [Hyprland](https://hypr.land), [Quickshell](https://quickshell.org), [Cava](https://github.com/karlstav/cava), [lrclib](https://lrclib.net), [wttr.in](https://wttr.in), [mpvpaper](https://github.com/GhostNaN/mpvpaper), and Depth Anything V2.
