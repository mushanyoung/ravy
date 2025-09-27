#!/bin/sh

SHELL=/bin/sh

set -e

# execute with log
__el() { echo "> $@" ; "$@" ; }

__banner () { echo; echo "===== $@"; }

append_content_if_absent () {
  file="$1" text="$2" appending=${3:-$2}
  echo "> $file"
  if ! grep "$text" "$file" >/dev/null 2>&1; then
    [ -f "$appending" ] && cat "$appending" >> "$file" || echo "$appending" >> "$file"
  fi
}

if [ -t 0 ]; then
  echo "Running interactively or from a terminal."
  RAVY="$(cd "$(dirname "$0")" && pwd)"
else
  echo "Script is being piped. Trying to create the ravy folder."
  RAVY="$HOME/.ravy"
  if [ -d "$RAVY" ]; then
    __el git -C "$RAVY" pull --rebase || true
  else
    __el git clone https://github.com/mushanyoung/ravy $RAVY
  fi
fi

__banner mkdir
__el mkdir -p $HOME/.config $HOME/.config/fish $HOME/.config/fish/functions $HOME/.config/nvim

__banner dotfiles
append_content_if_absent $HOME/.gitconfig "path=$RAVY/gitconfig" "[include]
path=$RAVY/gitconfig"
append_content_if_absent $HOME/.ignore "$(cat $RAVY/ignore)"

__banner fish
append_content_if_absent $HOME/.config/fish/config.fish "test -f $RAVY/config.fish && source $RAVY/config.fish"
__el rm -rf $HOME/.config/fish/functions
__el cp -r $RAVY/fish-functions $HOME/.config/fish/functions
curl https://raw.githubusercontent.com/danhper/fundle/master/functions/fundle.fish --create-dirs -sLo ~/.config/fish/functions/fundle.fish

__banner neovim
__el rm -f $HOME/.config/nvim/coc-settings.json
__el cp -f $RAVY/coc-settings.json $HOME/.config/nvim/coc-settings.json
__el curl -fLo $HOME/.config/nvim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
append_content_if_absent $HOME/.config/nvim/init.vim "if filereadable('$RAVY/vimrc') | source $RAVY/vimrc | endif"

__banner tmux
__el curl -sfLo $HOME/.tmux.conf https://raw.githubusercontent.com/gpakosz/.tmux/master/.tmux.conf
append_content_if_absent $HOME/.tmux.conf.local "source $RAVY/tmux.conf.local"

__banner custom
if command -v "$RAVY/custom/install.sh" >/dev/null; then
  "$RAVY/custom/install.sh" || true
fi

__banner complete
echo "Finish install."
type fish
