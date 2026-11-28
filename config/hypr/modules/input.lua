hl.config({
    input = {
        kb_layout    = "us",
        kb_options   = "",
        repeat_rate  = 35,
        repeat_delay = 280,
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad = {
            natural_scroll       = true,
            tap_to_click         = true,
            disable_while_typing = true,
            clickfinger_behavior = true,
            scroll_factor        = 0.6,
        },
    },
})

-- touchpad gestures live in gestures.lua. the shell re-applies your touchpad settings
-- (settings → input) on top of these at login.
