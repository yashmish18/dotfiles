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
            scroll_factor        = 0.6,
        },
    },
})

-- three fingers sideways: previous / next workspace
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
