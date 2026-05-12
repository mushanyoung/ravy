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

default_private_home() {
  for candidate in \
    "${RAVY_PRIVATE_HOME:-}" \
    "$HOME/.local/share/ravy-private" \
    "$HOME/.ravy-private" \
    "$SCRIPT_DIR/custom"
  do
    [ -n "${candidate:-}" ] || continue
    [ -d "$candidate/.git" ] || continue
    printf '%s\n' "$candidate"
    return 0
  done

  printf '%s\n' "$HOME/.local/share/ravy-private"
}

chezmoi_config_dir() {
  printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi"
}

seed_chezmoi_config() {
  target="$1"
  shift

  [ -f "$target" ] && return 0

  __el mkdir -p "$(dirname "$target")"
  for candidate in "$@"; do
    [ -n "${candidate:-}" ] || continue
    [ -f "$candidate" ] || continue
    __el cp "$candidate" "$target"
    return 0
  done
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

ensure_age() {
  if command -v age >/dev/null 2>&1; then
    success "age is installed."
    return 0
  fi

  warn "age is not installed; installing it for current user."
  if command -v brew >/dev/null 2>&1; then
    __el brew install age
  fi

  if ! command -v age >/dev/null 2>&1; then
    error "age is required for the private encrypted overlay"
    error "Install age and rerun this bootstrap"
    return 1
  fi

  success "age is installed."
}

bootstrap_private_age_identity() {
  local private_home bootstrap_key target_key target_dir

  private_home="$1"
  bootstrap_key="$private_home/bootstrap/key.txt.age"
  target_dir="$HOME/.config/chezmoi"
  target_key="$target_dir/key.txt"

  [ -f "$bootstrap_key" ] || return 0
  [ ! -f "$target_key" ] || return 0

  info "Bootstrapping local age identity"
  __el mkdir -p "$target_dir"
  __el sh -c 'umask 077 && age --decrypt -o "$1" "$2"' sh "$target_key" "$bootstrap_key"
  __el chmod 600 "$target_key"
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

info "Applying dotfiles (bash, zsh, and fish config files) for current user"
RAVY_REPO="${RAVY_REPO:-mushanyoung/ravy}"
RAVY_PRIVATE_HOME="${RAVY_PRIVATE_HOME:-$(default_private_home)}"
RAVY_PRIVATE_REPO="${RAVY_PRIVATE_REPO:-}"
RAVY_CHEZMOI_FORCE="${RAVY_CHEZMOI_FORCE:-0}"
RAVY_BOOTSTRAP_OPTIONAL="${RAVY_BOOTSTRAP_OPTIONAL:-1}"
RAVY_CHEZMOI_CONFIG_DIR="${RAVY_CHEZMOI_CONFIG_DIR:-$(chezmoi_config_dir)}"
RAVY_CHEZMOI_PRIVATE_CONFIG="${RAVY_CHEZMOI_PRIVATE_CONFIG:-$RAVY_CHEZMOI_CONFIG_DIR/ravy-private.toml}"
RAVY_CHEZMOI_PRIVATE_STATE="${RAVY_CHEZMOI_PRIVATE_STATE:-$RAVY_CHEZMOI_CONFIG_DIR/ravy-private-state.boltdb}"
export RAVY_PRIVATE_HOME

__el mkdir -p "$RAVY_CHEZMOI_CONFIG_DIR"

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

if [ -d "$RAVY_PRIVATE_HOME/.git" ]; then
  ensure_age
  bootstrap_private_age_identity "$RAVY_PRIVATE_HOME"
fi

if [ "$RAVY_CHEZMOI_FORCE" = "1" ]; then
  warn "Using --force to overwrite existing files managed by this setup."
  __el chezmoi init --apply --force "$RAVY_REPO"
else
  __el chezmoi init --apply "$RAVY_REPO"
fi

if [ -d "$RAVY_PRIVATE_HOME/.git" ]; then
  info "Applying private encrypted overlay"
  __el chezmoi -S "$RAVY_PRIVATE_HOME" -c "$RAVY_CHEZMOI_PRIVATE_CONFIG" --persistent-state "$RAVY_CHEZMOI_PRIVATE_STATE" init -C "$RAVY_CHEZMOI_PRIVATE_CONFIG"
  seed_chezmoi_config "$RAVY_CHEZMOI_PRIVATE_CONFIG" "$RAVY_CHEZMOI_CONFIG_DIR/chezmoi.toml"
  __el chezmoi -S "$RAVY_PRIVATE_HOME" -c "$RAVY_CHEZMOI_PRIVATE_CONFIG" --persistent-state "$RAVY_CHEZMOI_PRIVATE_STATE" apply
fi

private_install_script=''
if private_install_script="$(resolve_private_install_script)"; then
  info "Configuring optional private overlay"
  __el "$private_install_script"
fi

if [ "$RAVY_BOOTSTRAP_OPTIONAL" = "1" ]; then
  info "Optional bootstrap: vim-plug"
  if [ ! -f "$HOME/.config/nvim/autoload/plug.vim" ]; then
    __el curl -fLo "$HOME/.config/nvim/autoload/plug.vim" --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  fi
else
  info "Skipping optional vim bootstrap (set RAVY_BOOTSTRAP_OPTIONAL=1 to enable)"
fi

success "Installation complete!"

info "Notes"
echo "  - bash: sources ~/.bashrc (installed by chezmoi)"
echo "  - zsh:  sources ~/.zshrc (installed by chezmoi)"
echo "  - fish: uses ~/.config/fish/config.fish (installed by chezmoi)"
echo "  - managed shell secrets: ~/.config/ravy/secrets.tsv with sh/fish wrappers"
echo "  - private age identity: ~/.config/chezmoi/key.txt"
echo "  - private chezmoi config/state: ~/.config/chezmoi/ravy-private.toml and ~/.config/chezmoi/ravy-private-state.boltdb"
echo "  - optional private repo: set RAVY_PRIVATE_REPO before install"
