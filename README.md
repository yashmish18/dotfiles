# kajukatli

a desktop for arch + hyprland, in black and white.
grain, serif italics, film-frame numbers, and one muted colour borrowed from whatever wallpaper you're looking at.

- **wallpaper engine**: still pictures get a 3d depth parallax. when you change wallpaper, the subject (a character, a person, an object) is found and *drawn* first, stroke by stroke, and then ink bleeds outward from it to reveal the new picture. gifs and videos play too, and pause when they're covered or you're on battery.
- **one pill for a bar**: it grows into the control center, calendar, media, notifications, launcher, clipboard and power menu. no dock.
- **control center**: wi-fi (join networks and type passwords in place), bluetooth (scan, pair, connect, battery), sound (output device and per-app volume), brightness, night light, quiet mode, stay-awake, power profile. every page links to the full app (network manager, blueman, pavucontrol).
- **workspaces**: they appear when you go to them and disappear when they're empty. `super + tab` shows them all as frames. drag windows between them, rename them, open new ones.
- **lock screen**: a frame of black and white film. sprocket holes along the top with edge print that counts up every time you lock, 12 fps grain, a warm light leak that comes and goes, and a line of late-night writing.
- **light on battery and ram**: the whole desktop is one quickshell process. no blur anywhere. the nvidia card sleeps unless you ask for it. live wallpapers freeze to a still frame on battery.

---

## what's in here

```
dotfiles/
├── install.sh                 sets up everything (asks before touching the system)
├── uninstall.sh               removes the links and puts your old files back
├── packages/packages.txt      every package, one per line (repo or aur, the script decides)
│
├── config/                    → linked into ~/.config
│   ├── hypr/
│   │   ├── hyprland.lua       entry point (hyprland ≥ 0.55 lua config); loads modules/
│   │   ├── modules/
│   │   │   ├── vars.lua       terminal, file manager, browser, the shell's name
│   │   │   ├── env.lua        wayland env for qt / gtk / electron / firefox, cursor
│   │   │   ├── gpu.lua        written by install.sh: pins hyprland to the igpu on hybrid laptops
│   │   │   ├── monitors.lua   "preferred, auto". put exact monitor lines in user.lua
│   │   │   ├── look.lua       gaps, 1px borders, no blur, slow film-like animations
│   │   │   ├── theme.lua      border colour, rewritten by kk-theme from the wallpaper
│   │   │   ├── input.lua      keyboard, touchpad, 3-finger workspace swipe
│   │   │   ├── binds.lua      every key (super + / shows them on screen)
│   │   │   ├── rules.lua      floating dialogs, picture-in-picture, idle-inhibit on fullscreen
│   │   │   ├── autostart.lua  the shell, hypridle, clipboard history, polkit
│   │   │   └── user.lua       yours. never overwritten
│   │   ├── hypridle.conf      dim 2m · lock 5m · screen off 6m · suspend 15m (battery only)
│   │   ├── hyprlock.conf      fallback lock screen if the shell isn't running
│   │   └── xdph.conf          screen-sharing portal
│   │
│   ├── quickshell/kajukatli/  the desktop shell (qml)
│   │   ├── shell.qml          entry point: modules, global shortcuts, ipc
│   │   ├── services/          the logic, no drawing
│   │   │   ├── Theme.qml      colours, fonts, sizes, motion (accent follows the wallpaper)
│   │   │   ├── Config.qml     ~/.config/kajukatli/settings.json
│   │   │   ├── Store.qml      remembered state (current wallpaper, film frame)
│   │   │   ├── Ui.qml         which panel / overlay is open
│   │   │   ├── Hypr.qml       workspace + window helpers over hyprland ipc
│   │   │   ├── Net.qml        networkmanager via nmcli, event driven (no polling)
│   │   │   ├── Bt.qml         bluetooth via bluez
│   │   │   ├── Audio.qml      pipewire: volume, mic, outputs, per-app streams
│   │   │   ├── Bright.qml     brightnessctl
│   │   │   ├── Power.qml      battery, power profiles, night light, stay-awake, low battery warnings
│   │   │   ├── Notifs.qml     the notification daemon (no dunst / mako needed)
│   │   │   └── Wall.qml       the wallpaper engine's brain: prep → ink → theme → video
│   │   ├── modules/
│   │   │   ├── wallpaper/     the background layer: two picture slots + the ink/parallax shader
│   │   │   ├── bar/           the pill: workspaces, now playing, clock, tray, status
│   │   │   ├── panels/        what the pill grows into (control, calendar, media, launcher…)
│   │   │   ├── notifications/ toasts
│   │   │   ├── osd/           volume / brightness
│   │   │   ├── overlays/      workspace overview, wallpaper contact sheet, keybind cheatsheet
│   │   │   └── lock/          the film lock screen (wayland session-lock + pam)
│   │   ├── components/        small pieces: text, buttons, toggles, sliders, fields, cards
│   │   ├── shaders/           wallpaper.frag (ink + parallax), film.frag (lock), grain, mono
│   │   └── pam/password.conf  lets the lock screen check your password (pam_unix)
│   │
│   ├── kitty/kitty.conf       cursor with a tail, film-frame tab numbers, serif-ish italics
│   ├── fastfetch/             a sleepy cat with a cigarette, and the facts
│   ├── starship.toml          lowercase prompt, a small arrow
│   ├── shell/kajukatli.sh     aliases, zoxide, fzf colours, the greeting (bash + zsh)
│   ├── gtk-3.0/ gtk-4.0/      adw-gtk3 dark, papirus icons, plex sans
│   ├── qt6ct/                 fusion + the generated palette (dolphin and other qt apps)
│   └── kajukatli/             settings.json lives here
│
├── bin/                       → linked into ~/.local/bin
│   ├── kk-prep                makes a wallpaper bundle: depth, subject outline, ink map, accent
│   ├── kk-theme               spreads the accent to the shell, kitty, hyprland, gtk, qt, kde
│   ├── kk-wall                set / next / prev / random / redetect, from a terminal
│   ├── kk-lock                lock (falls back to hyprlock if the shell is down)
│   ├── kk-shot                screenshot area / screen / window → clipboard + file (+ edit in satty)
│   ├── kk-record              start / stop screen recording (encodes on the igpu)
│   ├── kk-power               "am i on battery?" for hypridle
│   └── kk-doctor              checks every piece and tells you what to fix
│
└── system/                    → installed with sudo
    ├── greetd/config.toml     tuigreet login screen
    ├── bin/kk-session         starts hyprland from the greeter
    ├── modprobe/nvidia.conf   modeset, fine-grained power management, suspend fix
    └── udev/                  stable igpu/dgpu names + nvidia runtime sleep
```

---

## install on arch

### 1 · a base system

if arch is already installed, skip to step 2.

boot the arch iso, connect to the internet (`iwctl` for wi-fi), then:

```sh
archinstall
```

choose a **minimal** profile, a normal user with sudo (wheel), **networkmanager** for networking, and **pipewire** for audio. reboot into the new system and log in on the tty.

### 2 · the rice

```sh
sudo pacman -S --needed git
git clone https://github.com/yashmish18/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

it will:

1. update the system and install the packages (from the aur too, bootstrapping `paru` if you have no aur helper; it asks first)
2. detect your graphics. on a hybrid nvidia laptop it offers the `nvidia-open` driver, makes the nvidia card sleep when idle, and pins hyprland to the integrated gpu
3. link every config. anything already in the way is moved to `~/.local/share/kajukatli/backup/<date>/`
4. compile the shaders
5. build the wallpaper ai in a private python environment (~1 gb, optional) and offer to download the models now
6. enable networkmanager, bluetooth, power-profiles-daemon, and (if you say yes) the greetd login screen
7. set dark gtk/qt defaults and a starting accent colour

then **reboot**, log in, and put some pictures, gifs or videos in `~/Pictures/wallpapers`. press `super + w`.

options: `--yes` (no questions), `--no-ai`, `--links` (only relink), `--shaders`, `--ai`. it's safe to run again at any time.

if something looks off, run `kk-doctor`.

> **older nvidia cards** (gtx 10-series and before) don't work with `nvidia-open`. say no when the installer offers it, and install `nvidia-580xx-dkms` from the aur yourself.

---

## keys

`super + /` shows this list on screen, read live from hyprland.

| | |
|---|---|
| `super + enter` | terminal (kitty) |
| `super + e` | files (dolphin) |
| `super + b` | browser |
| `super + space` | launcher. `=` math · `>` command · `?` web search |
| `super + a` | control center |
| `super + n` | notifications |
| `super + v` | clipboard history |
| `super + w` | wallpapers |
| `super + tab` | workspace overview |
| `super + escape` | lock / sleep / log out / restart / shut down |
| `super + l` | lock |
| `super + q` | close window · `+ shift` kill it |
| `super + f` | fullscreen · `+ shift` maximize |
| `super + t` | float / tile |
| `super + p` | pin a floating window to every workspace |
| `super + c` | center a floating window |
| `super + arrows` | focus · `+ shift` move · `+ ctrl` resize (`super + alt + h/j/k/l` focuses too) |
| `super + 1…0` | workspace · `+ shift` send the window there |
| `super + . / ,` | next / previous workspace (past the last one opens a fresh one) |
| ``super + ` `` | new empty workspace · `+ shift` take the window with you |
| `super + r` | rename this workspace |
| `super + s` | scratchpad · `+ shift` send a window to it |
| `print` | screenshot an area · `+ shift` the whole screen · `super + ctrl + s` area too |
| `super + shift + r` | record the screen (press again to stop) |
| `super + shift + c` | colour picker |
| `super + shift + b` | hide / show the bar |
| three fingers sideways | switch workspace |

---

## the wallpaper engine

```
your file ──► kk-prep (once per file, cached)          ──► the shell
              ├─ display.jpg   sized for the screen         ├─ outline draws itself (subject first)
              ├─ depth.png     depth anything v2            ├─ ink bleeds out from the subject
              ├─ ink.png       outline + drawing order      ├─ 3d parallax: workspace switches pan the
              │                + distance from subject      │   camera, the cursor tilts it over the bare desktop
              └─ palette.json  one muted accent             ├─ kk-theme recolours everything
                                                            └─ videos: mpvpaper takes over after the ink
```

- **pictures**: jpg, png, webp, bmp, tiff. **moving**: mp4, webm, mkv, mov, gif. gifs are converted to mp4 once, because they're very expensive to play.
- the first time a wallpaper is used it takes a few seconds ("developing…" in the bar). after that it's instant.
- **drawn art / anime**: the default subject model is tuned for photos and general images. for illustrations, press `a` in the wallpaper picker to re-detect with the anime model (or set `subjectModel` to `isnet-anime`).
- no subject found? you still get the ink bleed, from the centre.
- the ai step is optional. without it (`--no-ai`) wallpapers still ink-fade, just without the outline and the 3d.
- from a terminal: `kk-wall set ~/Pictures/wallpapers/rain.jpg`, `kk-wall random`, `kk-wall redetect anime`.

---

## settings

`~/.config/kajukatli/settings.json`. it's created on first run, and the shell picks up changes as you save.

| key | default | what it does |
|---|---|---|
| `wallpaperDir` | `~/Pictures/wallpapers` | where the picker looks |
| `parallax` | `true` | 3d depth parallax |
| `cursorParallax` | `true` | also tilt toward the cursor over the bare desktop (off on battery) |
| `parallaxStrength` | `1.0` | 0.2 subtle … 2.0 a lot |
| `transitionMs` | `2600` | how long the outline + ink take |
| `subjectModel` | `birefnet-general-lite` | `isnet-anime` for drawn art, `u2net` for speed |
| `videoOnBattery` | `false` | keep live wallpapers moving when unplugged |
| `autoPowerProfile` | `true` | power-saver on battery, balanced on ac |
| `clock24h` | `true` | |
| `nightLightTemp` | `4200` | kelvin |
| `lockPoetry` | `true` | the line above the clock on the lock screen |
| `notificationTimeout` | `5000` | ms, for apps that don't say |

hyprland: put your own binds, monitors and options in `~/.config/hypr/modules/user.lua`. it's loaded last and never overwritten.

---

## battery & nvidia

- hyprland draws on the integrated gpu. the nvidia card powers off when nothing uses it. check with `cat /sys/bus/pci/devices/*/power/runtime_status` or `kk-doctor`.
- run something on the nvidia card with `prime-run <app>` (games, blender, …). steam: set launch options to `prime-run %command%`.
- **external monitor not showing up?** some laptops wire the hdmi port to the nvidia card. edit `~/.config/hypr/modules/gpu.lua` and use the second line it suggests (`kk-igpu:kk-dgpu`).
- unplugged, the shell drops window shadows, freezes live wallpapers to a still frame, stops the cursor parallax and the lock-screen grain, and switches to power-saver.
- with no blur and one shell process, an idle session should sit well under half a gigabyte of ram. check yours with `free -h` after login.

---

## when something's wrong

| | |
|---|---|
| anything | `kk-doctor` |
| the shell | `pkill qs; qs -c kajukatli` in a terminal shows every error as it happens |
| hyprland config | `hyprctl configerrors` |
| shaders (black wallpaper) | `./install.sh --shaders` |
| wallpaper prep | `kk-prep ~/Pictures/wallpapers/x.jpg --force` prints what it's doing |
| lock screen won't take the password | `ls ~/.config/quickshell/kajukatli/pam/password.conf`. `hyprlock` is the fallback (`super + l` runs it if the shell is down) |
| wi-fi missing | `systemctl status NetworkManager`. iwd / dhcpcd / systemd-networkd must be off |
| ui shows the wrong accent | `kk-theme --reapply` |

## uninstall

```sh
./uninstall.sh
```

this removes every link and restores your backed-up files. it lists what it leaves alone (packages, the login screen, gpu files) and how to remove those too.

---

built on [hyprland](https://hypr.land), [quickshell](https://quickshell.org), [depth anything v2](https://github.com/DepthAnything/Depth-Anything-V2), [rembg](https://github.com/danielgatis/rembg) / birefnet, [mpvpaper](https://github.com/GhostNaN/mpvpaper). the lines on the lock screen are original.
