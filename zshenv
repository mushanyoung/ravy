export RAVY_HOME="${0:A:h}"

# paths operations
prepend_to_path () { for arg in "$@"; do [ -d "$arg" ] && path[1,0]="$arg"; done; }
append_to_path  () { for arg in "$@"; do [ -d "$arg" ] && path+="$arg";     done; }
append_to_fpath () { for arg in "$@"; do [ -d "$arg" ] && fpath+="$arg";    done; }

# source custom
[ -f "$RAVY_HOME/custom/zshenv" ] && source "$RAVY_HOME/custom/zshenv"

prepend_to_path "$RAVY_HOME/bin"
append_to_fpath "$RAVY_HOME/zsh-functions"

for brewprefix ("/home/linuxbrew/.linuxbrew" "/usr/local" "$HOME/.brew" "$HOME/.linuxbrew"); do
  if [ -f "$brewprefix/bin/brew" ]; then
    eval "$($brewprefix/bin/brew shellenv)"
    if [ -f "$brewprefix/opt/ruby/bin/ruby" ]; then
      setopt +o nomatch
      prepend_to_path "$brewprefix"/lib/ruby/gems/*/bin
      setopt -o nomatch
      prepend_to_path "$brewprefix/opt/ruby/bin"
    fi
    append_to_fpath "$brewprefix/share/zsh/site-functions"
    break
  fi
done
unset brewprefix

# path and fpath are exported as unique sets
typeset -U path
typeset -U fpath
typeset -U manpath
export PATH
export FPATH
export MANPATH

# MANPATH should always have a leading colon to search with executables
[[ ! $MANPATH =~ ^: ]] && export MANPATH=":$MANPATH"
