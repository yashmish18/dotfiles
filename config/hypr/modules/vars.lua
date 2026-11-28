-- shared names used by the other modules
KK = {
    mod      = "SUPER",
    terminal = "kitty --single-instance",   -- one process for all windows: shares memory between terminals
    -- a new file manager window every time: nautilus, or whichever is installed (falls back if kk-files isn't installed yet)
    files    = "sh -c '[ -x \"$HOME/.local/bin/kk-files\" ] && exec \"$HOME/.local/bin/kk-files\"; exec nautilus --new-window'",
    browser  = "firefox",
    -- quickshell registers global shortcuts as "kajukatli:<name>"
    shell    = "kajukatli",
}

-- shell actions go over the shell's own ipc: it works whether or not hyprland's global
-- shortcuts reach quickshell on this setup
function KK.shell_action(name)
    return hl.dsp.exec_cmd("qs -c " .. KK.shell .. " ipc call shell run " .. name)
end
