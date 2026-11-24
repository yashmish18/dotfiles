# kajukatli · shell extras, sourced from ~/.bashrc and ~/.zshrc by install.sh
# works in bash and zsh.

case $- in *i*) ;; *) return 0 2>/dev/null ;; esac

_kk_shell="$(basename "${ZSH_NAME:-${BASH:-sh}}")"
case "$_kk_shell" in zsh) _kk_init=zsh ;; *) _kk_init=bash ;; esac

# ---------------------------------------------------------------- completion
if [ "$_kk_init" = zsh ]; then
    # menu-style completion that ignores case, plus fish-like suggestions as you type
    autoload -Uz compinit && compinit -d "${XDG_CACHE_HOME:-$HOME/.cache}/zcompdump"
    zstyle ':completion:*' menu select
    zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
    zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
    HISTFILE="$HOME/.zsh_history"; HISTSIZE=20000; SAVEHIST=20000
    setopt share_history hist_ignore_dups hist_ignore_space auto_cd interactive_comments
    bindkey -e
    # ↑ / ↓: history, narrowed to what you've typed so far, with the cursor at the end of the line
    autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
    zle -N up-line-or-beginning-search; zle -N down-line-or-beginning-search
    bindkey '^[[A' up-line-or-beginning-search;   bindkey '^[OA' up-line-or-beginning-search
    bindkey '^[[B' down-line-or-beginning-search; bindkey '^[OB' down-line-or-beginning-search
    # autocorrect: a mistyped command (gti → git) is offered fixed before it runs
    setopt correct
    SPROMPT='  did you mean %F{16}%r%f? [y]es [n]o [e]dit [a]bort '
    bindkey '^[[1;5C' forward-word; bindkey '^[[1;5D' backward-word
    for _kk_p in /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh                  /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
        [ -r "$_kk_p" ] && . "$_kk_p"
    done
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=19'      # the faint text colour of the current theme
    bindkey '^ ' autosuggest-accept               # ctrl + space takes the suggestion
else
    # bash: real completion, case-insensitive, shown at the first tab, cycling with more tabs
    [ -r /usr/share/bash-completion/bash_completion ] && . /usr/share/bash-completion/bash_completion
    bind 'set completion-ignore-case on' 2>/dev/null
    bind 'set show-all-if-ambiguous on' 2>/dev/null
    bind 'set menu-complete-display-prefix on' 2>/dev/null
    bind 'set colored-stats on' 2>/dev/null
    bind 'TAB:menu-complete' 2>/dev/null
    bind '"\e[Z":menu-complete-backward' 2>/dev/null
    # ↑ / ↓: history with the cursor at the end of the line. page up / down search by what
    # you've typed so far (bash can't do both on one key and keep the cursor at the end)
    bind '"\e[A":previous-history' 2>/dev/null
    bind '"\e[B":next-history' 2>/dev/null
    bind '"\e[5~":history-search-backward' 2>/dev/null
    bind '"\e[6~":history-search-forward' 2>/dev/null
    bind 'set history-preserve-point off' 2>/dev/null
    HISTSIZE=20000; HISTFILESIZE=20000; HISTCONTROL=ignoreboth; shopt -s histappend autocd 2>/dev/null
    # autocorrect: small typos in folder names are fixed for cd and completion
    shopt -s cdspell dirspell 2>/dev/null
fi

# a command that isn't installed: say which package has it (pkgfile, in the terminal extra)
[ -r "/usr/share/doc/pkgfile/command-not-found.$_kk_init" ] && . "/usr/share/doc/pkgfile/command-not-found.$_kk_init"

command -v starship >/dev/null && eval "$(starship init $_kk_init)"
command -v zoxide   >/dev/null && eval "$(zoxide init $_kk_init)"
if command -v fzf >/dev/null; then
    eval "$(fzf --$_kk_init 2>/dev/null)" 2>/dev/null
    # colours are kitty palette slots that kk-theme fills from the wallpaper (16 = accent)
    export FZF_DEFAULT_OPTS="--color=bg+:0,bg:-1,spinner:16,hl:16,fg:18,header:19,info:19,pointer:16,marker:16,fg+:20,prompt:16,hl+:16,border:19 --prompt='› ' --pointer='›' --layout=reverse --border=none"
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
alias meow='kk-hello'      # KK_HELLO_FIGURE=1 meow: your wallpaper's figure as the logo
alias ..='cd ..'
alias ...='cd ../..'
alias icat='kitten icat'
alias ssh='kitten ssh'        # brings kitty's terminfo along
alias wall='kk-wall'
alias doctor='kk-doctor'
alias update='sudo pacman -Syu && { command -v paru >/dev/null && paru -Sua || command -v yay >/dev/null && yay -Sua; }'

unset _kk_shell _kk_init

# ---------------------------------------------------------------- hello
# fastfetch once per new terminal window (not in every subshell, split or tmux pane)
if command -v fastfetch >/dev/null && [ -z "${KK_GREETED:-}" ] && [ "${SHLVL:-1}" -le 2 ] && [ -z "${TMUX:-}" ]; then
    export KK_GREETED=1
    if command -v kk-hello >/dev/null; then kk-hello; else fastfetch; fi
fi
