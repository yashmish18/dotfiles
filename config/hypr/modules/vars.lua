-- shared names used by the other modules
KK = {
    mod      = "SUPER",
    terminal = "kitty",
    files    = "dolphin",
    browser  = "firefox",
    -- quickshell registers global shortcuts as "kajukatli:<name>"
    shell    = "kajukatli",
}

function KK.shell_action(name)
    return hl.dsp.global(KK.shell .. ":" .. name)
end
