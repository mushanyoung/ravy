#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

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

resolve_private_install_script() {
  local chezmoi_source

  if [ -x "$RAVY_PRIVATE_HOME/install.sh" ]; then
    printf '%s\n' "$RAVY_PRIVATE_HOME/install.sh"
    return 0
  fi

  if chezmoi_source="$(chezmoi source-path 2>/dev/null)"; then
    if [ -x "$chezmoi_source/custom/install.sh" ]; then
      printf '%s\n' "$chezmoi_source/custom/install.sh"
      return 0
    fi
  fi

  if [ -x "$SCRIPT_DIR/custom/install.sh" ]; then
    printf '%s\n' "$SCRIPT_DIR/custom/install.sh"
    return 0
  fi

  return 1
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
RAVY_PRIVATE_HOME="${RAVY_PRIVATE_HOME:-$HOME/.local/share/ravy-private}"
RAVY_PRIVATE_REPO="${RAVY_PRIVATE_REPO:-}"
RAVY_CHEZMOI_FORCE="${RAVY_CHEZMOI_FORCE:-0}"
RAVY_BOOTSTRAP_OPTIONAL="${RAVY_BOOTSTRAP_OPTIONAL:-0}"
export RAVY_PRIVATE_HOME

if [ -n "$RAVY_PRIVATE_REPO" ]; then
  if ! command -v git >/dev/null 2>&1; then
    error "git is required to install the optional private overlay"
    exit 1
  fi

  info "Syncing optional private overlay"
  __el mkdir -p "$(dirname "$RAVY_PRIVATE_HOME")"
  if [ -d "$RAVY_PRIVATE_HOME/.git" ]; then
    __el git -C "$RAVY_PRIVATE_HOME" pull --ff-only
  else
    __el git clone "$RAVY_PRIVATE_REPO" "$RAVY_PRIVATE_HOME"
  fi
fi

if [ "$RAVY_CHEZMOI_FORCE" = "1" ]; then
  warn "Using --force to overwrite existing files managed by this setup."
  __el chezmoi init --apply --force "$RAVY_REPO"
else
  __el chezmoi init --apply "$RAVY_REPO"
fi

private_install_script=''
if private_install_script="$(resolve_private_install_script)"; then
  info "Configuring optional private overlay"
  __el "$private_install_script"
fi

if [ "$RAVY_BOOTSTRAP_OPTIONAL" = "1" ]; then
  info "Optional bootstrap: tmux base config + vim-plug"
  __el curl -sfLo "$HOME/.tmux.conf" https://raw.githubusercontent.com/gpakosz/.tmux/master/.tmux.conf

  if [ ! -f "$HOME/.config/nvim/autoload/plug.vim" ]; then
    __el curl -fLo "$HOME/.config/nvim/autoload/plug.vim" --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  fi
else
  info "Skipping optional tmux/vim bootstrap (set RAVY_BOOTSTRAP_OPTIONAL=1 to enable)"
fi

success "Installation complete!"

info "Notes"
echo "  - bash: sources ~/.bashrc (installed by chezmoi)"
echo "  - zsh:  sources ~/.zshrc (installed by chezmoi)"
echo "  - fish: uses ~/.config/fish/config.fish (installed by chezmoi)"
echo "  - local machine secrets: ~/.config/ravy/local.sh and ~/.config/ravy/local.fish"
echo "  - optional private repo: set RAVY_PRIVATE_REPO before install"
