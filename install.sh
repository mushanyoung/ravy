#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

# Helpers
info() {
  echo -e "${BLUE}${BOLD}==>${RESET} ${BOLD}$1${RESET}"
}

success() {
  echo -e "${GREEN}${BOLD}==>${RESET} ${BOLD}$1${RESET}"
}

error() {
  echo -e "${RED}${BOLD}==>${RESET} ${BOLD}$1${RESET}"
}

warn() {
  echo -e "${YELLOW}${BOLD}==>${RESET} ${BOLD}$1${RESET}"
}

# execute with log
__el() {
  echo -e "${BOLD}  > $*${RESET}"
  "$@"
}

append_content_if_absent() {
  file="$1"
  text="$2"
  appending=${3:-$2}
  
  if ! grep -F "$text" "$file" >/dev/null 2>&1; then
    echo -e "${BOLD}  > Appending to $file${RESET}"
    if [ -f "$appending" ]; then
      cat "$appending" >> "$file"
    else
      echo "$appending" >> "$file"
    fi
  else
    echo -e "${BOLD}  > Content already present in $file${RESET}"
  fi
}

info "Checking Homebrew"
BREW_AVAILABLE=true
if command -v brew >/dev/null 2>&1; then
  success "Homebrew is installed."
else
  BREW_AVAILABLE=false
  warn "Homebrew/Linuxbrew is not installed."
  echo "Install it manually using:"
  echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
fi

info "Setting up Ravy"
RAVY="$HOME/.ravy"
if [ -d "$RAVY" ]; then
  echo "Updating existing ravy repo at $RAVY..."
  __el git -C "$RAVY" pull --rebase || true
else
  echo "Cloning ravy repo to $RAVY..."
  __el git clone https://github.com/mushanyoung/ravy "$RAVY"
fi

info "Preparing package installation command"
PACKAGES="bat eza fd fish fzf git neovim ripgrep the_silver_searcher tmux"
BREW_INSTALL_CMD="brew install $PACKAGES"
echo "Recommended packages: $PACKAGES"
warn "Automatic Homebrew installs are disabled; run the command manually later."

info "Configuring System"

info "Creating directories"
__el mkdir -p "$HOME/.config" "$HOME/.config/fish" "$HOME/.config/fish/functions" "$HOME/.config/nvim"

info "Setting up dotfiles"
append_content_if_absent "$HOME/.gitconfig" "path=$RAVY/gitconfig" "[include]
path=$RAVY/gitconfig"
append_content_if_absent "$HOME/.ignore" "$(cat "$RAVY/ignore")"

info "Setting up fish"
append_content_if_absent "$HOME/.config/fish/config.fish" "test -f $RAVY/config.fish && source $RAVY/config.fish"
__el rm -rf "$HOME/.config/fish/functions"
__el cp -r "$RAVY/fish-functions" "$HOME/.config/fish/functions"
__el curl -fsLo "$HOME/.config/fish/functions/fundle.fish" --create-dirs https://raw.githubusercontent.com/danhper/fundle/master/functions/fundle.fish

info "Setting up neovim"
__el rm -f "$HOME/.config/nvim/coc-settings.json"
__el cp -f "$RAVY/coc-settings.json" "$HOME/.config/nvim/coc-settings.json"
__el curl -fLo "$HOME/.config/nvim/autoload/plug.vim" --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
append_content_if_absent "$HOME/.config/nvim/init.vim" "if filereadable('$RAVY/vimrc') | source $RAVY/vimrc | endif"

info "Setting up tmux"
__el curl -sfLo "$HOME/.tmux.conf" https://raw.githubusercontent.com/gpakosz/.tmux/master/.tmux.conf
append_content_if_absent "$HOME/.tmux.conf.local" "source $RAVY/tmux.conf.local"

info "Checking for custom install script"
if command -v "$RAVY/custom/install.sh" >/dev/null; then
  "$RAVY/custom/install.sh" || true
fi

success "Installation complete!"
echo "Recommended packages: $PACKAGES"
echo "Configuration files linked."

if [[ "$SHELL" != *"fish"* ]]; then
  warn "Current shell is not fish."
  echo "It is recommended to switch to fish:"
  echo "  chsh -s $(which fish)"
fi

info "Next steps"
echo "To install the recommended Homebrew packages, run:"
echo "  $BREW_INSTALL_CMD"
if [ "$BREW_AVAILABLE" != true ]; then
  echo "Install Homebrew/Linuxbrew first using the command shown earlier."
fi
