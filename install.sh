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

MISE_BIN=''
HOMEBREW_BIN=''
CHEZMOI_TOOL="${RAVY_MISE_CHEZMOI_TOOL:-chezmoi@latest}"
AGE_TOOL="${RAVY_MISE_AGE_TOOL:-age@latest}"

find_mise() {
  local candidate

  if candidate="$(command -v mise 2>/dev/null)"; then
    printf '%s\n' "$candidate"
    return 0
  fi

  candidate="${MISE_INSTALL_PATH:-$HOME/.local/bin/mise}"
  if [ -x "$candidate" ]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  return 1
}

ensure_mise() {
  local install_path install_dir

  if MISE_BIN="$(find_mise)"; then
    success "mise is installed."
    return 0
  fi

  warn "mise is not installed; installing it for current user."
  install_path="${MISE_INSTALL_PATH:-$HOME/.local/bin/mise}"
  install_dir="$(dirname "$install_path")"
  __el mkdir -p "$install_dir"
  __el env MISE_INSTALL_PATH="$install_path" sh -c 'curl -fsSL https://mise.run | sh'

  if ! MISE_BIN="$(find_mise)"; then
    error "mise install failed or not on PATH"
    return 1
  fi

  export PATH="$(dirname "$MISE_BIN"):$PATH"
  success "mise is installed."
}

is_macos() {
  [ "$(uname -s 2>/dev/null || true)" = "Darwin" ]
}

homebrew_default_prefix() {
  case "$(uname -m 2>/dev/null || true)" in
    arm64 | aarch64)
      printf '%s\n' '/opt/homebrew'
      ;;
    *)
      printf '%s\n' '/usr/local'
      ;;
  esac
}

find_homebrew() {
  local candidate expected_prefix

  if candidate="$(command -v brew 2>/dev/null)"; then
    printf '%s\n' "$candidate"
    return 0
  fi

  expected_prefix="$(homebrew_default_prefix)"
  candidate="$expected_prefix/bin/brew"
  if [ -x "$candidate" ]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  return 1
}

ensure_homebrew_macos() {
  local brew_prefix expected_prefix

  is_macos || return 0

  expected_prefix="$(homebrew_default_prefix)"
  if HOMEBREW_BIN="$(find_homebrew)"; then
    brew_prefix="$("$HOMEBREW_BIN" --prefix 2>/dev/null || true)"
    if [ -n "$brew_prefix" ] && [ "$brew_prefix" != "$expected_prefix" ]; then
      warn "Homebrew prefix is $brew_prefix; expected macOS Tier 1 default $expected_prefix. Continuing with existing Homebrew."
    fi
    success "Homebrew is installed."
    return 0
  fi

  warn "Homebrew is not installed; installing it at macOS Tier 1 default $expected_prefix."
  __el /bin/bash -o pipefail -c 'curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | NONINTERACTIVE=1 /bin/bash'
  export PATH="$expected_prefix/bin:$expected_prefix/sbin:$PATH"

  if ! HOMEBREW_BIN="$(find_homebrew)"; then
    error "Homebrew install failed or not found at $expected_prefix/bin/brew"
    return 1
  fi

  success "Homebrew is installed."
}

run_chezmoi() {
  __el "$MISE_BIN" exec "$CHEZMOI_TOOL" -- chezmoi "$@"
}

run_chezmoi_quiet() {
  "$MISE_BIN" exec "$CHEZMOI_TOOL" -- chezmoi "$@"
}

run_age() {
  __el "$MISE_BIN" exec "$AGE_TOOL" -- age "$@"
}

mise_config_dir() {
  printf '%s\n' "${MISE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/mise}"
}

mise_config_contains() {
  local pattern config_dir

  pattern="$1"
  config_dir="$(mise_config_dir)"
  [ -d "$config_dir" ] || return 1

  grep -R -E "$pattern" "$config_dir" >/dev/null 2>&1
}

install_configured_mise_tools() {
  info "Installing mise-managed tools"

  if mise_config_contains '"npm:' && mise_config_contains '(^|[[:space:]])node[[:space:]]*='; then
    info "Installing Node first for npm-backed mise tools"
    __el "$MISE_BIN" install -C "$HOME" node
  fi

  __el "$MISE_BIN" install -C "$HOME"
}

resolve_public_brewfile() {
  local source_path

  source_path="$(run_chezmoi_quiet source-path 2>/dev/null || true)"
  if [ -z "$source_path" ]; then
    source_path="$SCRIPT_DIR"
  fi

  printf '%s\n' "$source_path/Brewfile"
}

install_homebrew_bundle_macos() {
  local brewfile

  is_macos || return 0

  ensure_homebrew_macos
  brewfile="$(resolve_public_brewfile)"
  if [ ! -f "$brewfile" ]; then
    error "Brewfile not found: $brewfile"
    return 1
  fi

  export HOMEBREW_BUNDLE_FILE="$brewfile"
  info "Installing Homebrew packages from $HOMEBREW_BUNDLE_FILE"
  __el "$HOMEBREW_BIN" bundle
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

  if chezmoi_source="$(run_chezmoi_quiet source-path 2>/dev/null)"; then
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
  if ! "$MISE_BIN" exec "$AGE_TOOL" -- age --version >/dev/null 2>&1; then
    error "age is required for the private encrypted overlay"
    error "mise could not install or run age"
    return 1
  fi

  success "age is installed via mise."
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
  (umask 077 && run_age --decrypt -o "$target_key" "$bootstrap_key")
  __el chmod 600 "$target_key"
}

info "Bootstrapping Ravy with chezmoi"

# Ensure ~/.local/bin exists for user-scoped installs
__el mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

ensure_mise

if ! "$MISE_BIN" exec "$CHEZMOI_TOOL" -- chezmoi --version >/dev/null 2>&1; then
  error "chezmoi install failed via mise"
  exit 1
fi
success "chezmoi is installed via mise."

info "Applying dotfiles (bash, zsh, and fish config files) for current user"
RAVY_REPO="${RAVY_REPO:-mushanyoung/ravy}"
RAVY_PRIVATE_HOME="${RAVY_PRIVATE_HOME:-$(default_private_home)}"
RAVY_PRIVATE_REPO="${RAVY_PRIVATE_REPO:-}"
RAVY_CHEZMOI_FORCE="${RAVY_CHEZMOI_FORCE:-0}"
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
  run_chezmoi init --apply --force "$RAVY_REPO"
else
  run_chezmoi init --apply "$RAVY_REPO"
fi

install_homebrew_bundle_macos

if [ -d "$RAVY_PRIVATE_HOME/.git" ]; then
  info "Applying private encrypted overlay"
  run_chezmoi -S "$RAVY_PRIVATE_HOME" -c "$RAVY_CHEZMOI_PRIVATE_CONFIG" --persistent-state "$RAVY_CHEZMOI_PRIVATE_STATE" init -C "$RAVY_CHEZMOI_PRIVATE_CONFIG"
  seed_chezmoi_config "$RAVY_CHEZMOI_PRIVATE_CONFIG" "$RAVY_CHEZMOI_CONFIG_DIR/chezmoi.toml"
  run_chezmoi -S "$RAVY_PRIVATE_HOME" -c "$RAVY_CHEZMOI_PRIVATE_CONFIG" --persistent-state "$RAVY_CHEZMOI_PRIVATE_STATE" apply
fi

private_install_script=''
if private_install_script="$(resolve_private_install_script)"; then
  info "Configuring optional private overlay"
  __el "$private_install_script"
fi

install_configured_mise_tools

success "Installation complete!"

info "Notes"
echo "  - bash: sources ~/.bashrc (installed by chezmoi)"
echo "  - zsh:  sources ~/.zshrc (installed by chezmoi)"
echo "  - fish: uses ~/.config/fish/config.fish (installed by chezmoi)"
echo "  - managed shell secrets: ~/.config/ravy/secrets.tsv with sh/fish wrappers"
if [ -n "${HOMEBREW_BUNDLE_FILE:-}" ]; then
  echo "  - Homebrew bundle: use brew bundle with HOMEBREW_BUNDLE_FILE=$HOMEBREW_BUNDLE_FILE"
fi
echo "  - private age identity: ~/.config/chezmoi/key.txt"
echo "  - private chezmoi config/state: ~/.config/chezmoi/ravy-private.toml and ~/.config/chezmoi/ravy-private-state.boltdb"
echo "  - optional private repo: set RAVY_PRIVATE_REPO before install"
