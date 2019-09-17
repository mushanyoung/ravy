export RAVY_HOME="${0:A:h}"

# path and fpath are exported as unique sets
typeset -U path
typeset -U fpath
export PATH
export FPATH

# paths operations
prepend_to_path    () { [[ -d "$1" ]] && path[1,0]="$1";    }
append_to_path     () { [[ -d "$1" ]] && path+="$1";        }
append_to_fpath    () { [[ -d "$1" ]] && fpath+="$1";       }

# source custom
[[ -f "$RAVY_HOME/custom/zshenv" ]] && source "$RAVY_HOME/custom/zshenv"

prepend_to_path "$RAVY_HOME/bin"
append_to_fpath "$RAVY_HOME/zsh-functions"

for brew in "$HOME/.brew" "$HOME/.linuxbrew" "/home/linuxbrew/.linuxbrew" "/usr/local"; do
  if [[ -f "$brew/bin/brew" && -d "$brew/Cellar" ]]; then
    eval "$($brew/bin/brew shellenv)"
    if [[ -f "$brew/opt/ruby/bin/ruby" ]]; then
      prepend_to_path "$brew/opt/ruby/bin"
    fi
    append_to_fpath "$brew/completions/zsh"
  fi
done
unset brew

# MANPATH should always have a leading colon to search with executables
[[ ! $MANPATH =~ ^: ]] && export MANPATH=":$MANPATH"
