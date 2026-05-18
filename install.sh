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
GIT_BIN=''
CHEZMOI_TOOL="${RAVY_MISE_CHEZMOI_TOOL:-chezmoi@latest}"
AGE_TOOL="${RAVY_MISE_AGE_TOOL:-age@latest}"

ensure_git() {
  if [ -n "${RAVY_GIT_BIN:-}" ]; then
    if [ -x "$RAVY_GIT_BIN" ]; then
      GIT_BIN="$RAVY_GIT_BIN"
      return 0
    fi
    error "git is required to install Ravy"
    return 1
  fi

  if ! GIT_BIN="$(command -v git 2>/dev/null)"; then
    error "git is required to install Ravy"
    return 1
  fi
}

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

homebrew_default_prefix() {
  case "$(uname -s 2>/dev/null || true)" in
    Darwin)
      case "$(uname -m 2>/dev/null || true)" in
        arm64 | aarch64)
          printf '%s\n' '/opt/homebrew'
          ;;
        *)
          printf '%s\n' '/usr/local'
          ;;
      esac
      ;;
    Linux)
      printf '%s\n' '/home/linuxbrew/.linuxbrew'
      ;;
    *)
      return 1
  esac
}

find_homebrew() {
  local candidate expected_prefix

  if candidate="$(command -v brew 2>/dev/null)"; then
    printf '%s\n' "$candidate"
    return 0
  fi

  if expected_prefix="$(homebrew_default_prefix)"; then
    candidate="$expected_prefix/bin/brew"
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi

  for candidate in \
    /opt/homebrew/bin/brew \
    /usr/local/bin/brew \
    /home/linuxbrew/.linuxbrew/bin/brew \
    "$HOME/.linuxbrew/bin/brew" \
    "$HOME/.brew/bin/brew"
  do
    [ -x "$candidate" ] || continue
    printf '%s\n' "$candidate"
    return 0
  done

  return 1
}

ensure_homebrew() {
  local brew_prefix expected_prefix brew_name

  case "$(uname -s 2>/dev/null || true)" in
    Darwin)
      brew_name="Homebrew"
      ;;
    Linux)
      brew_name="Linuxbrew"
      ;;
    *)
      error "Homebrew installation is only supported on macOS and Linux"
      return 1
      ;;
  esac

  if ! expected_prefix="$(homebrew_default_prefix)"; then
    error "Could not determine default Homebrew prefix"
    return 1
  fi
  if HOMEBREW_BIN="$(find_homebrew)"; then
    brew_prefix="$("$HOMEBREW_BIN" --prefix 2>/dev/null || true)"
    if [ -n "$brew_prefix" ] && [ "$brew_prefix" != "$expected_prefix" ]; then
      warn "Homebrew prefix is $brew_prefix; expected default $expected_prefix. Continuing with existing Homebrew."
    fi
    if [ -n "$brew_prefix" ]; then
      export PATH="$brew_prefix/bin:$brew_prefix/sbin:$PATH"
    fi
    success "$brew_name is installed."
    return 0
  fi

  warn "$brew_name is not installed; installing it at default $expected_prefix."
  __el /bin/bash -o pipefail -c 'curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | NONINTERACTIVE=1 /bin/bash'
  export PATH="$expected_prefix/bin:$expected_prefix/sbin:$PATH"

  if ! HOMEBREW_BIN="$(find_homebrew)"; then
    error "$brew_name install failed or not found at $expected_prefix/bin/brew"
    return 1
  fi
  brew_prefix="$("$HOMEBREW_BIN" --prefix 2>/dev/null || true)"
  if [ -n "$brew_prefix" ] && [ "$brew_prefix" != "$expected_prefix" ]; then
    warn "Homebrew prefix is $brew_prefix; expected default $expected_prefix. Continuing with installed Homebrew."
  fi
  if [ -n "$brew_prefix" ]; then
    export PATH="$brew_prefix/bin:$brew_prefix/sbin:$PATH"
  fi

  success "$brew_name is installed."
}

run_chezmoi() {
  __el "$MISE_BIN" exec "$CHEZMOI_TOOL" -- chezmoi "$@"
}

run_chezmoi_quiet() {
  "$MISE_BIN" exec "$CHEZMOI_TOOL" -- chezmoi "$@"
}

resolve_public_source_path() {
  local source_path

  source_path="${RAVY_HOME:-}"
  if [ -z "$source_path" ]; then
    source_path="$(run_chezmoi_quiet source-path 2>/dev/null || true)"
  fi
  if [ -z "$source_path" ]; then
    source_path="$HOME/.local/share/chezmoi"
  fi

  printf '%s\n' "$source_path"
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

load_managed_secrets_for_install() {
  local config_home secrets_sh secrets_tsv tab cr line key value

  config_home="${XDG_CONFIG_HOME:-$HOME/.config}/ravy"
  secrets_sh="$config_home/secrets.sh"
  secrets_tsv="$config_home/secrets.tsv"

  if [ -f "$secrets_sh" ]; then
    info "Loading managed shell secrets for installer"
    # shellcheck disable=SC1090
    . "$secrets_sh"
    return 0
  fi

  [ -f "$secrets_tsv" ] || return 0

  info "Loading managed TSV secrets for installer"
  tab="$(printf '\t')"
  cr="$(printf '\r')"

  while IFS= read -r line || [ -n "${line:-}" ]; do
    case "${line%"$cr"}" in
      '' | \#*)
        continue
        ;;
    esac
    case "$line" in
      *"$tab"*)
        key=${line%%"$tab"*}
        value=${line#*"$tab"}
        ;;
      *)
        continue
        ;;
    esac

    key="${key%"$cr"}"
    while :; do
      case "$key" in
        ' '*)
          key=${key# }
          ;;
        "$tab"*)
          key=${key#"$tab"}
          ;;
        *' ')
          key=${key% }
          ;;
        *"$tab")
          key=${key%"$tab"}
          ;;
        *)
          break
          ;;
      esac
    done

    value="${value%"$cr"}"
    while :; do
      case "$value" in
        ' '*)
          value=${value# }
          ;;
        "$tab"*)
          value=${value#"$tab"}
          ;;
        *)
          break
          ;;
      esac
    done
    case "$value" in
      '~' | '~/'*)
        value="$HOME${value#\~}"
        ;;
    esac

    [ -n "$key" ] || continue
    export "$key=$value"
  done < "$secrets_tsv"

}

resolve_public_brewfile_dir() {
  printf '%s\n' "$HOME/.config/homebrew"
}

resolve_public_brewfile() {
  printf '%s\n' "$(resolve_public_brewfile_dir)/Brewfile"
}

install_homebrew_bundle() {
  local brewfile brewfile_dir

  ensure_homebrew
  brewfile="$(resolve_public_brewfile)"
  brewfile_dir="$(resolve_public_brewfile_dir)"
  if [ ! -f "$brewfile" ]; then
    error "Brewfile not found: $brewfile"
    return 1
  fi

  export HOMEBREW_BUNDLE_FILE="$brewfile"
  info "Installing Homebrew packages from $HOMEBREW_BUNDLE_FILE"
  (cd "$brewfile_dir" && __el "$HOMEBREW_BIN" bundle install)
}

find_fish_shell() {
  local candidate fish_prefix brew_prefix

  if [ -z "${HOMEBREW_BIN:-}" ]; then
    HOMEBREW_BIN="$(find_homebrew)" || return 1
  fi

  if [ -n "${HOMEBREW_BIN:-}" ]; then
    fish_prefix="$("$HOMEBREW_BIN" --prefix fish 2>/dev/null || true)"
    candidate="$fish_prefix/bin/fish"
    if [ -n "$fish_prefix" ] && [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi

    brew_prefix="$("$HOMEBREW_BIN" --prefix 2>/dev/null || true)"
    candidate="$brew_prefix/bin/fish"
    if [ -n "$brew_prefix" ] && [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi

  for candidate in \
    /opt/homebrew/opt/fish/bin/fish \
    /usr/local/opt/fish/bin/fish \
    /home/linuxbrew/.linuxbrew/opt/fish/bin/fish \
    "$HOME/.linuxbrew/opt/fish/bin/fish" \
    "$HOME/.brew/opt/fish/bin/fish"
  do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

current_login_shell() {
  local target_user shell_line

  target_user="$1"

  if command -v getent >/dev/null 2>&1; then
    shell_line="$(getent passwd "$target_user" 2>/dev/null || true)"
    if [ -n "$shell_line" ]; then
      printf '%s\n' "${shell_line##*:}"
      return 0
    fi
  fi

  if command -v dscl >/dev/null 2>&1; then
    shell_line="$(dscl . -read "/Users/$target_user" UserShell 2>/dev/null || true)"
    shell_line="${shell_line#UserShell: }"
    if [ -n "$shell_line" ]; then
      printf '%s\n' "$shell_line"
      return 0
    fi
  fi

  printf '%s\n' "${SHELL:-}"
}

run_privileged() {
  if [ "$(id -u)" = "0" ]; then
    "$@"
  else
    sudo "$@"
  fi
}

ensure_shell_list_contains() {
  local fish_bin shells_file

  fish_bin="$1"
  shells_file="${RAVY_ETC_SHELLS:-/etc/shells}"

  if [ -r "$shells_file" ] && grep -Fx "$fish_bin" "$shells_file" >/dev/null 2>&1; then
    return 0
  fi

  info "Adding $fish_bin to $shells_file"
  if [ "$(id -u)" = "0" ]; then
    printf '%s\n' "$fish_bin" >> "$shells_file"
  else
    printf '%s\n' "$fish_bin" | sudo tee -a "$shells_file" >/dev/null
  fi
}

configure_default_fish_shell() {
  local fish_bin target_user login_shell

  [ "${RAVY_SKIP_CHSH:-0}" != "1" ] || {
    warn "Skipping default shell change because RAVY_SKIP_CHSH=1."
    return 0
  }

  if ! fish_bin="$(find_fish_shell)"; then
    error "brew-managed fish is required but was not found after package installation"
    return 1
  fi

  ensure_shell_list_contains "$fish_bin"

  target_user="${RAVY_CHSH_USER:-${SUDO_USER:-${USER:-${LOGNAME:-}}}}"
  if [ -z "$target_user" ]; then
    target_user="$(id -un 2>/dev/null || true)"
  fi
  if [ -z "$target_user" ]; then
    error "Could not determine target user for chsh"
    return 1
  fi

  login_shell="$(current_login_shell "$target_user")"
  if [ "$login_shell" = "$fish_bin" ]; then
    success "Default shell is already $fish_bin."
    return 0
  fi

  info "Changing default shell for $target_user to $fish_bin"
  __el run_privileged chsh -s "$fish_bin" "$target_user"
}

default_private_home() {
  local public_source

  public_source="$(resolve_public_source_path)"
  for candidate in \
    "${RAVY_PRIVATE_HOME:-}" \
    "$public_source/custom" \
    "$HOME/.local/share/ravy-private" \
    "$HOME/.ravy-private"
  do
    [ -n "${candidate:-}" ] || continue
    [ -d "$candidate/.git" ] || continue
    printf '%s\n' "$candidate"
    return 0
  done

  printf '%s\n' "$public_source/custom"
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

ensure_git
ensure_mise

if ! "$MISE_BIN" exec "$CHEZMOI_TOOL" -- chezmoi --version >/dev/null 2>&1; then
  error "chezmoi install failed via mise"
  exit 1
fi
success "chezmoi is installed via mise."

info "Applying dotfiles (bash, zsh, and fish config files) for current user"
RAVY_REPO="${RAVY_REPO:-mushanyoung/ravy}"
RAVY_HOME="${RAVY_HOME:-$(resolve_public_source_path)}"
RAVY_PRIVATE_HOME="${RAVY_PRIVATE_HOME:-$(default_private_home)}"
RAVY_PRIVATE_REPO="${RAVY_PRIVATE_REPO:-}"
RAVY_CHEZMOI_FORCE="${RAVY_CHEZMOI_FORCE:-0}"
RAVY_CHEZMOI_CONFIG_DIR="${RAVY_CHEZMOI_CONFIG_DIR:-$(chezmoi_config_dir)}"
RAVY_CHEZMOI_PRIVATE_CONFIG="${RAVY_CHEZMOI_PRIVATE_CONFIG:-$RAVY_CHEZMOI_CONFIG_DIR/ravy-private.toml}"
RAVY_CHEZMOI_PRIVATE_STATE="${RAVY_CHEZMOI_PRIVATE_STATE:-$RAVY_CHEZMOI_CONFIG_DIR/ravy-private-state.boltdb}"
export RAVY_PRIVATE_HOME
export RAVY_HOME

__el mkdir -p "$RAVY_CHEZMOI_CONFIG_DIR"

if [ "$RAVY_CHEZMOI_FORCE" = "1" ]; then
  warn "Using --force to overwrite existing files managed by this setup."
  run_chezmoi init --apply --force "$RAVY_REPO"
else
  run_chezmoi init --apply "$RAVY_REPO"
fi

if [ -n "$RAVY_PRIVATE_REPO" ]; then
  info "Syncing optional private overlay"
  __el mkdir -p "$(dirname "$RAVY_PRIVATE_HOME")"
  if [ -d "$RAVY_PRIVATE_HOME/.git" ]; then
    __el "$GIT_BIN" -C "$RAVY_PRIVATE_HOME" pull --ff-only
  else
    __el "$GIT_BIN" clone "$RAVY_PRIVATE_REPO" "$RAVY_PRIVATE_HOME"
  fi
fi

if [ -d "$RAVY_PRIVATE_HOME/.git" ]; then
  ensure_age
  bootstrap_private_age_identity "$RAVY_PRIVATE_HOME"
fi

install_homebrew_bundle
configure_default_fish_shell

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

load_managed_secrets_for_install
install_configured_mise_tools

success "Installation complete!"

info "Notes"
echo "  - bash: sources ~/.bashrc (installed by chezmoi)"
echo "  - zsh:  sources ~/.zshrc (installed by chezmoi)"
echo "  - fish: uses ~/.config/fish/config.fish (installed by chezmoi)"
echo "  - managed shell secrets: ~/.config/ravy/secrets.tsv with sh/fish wrappers"
echo "  - Homebrew bundle: HOMEBREW_BUNDLE_FILE=~/.config/homebrew/Brewfile"
echo "  - private age identity: ~/.config/chezmoi/key.txt"
echo "  - private chezmoi config/state: ~/.config/chezmoi/ravy-private.toml and ~/.config/chezmoi/ravy-private-state.boltdb"
echo "  - optional private repo: set RAVY_PRIVATE_REPO before install"
