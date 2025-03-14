#!/bin/sh

# Dependencies: git, vim, fzf, fd, curl
# Dependencies for Linux: build-essential

SHELL=/bin/sh

set -e

# execute with log
__el() { echo "> $@" ; "$@" ; }

__banner () { echo; echo "===== $@"; }

append_content_if_absent () {
  file="$1" text="$2" appending=${3:-$2}
  if ! grep "$text" "$file" >/dev/null 2>&1; then
    [ -f "$appending" ] && cat "$appending" >> "$file" || echo "$appending" >> "$file"
  fi
}

__banner mkdir
__el mkdir -p $HOME/.config $HOME/.config/fish $HOME/.config/fish/functions $HOME/.vim $HOME/.vim/bundle $HOME/.vim/tmp $HOME/.vim/autoload

__banner ~/.ravy
if [ -d "$HOME/.ravy" ]; then
  __el git -C "$HOME/.ravy" pull --rebase || true
else
  __el git clone https://github.com/mushanyoung/ravy $HOME/.ravy
fi

__banner link dotfiles
RAVY="$HOME/.ravy"
append_content_if_absent $HOME/.gitconfig "path=$RAVY/gitconfig" "[include]
path=$RAVY/gitconfig"
append_content_if_absent $HOME/.gitconfig "path=$RAVY/custom/gitconfig" "path=$RAVY/custom/gitconfig"
append_content_if_absent $HOME/.ignore "RAVY_TMP" "$RAVY/ignore"

__banner fish
append_content_if_absent $HOME/.config/fish/config.fish "test -f $RAVY/config.fish && source $RAVY/config.fish"
curl https://raw.githubusercontent.com/danhper/fundle/master/functions/fundle.fish --create-dirs -sLo ~/.config/fish/functions/fundle.fish
ln -sf $RAVY/fish-functions/* $HOME/.config/fish/functions

__banner brew-compose
__el rm -rf $HOME/.brew-compose
__el ln -s -f $RAVY/brew-compose $HOME/.brew-compose

__banner colorls
__el rm -rf $HOME/.config/colorls
__el ln -s -f $RAVY/colorls $HOME/.config/colorls

__banner vim/neovim
__el rm -rf $HOME/.config/nvim
__el ln -s -f $HOME/.vim $HOME/.config/nvim

append_content_if_absent $HOME/.vimrc "if filereadable(\"$RAVY/vimrc\") | source $RAVY/vimrc | endif"
append_content_if_absent $HOME/.config/nvim/init.vim "if filereadable(\"$RAVY/vimrc\") | source $RAVY/vimrc | endif"

__banner vim plugins
if [ ! -e $HOME/.vim/autoload/plug.vim ]; then
  __el curl -sfLo $HOME/.vim/autoload/plug.vim https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

__banner tmux
__el curl -sfLo $HOME/.tmux.conf https://raw.githubusercontent.com/gpakosz/.tmux/master/.tmux.conf
__el ln -s -f $RAVY/tmux.conf.local $HOME/.tmux.conf.local

__banner custom
if command -v "$RAVY/custom/install.sh" >/dev/null; then
  "$RAVY/custom/install.sh" || true
fi

__banner complete
echo "Please chsh to fish, if not yet."
type fish
