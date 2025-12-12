#!/bin/bash

set -euo pipefail

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

info "Bootstrapping Ravy with chezmoi"

# Ensure ~/.local/bin exists for user-scoped installs
__el mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

if command -v chezmoi >/dev/null 2>&1; then
  success "chezmoi is installed."
else
  warn "chezmoi is not installed; installing it for current user."
  if command -v brew >/dev/null 2>&1; then
    __el brew install chezmoi
  else
    # Official installer: https://www.chezmoi.io/install/
    __el sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
  fi
fi

if ! command -v chezmoi >/dev/null 2>&1; then
  error "chezmoi install failed or not on PATH"
  exit 1
fi

info "Applying dotfiles (bash, zsh, fish) for current user"
RAVY_REPO="${RAVY_REPO:-mushanyoung/ravy}"
RAVY_CHEZMOI_FORCE="${RAVY_CHEZMOI_FORCE:-1}"

if [ "$RAVY_CHEZMOI_FORCE" = "1" ]; then
  warn "Using --force to overwrite existing files managed by this setup."
  __el chezmoi init --apply --force "$RAVY_REPO"
else
  __el chezmoi init --apply "$RAVY_REPO"
fi

# Optional bootstrap helpers (kept from the old installer experience)
info "Optional bootstrap: tmux base config + vim-plug"

if [ ! -f "$HOME/.tmux.conf" ]; then
  __el curl -sfLo "$HOME/.tmux.conf" https://raw.githubusercontent.com/gpakosz/.tmux/master/.tmux.conf
fi

if [ ! -f "$HOME/.config/nvim/autoload/plug.vim" ]; then
  __el curl -fLo "$HOME/.config/nvim/autoload/plug.vim" --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

success "Installation complete!"

info "Notes"
echo "  - bash: sources ~/.bashrc (installed by chezmoi)"
echo "  - zsh:  sources ~/.zshrc (installed by chezmoi)"
echo "  - fish: uses ~/.config/fish/config.fish (installed by chezmoi)"
