# kajukatli · shell extras, sourced from ~/.bashrc and ~/.zshrc by install.sh
# works in bash and zsh.

case $- in *i*) ;; *) return 0 2>/dev/null ;; esac

_kk_shell="$(basename "${ZSH_NAME:-${BASH:-sh}}")"
case "$_kk_shell" in zsh) _kk_init=zsh ;; *) _kk_init=bash ;; esac

command -v starship >/dev/null && eval "$(starship init $_kk_init)"
command -v zoxide   >/dev/null && eval "$(zoxide init $_kk_init)"
if command -v fzf >/dev/null; then
    eval "$(fzf --$_kk_init 2>/dev/null)" 2>/dev/null
    export FZF_DEFAULT_OPTS="--color=bg+:#1c1c1c,bg:-1,spinner:#c9b79c,hl:#c9b79c,fg:#8f8a80,header:#5a5650,info:#5a5650,pointer:#c9b79c,marker:#c9b79c,fg+:#e8e4dc,prompt:#c9b79c,hl+:#c9b79c --prompt='› ' --pointer='›' --layout=reverse --border=none"
fi

if command -v eza >/dev/null; then
    alias ls='eza --group-directories-first'
    alias ll='eza -l --git --group-directories-first --time-style=relative'
    alias la='eza -la --git --group-directories-first'
    alias tree='eza --tree --level=3'
fi
command -v bat >/dev/null && alias cat='bat --style=plain --paging=never --theme=ansi'

# small kindnesses
alias please='sudo'
alias meow='fastfetch'
alias ..='cd ..'
alias ...='cd ../..'
alias icat='kitten icat'
alias ssh='kitten ssh'        # brings kitty's terminfo along
alias wall='kk-wall'
alias doctor='kk-doctor'
alias update='sudo pacman -Syu && { command -v paru >/dev/null && paru -Sua || command -v yay >/dev/null && yay -Sua; }'

# a greeting, once per kitty window, never inside tmux/ssh/scripts
if [ -n "$KITTY_WINDOW_ID" ] && [ -z "$TMUX" ] && [ -z "$SSH_TTY" ] && [ "${SHLVL:-1}" -le 2 ] && [ -z "$KK_GREETED" ]; then
    export KK_GREETED=1
    command -v fastfetch >/dev/null && fastfetch
fi
unset _kk_shell _kk_init
