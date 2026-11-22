-- keybinds. SUPER + / opens a cheatsheet of all of this inside the shell.
local M = KK.mod
local bind = hl.bind
local sh = KK.shell_action
-- our scripts by full path, so they work even if the session started without ~/.local/bin on PATH
local B = (os.getenv("HOME") or "") .. "/.local/bin/"

-- apps
bind(M .. " + Return", hl.dsp.exec_cmd(KK.terminal),  { description = "terminal" })
bind(M .. " + E",      hl.dsp.exec_cmd(KK.files),     { description = "files" })
bind(M .. " + B",      hl.dsp.exec_cmd(KK.browser),   { description = "browser" })

-- shell
bind(M .. " + Space",  sh("launcher"),      { description = "launcher" })
bind(M .. " + A",      sh("control"),       { description = "control center" })
bind(M .. " + I",      sh("settings"),      { description = "desktop settings" })
bind(M .. " + N",      sh("notifications"), { description = "notifications" })
bind(M .. " + W",      sh("wallpapers"),    { description = "wallpaper picker" })
bind(M .. " + V",      sh("clipboard"),     { description = "clipboard history" })
bind(M .. " + Tab",    sh("overview"),      { description = "workspace overview" })
bind(M .. " + Escape", sh("session"),       { description = "power menu" })
bind(M .. " + slash",  sh("cheatsheet"),    { description = "this cheatsheet" })
bind(M .. " + L",      hl.dsp.exec_cmd(B .. "kk-lock"), { description = "lock" })
bind(M .. " + SHIFT + B", sh("bar"),        { description = "hide / show bar" })
bind(M .. " + SHIFT + E", sh("edit"),       { description = "arrange desktop widgets" })
bind(M .. " + SHIFT + T", sh("look_next"),  { description = "next look (preset)" })
bind(M .. " + Z",         sh("focus"),      { description = "focus mode" })
bind(M .. " + SHIFT + P", sh("timer"),      { description = "start / pause the timer" })

-- windows
bind(M .. " + Q",         hl.dsp.window.close(),                       { description = "close window" })
bind(M .. " + SHIFT + Q", hl.dsp.window.kill(),                        { description = "kill window" })
bind(M .. " + F",         hl.dsp.window.fullscreen({ mode = "fullscreen" }), { description = "fullscreen" })
bind(M .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximized" }),  { description = "maximize" })
bind(M .. " + T",         hl.dsp.window.float({ action = "toggle" }),  { description = "float / tile" })
bind(M .. " + P",         hl.dsp.window.pin({ action = "toggle" }),    { description = "pin floating window" })
bind(M .. " + J",         hl.dsp.layout("togglesplit"),                { description = "flip split" })
bind(M .. " + C",         hl.dsp.window.center(),                      { description = "center floating window" })

local dirs = { left = "left", right = "right", up = "up", down = "down", h = "left", l = "right", k = "up", j = "down" }
for key, dir in pairs(dirs) do
    -- SUPER+L and SUPER+J are taken above, so vim keys need ALT for focus
    local focus_mod = (key == "h" or key == "j" or key == "k" or key == "l") and (M .. " + ALT + ") or (M .. " + ")
    bind(focus_mod .. key,         hl.dsp.focus({ direction = dir }))
    bind(M .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = dir }))
end

local step = 40
bind(M .. " + ALT + left",  hl.dsp.window.resize({ x = -step, y = 0, relative = true }), { repeating = true, description = "resize window" })
bind(M .. " + ALT + right", hl.dsp.window.resize({ x =  step, y = 0, relative = true }), { repeating = true })
bind(M .. " + ALT + up",    hl.dsp.window.resize({ x = 0, y = -step, relative = true }), { repeating = true })
bind(M .. " + ALT + down",  hl.dsp.window.resize({ x = 0, y =  step, relative = true }), { repeating = true })

-- ctrl + super + ← →: previous / next workspace (like a laptop's desktop switch). ↑: overview
bind(M .. " + CTRL + left",  sh("ws_prev"),  { description = "previous workspace" })
bind(M .. " + CTRL + right", sh("ws_next"),  { description = "next workspace" })
bind(M .. " + CTRL + up",    sh("overview"), { description = "workspace overview" })

bind(M .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
bind(M .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- workspaces. they are made when you go to them and vanish when emptied.
for i = 1, 10 do
    local key = i % 10
    bind(M .. " + " .. key,         hl.dsp.focus({ workspace = tostring(i) }))
    bind(M .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = tostring(i) }))
end
bind(M .. " + period",          sh("ws_next"),     { description = "next workspace" })
bind(M .. " + comma",           sh("ws_prev"),     { description = "previous workspace" })
bind(M .. " + mouse_down",      sh("ws_next"))
bind(M .. " + mouse_up",        sh("ws_prev"))
bind(M .. " + grave",           sh("ws_new"),      { description = "new empty workspace" })
bind(M .. " + SHIFT + grave",   sh("ws_new_move"), { description = "move window to new workspace" })
bind(M .. " + R",               sh("ws_rename"),   { description = "rename workspace" })

-- scratchpad
bind(M .. " + S",         hl.dsp.workspace.toggle_special("magic"),           { description = "scratchpad" })
bind(M .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }), { description = "send to scratchpad" })

-- screenshots & recording
bind("Print",              sh("capture"),                            { description = "screenshot / record: pick what" })
bind("SHIFT + Print",      hl.dsp.exec_cmd(B .. "kk-shot screen"),   { description = "screenshot the screen" })
bind("CTRL + Print",       hl.dsp.exec_cmd(B .. "kk-shot region"),   { description = "screenshot a region" })
bind("ALT + Print",        hl.dsp.exec_cmd(B .. "kk-shot window"),   { description = "screenshot the window" })
bind(M .. " + CTRL + S",   sh("capture"),                            { description = "screenshot / record (no print key)" })
bind(M .. " + SHIFT + R",  hl.dsp.exec_cmd(B .. "kk-record region"), { description = "record a region (again: stop)" })
bind(M .. " + SHIFT + C",  hl.dsp.exec_cmd("hyprpicker -a"),  { description = "colour picker" })

-- hardware keys (work on the lock screen too)
bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })
bind("XF86MonBrightnessUp",   sh("brightness_up"),   { locked = true, repeating = true })
bind("XF86MonBrightnessDown", sh("brightness_down"), { locked = true, repeating = true })
bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
