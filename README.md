# kajukatli

a desktop shell for arch + hyprland that takes its colours, and its clock, from the wallpaper.

type: **bricolage grotesque** for the interface, **dm mono** for numbers, and a loud face per look for the desktop clock (syne, unbounded, anton, fraunces). no italics. icons are the shell's own, drawn as vector lines (no icon font).

the clock tucks itself *behind* the person in your wallpaper. the whole desktop recolours from the picture.
an audio wave rolls along the bottom of the screen, synced lyrics scroll beside the album art, and there's a calendar, the weather and your system stats.
seven looks switch the whole thing in one click, and every widget can be dragged wherever you want it.

- **depth clock**: every wallpaper gets its subject cut out once (rembg, cached). the shell draws the clock (and, if you like, the visualiser) *between* the background and that cut-out, inside the wallpaper shader, so it stays glued behind the subject even while the 3d parallax moves the camera.
- **colour from the picture**: `kk-theme` builds a full material-you style scheme (oklch tonal palettes) from the wallpaper's seed colour and applies it to the shell, kitty, hyprland borders, gtk and qt/kde apps. `vibrant`, `tonal`, or `mono` (the original black & white print look); dark, light, or auto.
- **six desktop clocks**: `stack` · `hero` · `serif` · `line` · `day` (weather + slanted time chip + giant weekday) · `date` (a giant day of month with the month across it).
- **widgets**: cava visualiser (wave / bars / mirror), a calendar with week numbers, a player with synced lyrics (lrclib.net) or as a card or a tall portrait, and system stats (cpu, network graph, disk, temperatures, fan, battery). drag them anywhere with `super + shift + e`.
- **bars**: a floating `pill`, a long floating `bar`, three `islands`, a `rail` down the left edge, or `none`. top or bottom. every module (workspaces, media, weather, cpu, volume…) can go in any group. panels pop out next to whatever you clicked.
- **dock**: pinned + running apps, a player pill, and it hides while a window is open.
- **control center, launcher, clipboard, notifications, film lock screen, workspace overview**: all still here, all recoloured.
- **light on battery**: one quickshell process. cava, weather and stats only run while something on screen shows them. unplugged, blur, shadows, cursor parallax and live wallpapers switch off.

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
│   │   │   ├── input.lua      keyboard, touchpad (gestures.lua: 4-finger workspace swipe)
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
│   │   │   ├── Theme.qml      colour roles from the wallpaper (kk-theme), fonts, sizes, motion
│   │   │   ├── Looks.qml      the presets (tide, ronin, komorebi, currents, dreamer, grove, print)
│   │   │   ├── Media.qml      the active player, position, synced lyrics (lrclib.net)
│   │   │   ├── Cava.qml       the audio visualiser feed (runs only while shown + playing)
│   │   │   ├── Weather.qml    wttr.in, every 20 minutes while shown
│   │   │   ├── Sys.qml        cpu, memory, network, disk, temperatures (via kk-sys)
│   │   │   ├── Icons.qml      every nerd-font glyph in one place
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
│   │   │   ├── wallpaper/     the background layer: picture slots, ink/parallax shader, depth composite
│   │   │   ├── desktop/       clocks, visualiser, calendar, player, stats; drag-to-arrange
│   │   │   ├── dock/          pinned + running apps and a player pill
│   │   │   ├── bar/           pill / bar / islands / rail, and every module that goes in them
│   │   │   ├── panels/        what the pill grows into (control, calendar, media, launcher…)
│   │   │   ├── notifications/ toasts
│   │   │   ├── osd/           volume / brightness
│   │   │   ├── overlays/      workspace overview, wallpaper contact sheet, keybind cheatsheet
│   │   │   └── lock/          the film lock screen (wayland session-lock + pam)
│   │   ├── components/        small pieces: text, buttons, toggles, sliders, fields, cards
│   │   ├── shaders/           wallpaper.frag (ink + parallax + depth), film.frag (lock), grain, mono, round
│   │   └── pam/password.conf  lets the lock screen check your password (pam_unix)
│   │
│   ├── kitty/kitty.conf       cursor with a tail, film-frame tab numbers, serif-ish italics
│   ├── fastfetch/             a sleepy cat with a cigarette, and the facts
│   ├── starship.toml          lowercase prompt, a small arrow
│   ├── shell/kajukatli.sh     aliases, zoxide, fzf colours, the greeting (bash + zsh)
│   ├── gtk-3.0/ gtk-4.0/      adw-gtk3 dark, papirus icons, plex sans
│   ├── qt6ct/                 fusion + the generated palette (Nautilus/GTK apps and QT apps)
│   └── kajukatli/             settings.json lives here
│
├── bin/                       → linked into ~/.local/bin
│   ├── kk-prep                makes a wallpaper bundle: depth, subject cut-out, ink map, seed colour
│   ├── kk-theme               builds the colour scheme and spreads it to shell, kitty, hyprland, gtk, qt, kde
│   ├── kk-look                switch looks from a terminal (kk-look tide · kk-look edit)
│   ├── kk-sys                 system counters as json, for the stats widget
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

## looks

`super + i` → **looks**, or `super + shift + t` to flip through them, or `kk-look <name>` in a terminal.

| look | bar | desktop |
|---|---|---|
| `tide` | floating pill, top | huge stacked clock behind the subject, an audio wave along the bottom, dock |
| `ronin` | rail down the left | a giant date in the corner, small visualiser bars, a player card |
| `komorebi` | pill, top | a heavy clock with hollow seconds behind the subject, calendar, dock |
| `currents` | long bar, bottom | weather · time chip · giant weekday, calendar, lyrics card |
| `dreamer` | three islands, top | `12:35 – 09/04` line clock, system stats, a tall player |
| `grove` | none | a big serif clock behind the subject, dock |
| `print` | long bar, top | the original kajukatli: black & white, one muted accent |

a look is only a bundle of settings, so after picking one you can change any single piece on the same page (bar shape, clock face, visualiser, which widgets, dock, colours). `super + shift + e` lets you drag every widget around; positions are saved as fractions of the screen, so they survive a resolution change.

### the depth effect

the clock goes behind the subject when the wallpaper has a cut-out. that needs the wallpaper ai (`./install.sh --ai`, on by default).

- the default subject model is `isnet-anime`, tuned for drawn art. for photos, set `subjectModel` to `birefnet-general-lite`.
- wrong subject, or none found? open the wallpaper picker and press `a`, or **looks → re-detect subject**. the same thing from a terminal: `kk-prep <file> --force --model isnet-anime`.
- live wallpapers: the clock stays in front once the video plays (the subject moves, the cut-out doesn't).

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

it installs the **essentials** (hyprland, the shell, network / bluetooth / sound / power, kitty, the typefaces), then shows a menu of **extras** to switch on or off:

| # | extra | what | size |
|---|---|---|---|
| 1 | apps | files, browser, video player, mixer, bluetooth + wi-fi editors | ~400 mb |
| 2 | capture | screenshot editor, screen recorder, colour picker | ~30 mb |
| 3 | visualizer | cava, for the desktop and bar visualisers | ~2 mb |
| 4 | live-wallpapers | videos and gifs as wallpapers (mpvpaper) | ~5 mb |
| 5 | terminal | starship, fastfetch, eza, bat, zoxide, fzf, btop | ~30 mb |
| 6 | cjk-fonts | chinese / japanese / korean text | ~250 mb |
| 7 | kde-helpers | archive manager, thumbnails for qt apps | ~150 mb |
| 8 | greeter | greetd + tuigreet login screen | ~3 mb |
| 9 | wallpaper-pack | twelve public-domain paintings (hokusai, friedrich, vermeer, klimt…) | ~25 mb |
| 10 | wallpaper-ai | the subject cut-out behind the clock (+ optional 3d depth) | ~200–450 mb |

everything except 6 and 7 is on by default. options: `--yes` (recommended set, no questions), `--minimal` (essentials only), `--extras=3,5,10` (exactly these), and `--links`, `--shaders`, `--fonts`, `--walls`, `--ai` to redo one step. safe to run again any time.

the wallpaper ai asks once: **lite** (u2netp, 5 mb), **anime** (recommended, 170 mb), **full** (anime + parallax depth) or **photo** (birefnet + depth). it no longer pulls in rembg, so there's no numba / scipy / scikit-image (~700 mb saved).

then **reboot**, log in, and press `super + w`.

if something looks off, run `kk-doctor`.

> **older nvidia cards** (gtx 10-series and before) don't work with `nvidia-open`. say no when the installer offers it, and install `nvidia-580xx-dkms` from the aur yourself.

---

## keys

`super + /` shows this list on screen, read live from hyprland.

| | |
|---|---|
| `super + enter` | terminal (kitty) |
| `super + e` | files (nautilus) |
| `super + b` | browser |
| `super + space` | launcher. `=` math · `>` command · `?` web search |
| `super + a` | control center |
| `super + i` | settings: looks, bar, clock, widgets, display, touchpad, keyboard, network, sound, power |
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
| `super + arrows` | focus · `+ shift` move · `+ alt` resize (`super + alt + h/j/k/l` focuses too) |
| `ctrl + super + ← →` | previous / next workspace · `ctrl + super + ↑` overview |
| `super + 1…0` | workspace · `+ shift` send the window there |
| `super + . / ,` | next / previous workspace (past the last one opens a fresh one) |
| ``super + ` `` | new empty workspace · `+ shift` take the window with you |
| `super + r` | rename this workspace |
| `super + s` | scratchpad · `+ shift` send a window to it |
| `print` | screenshot an area · `+ shift` the whole screen · `super + ctrl + s` area too |
| `super + shift + r` | record the screen (press again to stop) |
| `super + shift + c` | colour picker |
| `super + shift + b` | hide / show the bar |
| `super + shift + t` | next look |
| `super + shift + e` | arrange desktop widgets (drag them; `esc` when done) |
| three or four fingers sideways | switch workspace |
| four fingers up / down | workspace overview (drag windows between workspaces, or onto “new”) / close it |
| click the workspaces pill | the same overview |

---

## the wallpaper engine

switching is instant: the picture is decoded at screen size and fades in within half a second, the colours follow a moment later (`kk-prep --fast`, pillow + numpy, no ai), and the subject cut-out and depth arrive in the background at idle priority, without a second transition. on battery the ai waits for the charger (`aiOnBattery` to change that).

```
your file ──► kk-prep (once per file, cached)          ──► the shell
              ├─ display.jpg   sized for the screen         ├─ outline draws itself (subject first)
              ├─ depth.png     depth anything v2            ├─ ink bleeds out from the subject
              ├─ ink.png       outline + drawing order      ├─ 3d parallax: workspace switches pan the
              │                + distance from subject      │   camera, the cursor tilts it over the bare desktop
              ├─ mask.png      soft subject cut-out         ├─ the clock is composited behind the cut-out
              └─ palette.json  seed colour + swatches       ├─ kk-theme recolours everything
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
| `look` | `tide` | the preset last applied (see **looks**) |
| `themeScheme` | `vibrant` | `vibrant`, `tonal`, `mono` |
| `themeMode` | `dark` | `dark`, `light`, `auto` (follows the wallpaper's brightness) |
| `barStyle` | `pill` | `pill`, `bar`, `islands`, `rail`, `none` |
| `barPosition` | `top` | `top`, `bottom` |
| `barModules` | … | `{ left: [], center: [], right: [] }` from: `logo workspaces notifs cpu mem temp clock weather media visualizer volume brightness network bluetooth battery tray power` |
| `workspaceStyle` | `dots` | `dots`, `diamonds`, `numbers` |
| `clockStyle` | `stack` | `stack`, `hero`, `serif`, `line`, `day`, `date`, `off` |
| `clockDepth` | `true` | put the clock behind the wallpaper's subject |
| `clockFont` / `clockScale` | `""` / `1.0` | any installed font family; size multiplier |
| `visualizer` | `wave` | `off`, `wave`, `bars`, `mirror` · `visualizerBehind` puts it behind the subject too |
| `mediaWidget` | `off` | `off`, `lyrics`, `card`, `portrait` |
| `showCalendar` / `showStats` | `false` | desktop calendar, system stats |
| `layout` | `{}` | widget positions, written by `super + shift + e` |
| `dock` / `dockAutoHide` / `dockPinned` | `true` / `true` / kitty, firefox, files | right-click an icon to pin or unpin it |
| `weatherLocation` / `tempUnit` | `""` / `c` | a city name (empty = guess from your ip, via wttr.in) |
| `lyrics` | `true` | fetch synced lyrics from lrclib.net (sends the track's title and artist) |
| `transition` | `fade` | `fade` (0.4 s), `ink` (the drawn outline, needs the ai), `none` |
| `aiOnBattery` | `false` | run the subject detection unplugged too |
| `wallpaperDir` | `~/Pictures/wallpapers` | where the picker looks |
| `parallax` | `true` | 3d depth parallax |
| `cursorParallax` | `true` | also tilt toward the cursor over the bare desktop (off on battery) |
| `parallaxStrength` | `1.0` | 0.2 subtle … 2.0 a lot |
| `transitionMs` | `2600` | how long the outline + ink take |
| `subjectModel` | `isnet-anime` | `birefnet-general-lite` for photos, `u2net` for speed |
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
| ui shows the wrong colours | `kk-theme --reapply` |
| clock isn't behind the subject | `kk-doctor` says whether this wallpaper has a cut-out; re-detect with the anime model |
| no visualiser | `cava` installed? it only moves while something is playing |
| updated the dotfiles | `./install.sh --links --shaders` (new scripts + the new shader) |

## push the dotfiles to GitHub

https push requires GitHub authentication. the commit is not pushed until this succeeds:

1. install github cli:
   ```sh
   sudo pacman -S --needed github-cli
   ```
2. sign in from a terminal:
   ```sh
   gh auth login
   ```
3. choose `GitHub.com`, `HTTPS`, `Login with a web browser`, and confirm the one-time code.
4. verify:
   ```sh
   gh auth status
   git push origin main
   ```

to use ssh instead, add a key with `ssh-keygen -t ed25519 -C "you@example.com"`, add the public key at https://github.com/settings/keys, set `git remote set-url origin git@github.com:yashmish18/dotfiles.git`, and run `git push origin main`.

## uninstall

```sh
./uninstall.sh
```

this removes every link and restores your backed-up files. it lists what it leaves alone (packages, the login screen, gpu files) and how to remove those too.

---

built on [hyprland](https://hypr.land), [quickshell](https://quickshell.org), [cava](https://github.com/karlstav/cava), [lrclib](https://lrclib.net), [wttr.in](https://wttr.in), [depth anything v2](https://github.com/DepthAnything/Depth-Anything-V2), [rembg](https://github.com/danielgatis/rembg) / birefnet, [mpvpaper](https://github.com/GhostNaN/mpvpaper). the lines on the lock screen are original.
