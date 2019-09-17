#!/bin/sh

link_homebrew () {
  for brew in "$HOME/.brew" "$HOME/.linuxbrew" "/home/linuxbrew/.linuxbrew" "/usr/local"; do
    test -f "$brew/bin/brew" && eval "$($brew/bin/brew shellenv)"
  done
}

append_content_if_absent () {
  file="$1" text="$2" appending=${3:-$2}
  if ! grep "$text" "$file" >/dev/null 2>&1; then
    [ -f "$appending" ] && cat "$appending" >> "$file" || echo "$appending" >> "$file"
  fi
}

link_homebrew

if ! type brew >/dev/null 2>&1; then
  echo "Homebrew / Linuxbrew does not present."
  if [ $(uname) = Darwin ]; then
    echo "Installing Homebrew..."
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  elif [ $(uname) = Linux ]; then
    echo "Installing Linuxbrew dependencies..."
    if type apt-get >/dev/null 2>&1; then
      sudo apt-get install build-essential curl file git
    elif type yum >/dev/null 2>&1; then
      sudo yum groupinstall 'Development Tools'
      sudo yum install curl file git
      sudo yum install libxcrypt-compat
    fi

    echo "Installing Linuxbrew..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/Linuxbrew/install/master/install.sh)"
  else
    echo "The system is not standard Linux or OSX."
    echo "Please manually install Homebrew / Linuxbrew and then rerun the script."
    exit
  fi
  link_homebrew
  if ! type brew >/dev/null 2>&1; then
    echo "Homebrew / Linuxbrew can not be loaded. Exiting."
    exit
  fi
fi

for dep in "git" "vim" "zsh" "fzf" "fd"; do
  if ! type $dep >/dev/null 2>&1; then
    echo "Installing $dep by brew."
    brew install $dep
    if [ $? != 0 ] || ! type $dep >/dev/null 2>&1; then
      echo "Failed to install git. Exiting."
      exit
    fi
  fi
done

echo "mkdir"
mkdir -p $HOME/.config $HOME/.vim $HOME/.vim/bundle $HOME/.vim/tmp $HOME/.vim/autoload

echo "ravy"
[ -d $HOME/.ravy ] || git clone https://github.com/mushanyoung/ravy $HOME/.ravy

echo "zplug"
[ -d $HOME/.zplug ] || git clone https://github.com/zplug/zplug $HOME/.zplug

echo "dotfiles"
RAVY="$HOME/.ravy"
append_content_if_absent $HOME/.zshrc "[ -f $RAVY/zshrc ] && source $RAVY/zshrc"
append_content_if_absent $HOME/.zshenv "[ -f $RAVY/zshenv ] && source $RAVY/zshenv"
append_content_if_absent $HOME/.gitconfig "path=$RAVY/gitconfig" "[include]\npath=$RAVY/gitconfig\npath=$RAVY/custom/gitconfig"
append_content_if_absent $HOME/.ignore "RAVY_TMP" "$RAVY/ignore"

echo "colorls"
rm -rf $HOME/.config/colorls
ln -s -f $RAVY/colorls $HOME/.config/colorls

echo "vim/neovim"
[ -d $HOME/.config/nvim ] || ln -s -f $HOME/.vim $HOME/.config/nvim

append_content_if_absent $HOME/.vimrc "if filereadable(\"$RAVY/vimrc\") | source $RAVY/vimrc | endif"
append_content_if_absent $HOME/.config/nvim/init.vim "if filereadable(\"$RAVY/vimrc\") | source $RAVY/vimrc | endif"

[ -e $HOME/.vim/autoload/plug.vim ] || curl -sfLo $HOME/.vim/autoload/plug.vim \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

echo "vim plugins"
vim '+PlugUpdate' '+qall'

echo "tmux"
curl -sfLo $HOME/.tmux.conf \
  https://raw.githubusercontent.com/gpakosz/.tmux/master/.tmux.conf
ln -s -f $RAVY/tmux.conf.local $HOME/.tmux.conf.local

if command -v "$RAVY/custom/install" >/dev/null; then
  echo "$RAVY/custom/install"
  "$RAVY/custom/install" || true
fi

echo "Install complete."
if [ -z "$ZSH_VERSION" ]; then
  echo "Please chsh to zsh."
  type zsh
fi
