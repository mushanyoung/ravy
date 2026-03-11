#!/usr/bin/env bash
set -euo pipefail

script_path=$(realpath "${BASH_SOURCE[0]}")
repo_root=$(realpath "$(dirname "$script_path")/..")
real_chezmoi=$(command -v chezmoi)

failures=0
tmp_home=''

fail() {
  echo "FAIL $1" >&2
  failures=$((failures + 1))
}

assert_file_contains() {
  local path=$1
  local expected=$2
  local msg=$3
  if ! grep -F "$expected" "$path" >/dev/null 2>&1; then
    fail "$msg"
  fi
}

assert_file_lacks() {
  local path=$1
  local unexpected=$2
  local msg=$3
  if grep -F "$unexpected" "$path" >/dev/null 2>&1; then
    fail "$msg"
  fi
}

tmp_home=$(mktemp -d "$repo_root/.tmp_nvim_home.XXXXXX")
trap 'rm -rf "$tmp_home"' EXIT

rendered_init="$tmp_home/.config/nvim/init.vim"
rendered_main="$tmp_home/.config/nvim/ravy.vim"
mkdir -p "$(dirname "$rendered_init")"

"$real_chezmoi" -S "$repo_root" -D "$tmp_home" cat "$rendered_init" > "$rendered_init"
"$real_chezmoi" -S "$repo_root" -D "$tmp_home" cat "$rendered_main" > "$rendered_main"

assert_file_contains "$rendered_init" "let s:ravy_vimrc = s:config_dir . '/ravy.vim'" "init.vim points at the managed local config"
assert_file_contains "$rendered_init" "let \$MYVIMRC = s:ravy_vimrc" "init.vim exposes the managed local config as MYVIMRC"
assert_file_lacks "$rendered_init" "chezmoi source-path" "init.vim no longer shells out to chezmoi"
assert_file_lacks "$rendered_init" "~/.local/share/chezmoi" "init.vim no longer hard-codes the chezmoi checkout path"
assert_file_lacks "$rendered_init" "~/.ravy" "init.vim no longer falls back to the repo checkout path"

assert_file_contains "$rendered_main" "set shadafile=~/.config/nvim/main.shada" "ravy.vim includes the main vimrc"
assert_file_contains "$rendered_main" "let s:private_home = \$RAVY_PRIVATE_HOME" "ravy.vim preserves the existing private overlay hook"

if [ "$failures" -eq 0 ]; then
  echo 'All nvim config tests passed'
fi

exit "$failures"
