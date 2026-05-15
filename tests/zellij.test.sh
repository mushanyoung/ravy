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
}

write_zellij_stub() {
  write_stub "$tmp_root/bin/zellij" '#!/usr/bin/env bash
set -euo pipefail

case "$*" in
  "action list-tabs --json --state")
    cat "$ZELLIJ_STUB_TABS"
    ;;
  "action list-panes --json --all")
    cat "$ZELLIJ_STUB_PANES"
    ;;
  action\ switch-mode\ *)
    printf "%s\n" "$3" >>"$ZELLIJ_STUB_MODES"
    ;;
  *)
    printf "unexpected zellij args: %s\n" "$*" >&2
    exit 1
    ;;
esac
'
}

write_watcher_fixture() {
  local pane_command=$1
  local pane_title=$2

  jq -n '[{tab_id: 1, active: true}, {tab_id: 2, active: false}]' >"$tmp_root/tabs.json"
  jq -n --arg command "$pane_command" --arg title "$pane_title" '
    [
      {
        tab_id: 1,
        is_focused: true,
        is_plugin: false,
        is_selectable: true,
        pane_command: $command,
        title: $title
      }
    ]
  ' >"$tmp_root/panes.json"
}

run_watcher_case() {
  local name=$1
  local pane_command=$2
  local pane_title=$3
  local iterations=$4
  local expected_modes=$5
  local actual_modes

  write_watcher_fixture "$pane_command" "$pane_title"
  : >"$tmp_root/modes.log"

  PATH="$tmp_root/bin:$PATH" \
    TMPDIR="$tmp_root/tmp" \
    ZELLIJ=0 \
    ZELLIJ_SESSION_NAME="zellij-test-$name" \
    ZELLIJ_STUB_TABS="$tmp_root/tabs.json" \
    ZELLIJ_STUB_PANES="$tmp_root/panes.json" \
    ZELLIJ_STUB_MODES="$tmp_root/modes.log" \
    ZELLIJ_NVIM_LOCK_INTERVAL=0 \
    ZELLIJ_NVIM_LOCK_ITERATIONS="$iterations" \
    "$repo_root/bin/zellij-nvim-lock-watch"

  actual_modes=$(cat "$tmp_root/modes.log")
  assert_equal "$actual_modes" "$expected_modes" "$name should switch to expected mode"
}

setup_tmp_root
trap cleanup EXIT

if ! command -v jq >/dev/null 2>&1; then
  fail "jq is required for zellij watcher tests"
else
  render_zellij_config
  write_zellij_stub
  run_watcher_case "nvim-command" "nvim /tmp/file" "file" 1 "locked"
  run_watcher_case "normal-command" "/opt/homebrew/bin/fish" "~" 1 "normal"
  run_watcher_case "title-prefix" "/bin/sh" "$(printf '\342\234\217\357\270\217  file')" 1 "locked"
  run_watcher_case "deduplicates" "nvim /tmp/file" "file" 2 "locked"
fi

if [ "$failures" -eq 0 ]; then
  echo 'All zellij config tests passed'
fi

exit "$failures"
