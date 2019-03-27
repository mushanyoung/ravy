export RAVY_HOME="${0:A:h}"
export RAVY_CUSTOM_HOME="$RAVY_HOME/custom"

# path, fpath and manpath are exported unique sets
typeset -U path
typeset -U fpath
typeset -U manpath
export PATH
export FPATH
export MANPATH

# paths operations
prepend_to_path    () { [[ -d "$1" ]] && path[1,0]="$1";    }
prepend_to_manpath () { [[ -d "$1" ]] && manpath[1,0]="$1"; }
append_to_path     () { [[ -d "$1" ]] && path+="$1";        }
append_to_fpath    () { [[ -d "$1" ]] && fpath+="$1";       }

# source custom
[[ -f "$RAVY_CUSTOM_HOME/zshenv" ]] && source "$RAVY_CUSTOM_HOME/zshenv"

prepend_to_path "$RAVY_HOME/bin"
prepend_to_path "$RAVY_CUSTOM_HOME/bin"

append_to_fpath "$RAVY_HOME/zsh-functions"
append_to_fpath "$RAVY_CUSTOM_HOME/zsh-functions"

local brew_prefixes=(
"$HOME/.brew"
"$HOME/.linuxbrew"
"/home/linuxbrew/.linuxbrew"
"/usr/local"
)

for brew in $brew_prefixes; do
  if [[ -f "$brew/bin/brew" && -d "$brew/Cellar" ]]; then
    export HOMEBREW_PREFIX="$brew"
    export HOMEBREW_CELLAR="$brew/Cellar"
    export HOMEBREW_REPOSITORY="$brew"

    prepend_to_path "$brew/bin"
    prepend_to_path "$brew/sbin"
    prepend_to_manpath "$brew/share/man"
    append_to_fpath "$brew/completions/zsh"
    if [[ $INFOPATH != *$brew/share/info* ]]; then
      export INFOPATH="$brew/share/info:$INFOPATH"
    fi
  fi
done

