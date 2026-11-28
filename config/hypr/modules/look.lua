-- thin borders, soft corners. blur only behind the shell's glass (bar, panels, dock) and only
-- on ac power: the shell switches it off when you unplug.
hl.config({
    general = {
        gaps_in     = 5,
        gaps_out    = 12,
        border_size = 2,
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    },

    decoration = {
        rounding       = 12,
        rounding_power = 2,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        dim_special = 0.35,

        shadow = {
            enabled      = true,
            range        = 18,
            render_power = 4,
            color        = 0x66000000,
        },

        -- blur is the most expensive effect hyprland has, so it is kept to the shell's own
        -- translucent surfaces (see rules.lua). opaque windows never pay for it.
        blur = {
            enabled           = true,
            size              = 7,
            passes            = 2,
            new_optimizations = true,
            popups            = false,
        },
    },

    animations = { enabled = true },

    dwindle = { preserve_split = true },
    master  = { new_status = "master" },

    misc = {
        force_default_wallpaper  = 0,
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        focus_on_activate        = true,
        animate_manual_resizes   = false,
        key_press_enables_dpms   = true,
        mouse_move_enables_dpms  = true,
        -- every wallpaper rewrites theme.lua; a config reload on each one re-applied the monitor
        -- rules, and the screen blanked for a moment. colours go in live (hyprctl eval) instead;
        -- after editing the config yourself: super + shift + ctrl + r, or hyprctl reload
        disable_autoreload       = true,
        -- a restarted shell may take over a lock its crashed predecessor left behind
        allow_session_lock_restore = true,
    },

    cursor = {
        hide_on_key_press = true,
        inactive_timeout  = 6,
    },

    binds = { workspace_back_and_forth = 1 },

    ecosystem = {
        no_update_news  = true,
        no_donation_nag = true,
    },

    layers = {
        allow_new_top_layers_over_existing_fullscreen = true,
    },
})

-- motion: unhurried, like a dissolve between two frames. nothing bounces.
hl.curve("film",   { type = "bezier", points = { {0.22, 1},    {0.36, 1} } })
hl.curve("drift",  { type = "bezier", points = { {0.45, 0.05}, {0.25, 1} } })
hl.curve("linear", { type = "bezier", points = { {0, 0},       {1, 1}    } })
hl.curve("soft",   { type = "spring", mass = 1, stiffness = 180, damping = 24 })

hl.animation({ leaf = "global",           enabled = true, speed = 8,   bezier = "film" })
hl.animation({ leaf = "border",           enabled = true, speed = 6,   bezier = "film" })
hl.animation({ leaf = "windows",          enabled = true, speed = 4.5, spring = "soft" })
hl.animation({ leaf = "windowsIn",        enabled = true, speed = 4,   spring = "soft",   style = "popin 94%" })
hl.animation({ leaf = "windowsOut",       enabled = true, speed = 2,   bezier = "linear", style = "popin 94%" })
hl.animation({ leaf = "fade",             enabled = true, speed = 3,   bezier = "film" })
hl.animation({ leaf = "layers",           enabled = true, speed = 3,   bezier = "film" })
hl.animation({ leaf = "workspaces",       enabled = true, speed = 4.2, bezier = "drift", style = "slidefade 8%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3.5, bezier = "film",  style = "slidefadevert 6%" })
