# prevent from loading more than once
[[ -n $RAVY_ENV_LOADED ]] && return 0 || RAVY_ENV_LOADED=true

export RAVY_HOME="${0:A:h}"
export RAVY_CUSTOM_HOME="$RAVY_HOME/custom"

# make elements in path and fpath unique
typeset -U path
typeset -U fpath

# generates path
prepend_to_path () { [[ -d "$1" ]] && path[1,0]="$1"; }
append_to_path () { [[ -d "$1" ]] && path+="$1"; }
append_to_fpath () { [[ -d "$1" ]] && fpath+="$1"; }

# source custom
[[ -f "$RAVY_CUSTOM_HOME/zshenv" ]] && source "$RAVY_CUSTOM_HOME/zshenv"

prepend_to_path "$RAVY_HOME/bin"
prepend_to_path "$RAVY_CUSTOM_HOME/bin"

append_to_fpath "$RAVY_HOME/zsh-functions"
append_to_fpath "$RAVY_CUSTOM_HOME/zsh-functions"

local brew_prefixes=("$HOME/.brew" "$HOME/.linuxbrew")
for brew_prefix in $brew_prefixes; do
  if [[ -f "$brew_prefix/bin/brew" ]]; then
    prepend_to_path "$brew_prefix/bin"
    prepend_to_path "$brew_prefix/sbin"
    append_to_fpath "$brew_prefix/completions/zsh"
    if [[ $MANPATH != *$brew_prefix/share/man* ]]; then
      export MANPATH="$brew_prefix/share/man:$MANPATH"
    fi
    if [[ $INFOPATH != *$brew_prefix/share/info* ]]; then
      export INFOPATH="$brew_prefix/share/info:$INFOPATH"
    fi
    if [[ $XDG_DATA_DIRS != *$brew_prefix/share* ]]; then
      export XDG_DATA_DIRS="$brew_prefix/share:$XDG_DATA_DIRS"
    fi
  fi
done

