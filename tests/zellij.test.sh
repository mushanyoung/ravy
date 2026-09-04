#!/usr/bin/env bash
set -euo pipefail

script_path=$(realpath "${BASH_SOURCE[0]}")
repo_root=$(realpath "$(dirname "$script_path")/..")
# shellcheck source=tests/prefix_guard_common.sh
source "$repo_root/tests/prefix_guard_common.sh"
real_chezmoi=$(command -v chezmoi)

failures=0
tmp_root=''

fail() {
  echo "FAIL $1" >&2
  failures=$((failures + 1))
}

assert_equal() {
  local actual=$1
  local expected=$2
  local msg=$3

  if [ "$actual" != "$expected" ]; then
    fail "$msg: expected '$expected', got '$actual'"
  fi
}

assert_file_contains() {
  local path=$1
  local expected=$2
  local msg=$3
  if ! grep -F "$expected" "$path" >/dev/null 2>&1; then
    fail "$msg"
  fi
}

assert_file_not_contains() {
  local path=$1
  local unexpected=$2
  local msg=$3
  if grep -F "$unexpected" "$path" >/dev/null 2>&1; then
    fail "$msg"
  fi
}

write_locked_block() {
  local source_config=$1
  local locked_block=$2

  awk '
    /^[[:space:]]*locked[[:space:]]*\{/ {
      in_locked = 1
      print
      next
    }
    in_locked {
      print
      if ($0 ~ /^[[:space:]]*\}[[:space:]]*$/) {
        exit
      }
    }
  ' "$source_config" >"$locked_block"
}

write_stub() {
  local target=$1
  local body=$2
  local root

  root=$(guard_guess_repo_tmp_root "$repo_root" "$target") || {
    fail "unsafe stub target: $target"
    return 1
  }
  guard_assert_path "$root" "$target" create || {
    fail "unsafe stub target: $target"
    return 1
  }
  printf '%s' "$body" >"$target"
  guard_exec "$root" chmod +x "$target"
}

setup_tmp_root() {
  tmp_root=$(mktemp -d "$repo_root/.tmp_zellij.XXXXXX")
  guard_assert_repo_tmp_root "$repo_root" "$tmp_root"
  guard_exec "$tmp_root" mkdir -p "$tmp_root/bin" "$tmp_root/tmp"
}

cleanup() {
  if [ -n "$tmp_root" ] && [ -d "$tmp_root" ]; then
    guard_assert_repo_tmp_root "$repo_root" "$tmp_root" && guard_exec "$tmp_root" rm -rf "$tmp_root"
  fi
}

render_zellij_config() {
  local rendered_config="$tmp_root/.config/zellij/config.kdl"
  local locked_block="$tmp_root/locked-block.kdl"

  guard_exec "$tmp_root" mkdir -p "$(dirname "$rendered_config")"
  guard_assert_path "$tmp_root" "$rendered_config" create
  "$real_chezmoi" -S "$repo_root" -D "$tmp_root" cat "$rendered_config" >"$rendered_config"
  write_locked_block "$rendered_config" "$locked_block"

  assert_file_contains "$locked_block" 'bind "Ctrl space" { SwitchToMode "tmux"; }' \
    "locked mode should allow Ctrl-space to enter tmux mode"

  for binding in \
    'bind "Alt 1" { GoToTab 1; }' \
    'bind "Alt 2" { GoToTab 2; }' \
    'bind "Alt 3" { GoToTab 3; }' \
    'bind "Alt 4" { GoToTab 4; }' \
    'bind "Alt 5" { GoToTab 5; }' \
    'bind "Alt 6" { GoToTab 6; }' \
    'bind "Alt 7" { GoToTab 7; }' \
    'bind "Alt 8" { GoToTab 8; }' \
    'bind "Alt 9" { GoToTab 9; }' \
    'bind "Alt 0" { GoToTab 10; }'
  do
    assert_file_contains "$locked_block" "$binding" "locked mode should include $binding"
  done

  assert_file_contains "$rendered_config" 'bind "Alt 0" { GoToTab 10; SwitchToMode "normal"; }' \
    "non-locked modes should keep Alt 0 normal-mode behavior"
  assert_file_contains "$rendered_config" 'support_kitty_keyboard_protocol false' \
    "zellij should disable kitty keyboard protocol for Codex TUI stability across detach"
  assert_file_contains "$rendered_config" 'Run "zellij-safe-detach" {' \
    "detach binding should run the safe detach helper"
  assert_file_contains "$rendered_config" 'floating true' \
    "safe detach helper should run in a floating pane"
  assert_file_contains "$rendered_config" 'close_on_exit true' \
    "safe detach helper pane should close after detach"
  assert_file_not_contains "$rendered_config" 'bind "d" { Detach; }' \
    "detach binding should not detach directly from the focused app pane"

  # Mode locking is done by the headless autolock plugin, in-process inside the
  # zellij server. It replaced a 5 Hz shell poller whose liveness probes could
  # get a live session's socket deleted; see README.
  assert_file_contains "$rendered_config" 'autolock location="file:/' \
    "autolock plugin should be referenced by an absolute path, not a bare ~"
  assert_file_contains "$rendered_config" '/.config/zellij/plugins/zellij-autolock.wasm"' \
    "autolock plugin should resolve to the zellij plugin dir"
  assert_file_contains "$rendered_config" 'triggers "nvim|vim|vimdiff|view|codex|claude"' \
    "autolock should lock for editors and coding agents"
  assert_file_contains "$rendered_config" 'is_enabled true' \
    "autolock should be enabled"

  awk '
    /^[[:space:]]*load_plugins[[:space:]]*\{/ { in_block = 1; next }
    in_block && /^[[:space:]]*\}[[:space:]]*$/ { exit }
    in_block { print }
  ' "$rendered_config" >"$tmp_root/load-plugins.kdl"
  assert_file_contains "$tmp_root/load-plugins.kdl" 'autolock' \
    "autolock should be started in the background on every new session"
}

assert_no_polling_watcher() {
  if [ -e "$repo_root/bin/zellij-lock-watch" ]; then
    fail "bin/zellij-lock-watch should be gone: its zellij action polling could delete a live session socket"
  fi

  # Comments may still explain why the poller is gone; nothing may still run it.
  local hits
  hits=$(grep -rn 'zellij-lock-watch' \
    "$repo_root/bin" "$repo_root/.chezmoitemplates" "$repo_root/dot_config" 2>/dev/null |
    grep -vE ':[[:space:]]*(#|//)' || true)
  if [ -n "$hits" ]; then
    fail "zellij-lock-watch is still invoked by: $(echo "$hits" | cut -d: -f1,2 | tr '\n' ' ')"
  fi
}

assert_plugin_external_is_pinned() {
  local external="$repo_root/.chezmoiexternal.toml"

  if [ ! -f "$external" ]; then
    fail ".chezmoiexternal.toml should declare the autolock plugin download"
    return
  fi

  assert_file_contains "$external" '.config/zellij/plugins/zellij-autolock.wasm' \
    "autolock plugin should be fetched into the zellij plugin dir"
  assert_file_contains "$external" 'checksum.sha256' \
    "autolock plugin download should be checksum-pinned"
  if grep -E 'url = ".*/(latest|main|master)/' "$external" >/dev/null 2>&1; then
    fail "autolock plugin download should pin an exact release, not a moving ref"
  fi
}

run_safe_detach_case() {
  local name=$1
  local zellij_env=$2
  local expected_log=$3
  local actual_log

  : >"$tmp_root/safe-detach.log"

  if [ -n "$zellij_env" ]; then
    PATH="$tmp_root/bin:$PATH" \
      ZELLIJ="$zellij_env" \
      ZELLIJ_STUB_LOG="$tmp_root/safe-detach.log" \
      "$repo_root/bin/zellij-safe-detach"
  else
    env -u ZELLIJ \
      PATH="$tmp_root/bin:$PATH" \
      ZELLIJ_STUB_LOG="$tmp_root/safe-detach.log" \
      "$repo_root/bin/zellij-safe-detach"
  fi

  actual_log=$(cat "$tmp_root/safe-detach.log")
  assert_equal "$actual_log" "$expected_log" "$name should call expected zellij actions"
}

setup_tmp_root
trap cleanup EXIT

render_zellij_config
assert_no_polling_watcher
assert_plugin_external_is_pinned

write_stub "$tmp_root/bin/zellij" '#!/usr/bin/env bash
set -euo pipefail

printf "%s\n" "$*" >>"$ZELLIJ_STUB_LOG"
'
run_safe_detach_case "safe-detach-outside-zellij" "" ""
run_safe_detach_case "safe-detach-inside-zellij" "0" $'action switch-mode normal\naction detach'

if [ "$failures" -eq 0 ]; then
  echo 'All zellij config tests passed'
fi

exit "$failures"
