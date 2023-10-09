# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Add wisely, as too many plugins slow down shell startup.
plugins=(asdf git)

if [ -f ~/.local.zsh ]; then
  source ~/.local.zsh
fi

source $ZSH/oh-my-zsh.sh

function precmd {
    PREV_EXIT=$?
    if [ "$PRECMD_NEWLINE_LOGIN" -eq 1 ]; then
        if [ "$PREV_EXIT" -eq 0 ]; then
            printf "$(tput setaf 2)➜$(tput sgr0) $PREV_EXIT\n"
        else
            printf "$(tput setaf 1)➜$(tput sgr0) $PREV_EXIT\n"
        fi
    else
        export PRECMD_NEWLINE_LOGIN=1
    fi
}

export PROMPT='$(git_prompt_info) %{$fg[blue]%}\$%{$reset_color%} '

export EDITOR='emacs -nw'
