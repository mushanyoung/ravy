#!/bin/sh

set -e

# execute with log
__el() { echo "> $@" ; "$@" ; }

__banner () { echo; echo "===== $@"; }

link_homebrew () {
  for brew in "$HOME/.brew" "$HOME/.linuxbrew" "/home/linuxbrew/.linuxbrew" "/usr/local"; do
    test -f "$brew/bin/brew" && eval "$($brew/bin/brew shellenv)"
  done
  true
}

append_content_if_absent () {
  file="$1" text="$2" appending=${3:-$2}
  if ! grep "$text" "$file" >/dev/null 2>&1; then
    [ -f "$appending" ] && cat "$appending" >> "$file" || echo "$appending" >> "$file"
  fi
}

if [ $(uname) = Linux ]; then
  __banner Linux packages
  if type apt-get >/dev/null 2>&1; then
    deps_to_install=""
    for dep in "build-essential" "curl" "file" "git" "zsh"; do
      echo -n "Checking apt for $dep... "
      if ! type apt >/dev/null 2>&1 || \
         ! apt -qq list $dep 2>/dev/null | grep "installed" >/dev/null; then
        deps_to_install="$deps_to_install $dep"
        echo "to install"
      else
        echo "found"
      fi
    done
    if [ -n "$deps_to_install" ]; then
      __el sudo apt-get update
      __el sudo apt-get install -y ${deps_to_install}
    fi
  elif type yum >/dev/null 2>&1; then
    __el sudo yum groupinstall 'Development Tools'
    __el sudo yum install -y curl file git zsh libxcrypt-compat
  else
    echo "No supported package manager is found."
    echo "Please manually install Linuxbrew dependencies."
  fi
fi

__banner Homebrew

link_homebrew

if ! type brew >/dev/null 2>&1; then
  echo "Homebrew / Linuxbrew is not present."
  if [ $(uname) = Darwin ]; then
    echo "Installing Homebrew..."
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  elif [ $(uname) = Linux ]; then
    echo "Installing Linuxbrew..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/Linuxbrew/install/master/install.sh)"
  else
    echo "The system is not standard Linux or OSX."
    echo "Please manually install Homebrew / Linuxbrew and rerun the script."
    exit
  fi

  link_homebrew
  if ! type brew >/dev/null 2>&1; then
    echo "Homebrew / Linuxbrew can not be loaded. Exiting."
    exit
  fi
fi

__banner Homebrew formulae

for dep in "git" "vim" "fzf" "fd"; do
  if ! type $dep >/dev/null 2>&1; then
    __el brew install $dep
  fi
done

__banner mkdir
__el mkdir -p $HOME/.config $HOME/.vim $HOME/.vim/bundle $HOME/.vim/tmp $HOME/.vim/autoload

__banner ~/.ravy
if [ -d "$HOME/.ravy" ]; then
  __el git -C "$HOME/.ravy" pull --rebase
else
  __el git clone https://github.com/mushanyoung/ravy $HOME/.ravy
fi

__banner link dotfiles
RAVY="$HOME/.ravy"
append_content_if_absent $HOME/.zshrc "[ -f $RAVY/zshrc ] && source $RAVY/zshrc"
append_content_if_absent $HOME/.zshenv "[ -f $RAVY/zshenv ] && source $RAVY/zshenv"
append_content_if_absent $HOME/.gitconfig "path=$RAVY/gitconfig" "[include]
path=$RAVY/gitconfig"
append_content_if_absent $HOME/.ignore "RAVY_TMP" "$RAVY/ignore"

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

__el vim '+PlugUpdate' '+qall'

__banner tmux
__el curl -sfLo $HOME/.tmux.conf https://raw.githubusercontent.com/gpakosz/.tmux/master/.tmux.conf
__el ln -s -f $RAVY/tmux.conf.local $HOME/.tmux.conf.local

__banner ~/.zplug
if [ -d "$HOME/.zplug" ]; then
  __el git -C "$HOME/.zplug" pull --rebase
else
  __el git clone https://github.com/zplug/zplug $HOME/.zplug
fi
zsh -c 'source ~/.ravy/zplugrc'

__banner custom
if command -v "$RAVY/custom/install" >/dev/null; then
  "$RAVY/custom/install" || true
fi

__banner complete
if ! echo $SHELL | grep zsh >/dev/null 2>&1; then
  echo "Please chsh to zsh."
  type zsh
fi
