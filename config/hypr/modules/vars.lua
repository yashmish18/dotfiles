-- shared names used by the other modules
KK = {
    mod      = "SUPER",
    terminal = "kitty",
    files    = "nautilus",
    browser  = "firefox",
    -- quickshell registers global shortcuts as "kajukatli:<name>"
    shell    = "kajukatli",
}

-- shell actions go over the shell's own ipc: it works whether or not hyprland's global
-- shortcuts reach quickshell on this setup
function KK.shell_action(name)
    return hl.dsp.exec_cmd("qs -c " .. KK.shell .. " ipc call shell run " .. name)
end
