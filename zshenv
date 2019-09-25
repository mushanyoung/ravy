export RAVY_HOME="${0:A:h}"

# path and fpath are exported as unique sets
typeset -U path
typeset -U fpath
export PATH
export FPATH

# paths operations
prepend_to_path () { for arg in "$@"; do [ -d "$arg" ] && path[1,0]="$arg"; done; }
append_to_path  () { for arg in "$@"; do [ -d "$arg" ] && path+="$arg";     done; }
append_to_fpath () { for arg in "$@"; do [ -d "$arg" ] && fpath+="$arg";    done; }

# source custom
[ -f "$RAVY_HOME/custom/zshenv" ] && source "$RAVY_HOME/custom/zshenv"

prepend_to_path "$RAVY_HOME/bin"
append_to_fpath "$RAVY_HOME/zsh-functions"

for brew in "$HOME/.brew" "/home/linuxbrew/.linuxbrew" "/usr/local"; do
  if [ -f "$brew/bin/brew" ] && [ -e "$brew/Cellar" ]; then
    eval "$($brew/bin/brew shellenv)"
    if [ -f "$brew/opt/ruby/bin/ruby" ]; then
      setopt +o nomatch
      prepend_to_path "$brew"/lib/ruby/gems/*/bin
      setopt -o nomatch
      prepend_to_path "$brew/opt/ruby/bin"
    fi
    append_to_fpath "$brew/completions/zsh"
    break
  fi
done
unset brew

# MANPATH should always have a leading colon to search with executables
[[ ! $MANPATH =~ ^: ]] && export MANPATH=":$MANPATH"
