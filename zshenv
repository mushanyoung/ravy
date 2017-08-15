export RAVY_HOME="${0:A:h}"
export RAVY_CUSTOM_HOME="$RAVY_HOME/custom"

# make elements in path and fpath unique
typeset -U path
typeset -U fpath

# generates path
prepand_to_path () { [[ -d "$1" ]] && path[1,0]="$1"; }
append_to_fpath () { [[ -d "$1" ]] && fpath+="$1"; }

prepand_to_path "$RAVY_HOME/bin"
prepand_to_path "$RAVY_CUSTOM_HOME/bin"

append_to_fpath "$RAVY_HOME/zsh-functions"
append_to_fpath "$RAVY_CUSTOM_HOME/zsh-functions"

local BREW_PREFIX="$HOME/.brew"
if [[ -d "$BREW_PREFIX" ]]; then
  prepand_to_path "$BREW_PREFIX/bin"
  prepand_to_path "$BREW_PREFIX/sbin"
  append_to_fpath "$BREW_PREFIX/completions/zsh"
  if [[ $MANPATH != *$BREW_PREFIX/share/man* ]]; then
    export MANPATH="$BREW_PREFIX/share/man:$MANPATH"
  fi
  if [[ $INFOPATH != *$BREW_PREFIX/share/info* ]]; then
    export INFOPATH="$BREW_PREFIX/share/info:$INFOPATH"
  fi
  if [[ $XDG_DATA_DIRS != *$BREW_PREFIX/share* ]]; then
    export XDG_DATA_DIRS="$BREW_PREFIX/share:$XDG_DATA_DIRS"
  fi
fi

