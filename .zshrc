# Dedupe PATH
typeset -U path PATH

if [ -f "$HOME/.local.zsh" ]; then
  source "$HOME/.local.zsh"
fi

autoload -Uz vcs_info
setopt prompt_subst
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' unstagedstr '✗'
zstyle ':vcs_info:git:*' stagedstr '✗'
zstyle ':vcs_info:git:*' formats '%F{blue}git:(%F{red}%b%F{blue})%f %F{yellow}%u%f'
zstyle ':vcs_info:git:*' actionformats '%F{blue}git:(%F{red}%b%F{blue})%f %F{yellow}%u%f (%a) '
zstyle ':vcs_info:*' nvcsformats ' '

# Collapse staged+unstaged into a single ✗
+vi-git-dirty() {
    if [[ -n ${hook_com[staged]} || -n ${hook_com[unstaged]} ]]; then
        hook_com[unstaged]='✗ '
        hook_com[staged]=''
    fi
}
zstyle ':vcs_info:git*+set-message:*' hooks git-dirty

precmd() {
    local prev_exit=$?
    vcs_info
    if [[ ${PRECMD_NEWLINE_LOGIN:-0} -eq 1 ]]; then
        if (( prev_exit == 0 )); then
            print -P "%F{green}➜%f $prev_exit"
        else
            print -P "%F{red}➜%f $prev_exit"
        fi
    else
        PRECMD_NEWLINE_LOGIN=1
    fi
}

PROMPT='%B${vcs_info_msg_0_}%b%F{blue}$%f '

export EDITOR='emacs -nw'

# Setup asdf
[ -d "${ASDF_DATA_DIR:-$HOME/.asdf}/shims" ] && export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
[ -f "${ASDF_DATA_DIR:-$HOME/.asdf}/completions/_asdf" ] && fpath=("${ASDF_DATA_DIR:-$HOME/.asdf}/completions" $fpath)

# Activate mise
command -v mise >/dev/null && eval "$(mise activate zsh)"

# Initialise completions
autoload -Uz compinit && compinit

export PATH="/usr/local/go/bin:$PATH"
export PATH="$PATH:$HOME/go/bin"

export PATH="$PATH:$HOME/.local/bin"
