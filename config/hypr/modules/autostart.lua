hl.on("hyprland.start", function()
    -- give the session environment to dbus/systemd activated services (portals, polkit)
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")

    -- the whole desktop: bar, wallpaper, control center, notifications, lock screen
    -- -n: never start a second shell over this one (dbus name clash, double RSS, reload races)
    hl.exec_cmd("qs -n -c kajukatli")
    -- after an auto-login: make sure the screen ends up locked even if the shell doesn't start
    hl.exec_cmd((os.getenv("HOME") or "") .. "/.local/bin/kk-startlock")

    hl.exec_cmd("hypridle")
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
