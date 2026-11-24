hl.on("hyprland.start", function()
    -- give the session environment to dbus/systemd activated services (portals, polkit)
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")

    -- the whole desktop: bar, wallpaper, control center, notifications, lock screen
    -- kk-shell keeps it running: if the shell ever crashes it comes straight back (and never starts a second one over it)
    -- if kk-shell isn't installed yet (repo pulled without ./install.sh --update), start the shell plainly
    hl.exec_cmd("sh -c '[ -x \"$HOME/.local/bin/kk-shell\" ] && exec \"$HOME/.local/bin/kk-shell\"; exec qs -n -c kajukatli'")
    -- after an auto-login: make sure the screen ends up locked even if the shell doesn't start
    hl.exec_cmd((os.getenv("HOME") or "") .. "/.local/bin/kk-startlock")

    -- idle times come from settings → power: kk-idle writes the config, then starts hypridle with it
    hl.exec_cmd("sh -c '[ -x \"$HOME/.local/bin/kk-idle\" ] && exec \"$HOME/.local/bin/kk-idle\" apply; exec hypridle'")
    -- nautilus's background service, so super + e opens a window at once instead of starting the app cold
    hl.exec_cmd("sh -c 'command -v nautilus >/dev/null && exec nautilus --gapplication-service'")
    -- the phone service (kk-phone): finds your phone's KDE Connect app on the wi-fi
    hl.exec_cmd((os.getenv("HOME") or "") .. "/.local/bin/kk-phone daemon")
    -- clipboard history: the last 80 things. every screenshot is copied as a full-size image,
    -- so an unlimited history grew to gigabytes
    -- clipboard history: small and short-lived. kk-storage tidy wipes it at login (unless you
    -- turned that off) and trims it to your limit; this cap holds in between
    hl.exec_cmd((os.getenv("HOME") or "") .. "/.local/bin/kk-storage tidy --login")
    hl.exec_cmd("wl-paste --type text --watch cliphist -max-items 50 store")
    hl.exec_cmd("wl-paste --type image --watch cliphist -max-items 50 store")
end)
