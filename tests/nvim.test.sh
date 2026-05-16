#!/usr/bin/env bash
set -euo pipefail

script_path=$(realpath "${BASH_SOURCE[0]}")
repo_root=$(realpath "$(dirname "$script_path")/..")
# shellcheck source=tests/prefix_guard_common.sh
source "$repo_root/tests/prefix_guard_common.sh"
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

assert_file_exists() {
  local path=$1
  local msg=$2
  if [ ! -f "$path" ]; then
    fail "$msg"
  fi
}

assert_file_missing() {
  local path=$1
  local msg=$2
  if [ -e "$path" ] || [ -L "$path" ]; then
    fail "$msg"
  fi
}

tmp_home=$(mktemp -d "$repo_root/.tmp_nvim_home.XXXXXX")
guard_assert_repo_tmp_root "$repo_root" "$tmp_home"
trap '
  if [ -n "${tmp_home:-}" ] && [ -d "$tmp_home" ]; then
    guard_exec "$tmp_home" rm -rf "$tmp_home"
  fi
' EXIT

rendered_nvim_dir="$tmp_home/.config/nvim"
rendered_init="$rendered_nvim_dir/init.lua"
stale_init="$rendered_nvim_dir/init.vim"
stale_main="$rendered_nvim_dir/ravy.vim"
headless_log="$tmp_home/nvim-headless.log"
register_log="$tmp_home/nvim-registers.log"
register_test="$tmp_home/nvim-registers.lua"
nvim_sources=()
while IFS= read -r source; do
  nvim_sources+=("$source")
done < <(find "$repo_root/dot_config/nvim" -type f -print | sort)

guard_exec "$tmp_home" mkdir -p "$(dirname "$rendered_init")" "$rendered_nvim_dir/lua/ravy"
guard_assert_path "$tmp_home" "$stale_init" create
printf 'stale vim entrypoint\n' > "$stale_init"
guard_assert_path "$tmp_home" "$stale_main" create
printf 'stale rendered vimrc\n' > "$stale_main"

"$real_chezmoi" -S "$repo_root" -D "$tmp_home" apply --force --source-path "${nvim_sources[@]}"

assert_file_exists "$rendered_init" "init.lua is rendered as the Neovim entrypoint"
assert_file_missing "$stale_init" "old init.vim is removed to avoid Neovim entrypoint conflicts"
assert_file_missing "$stale_main" "old ravy.vim render target is removed"

assert_file_contains "$rendered_init" "RAVY_NVIM_SKIP_PLUGINS" "init.lua supports a plugin-free test mode"
assert_file_contains "$rendered_nvim_dir/lua/ravy/plugins.lua" "folke/lazy.nvim" "plugins.lua bootstraps lazy.nvim"
assert_file_contains "$rendered_nvim_dir/lua/ravy/plugins.lua" "nvim-telescope/telescope.nvim" "plugins.lua uses Telescope"
assert_file_contains "$rendered_nvim_dir/lua/ravy/plugins.lua" "neoclide/coc.nvim" "plugins.lua keeps CoC"
assert_file_contains "$rendered_nvim_dir/lua/ravy/plugins.lua" "https://codeberg.org/andyg/leap.nvim" "plugins.lua uses the Codeberg leap.nvim URL"
assert_file_contains "$rendered_nvim_dir/lua/ravy/plugins.lua" "<Plug>(leap-forward)" "plugins.lua uses explicit leap.nvim mappings"
assert_file_lacks "$rendered_nvim_dir/lua/ravy/plugins.lua" "create_default_mappings" "plugins.lua avoids deprecated leap.nvim default mappings"
assert_file_contains "$rendered_nvim_dir/lua/ravy/autocmds.lua" "zellij_lock" "autocmds.lua keeps zellij lock integration"
assert_file_contains "$rendered_nvim_dir/lua/ravy/private.lua" "RAVY_PRIVATE_HOME" "private.lua loads the private Lua overlay"
assert_file_lacks "$rendered_init" "ravy.vim" "init.lua no longer sources the old rendered vimrc"

guard_assert_path "$tmp_home" "$headless_log" create
if ! RAVY_NVIM_SKIP_PLUGINS=1 \
  XDG_CONFIG_HOME="$tmp_home/.config" \
  XDG_DATA_HOME="$tmp_home/.local/share" \
  XDG_STATE_HOME="$tmp_home/.local/state" \
  XDG_CACHE_HOME="$tmp_home/.cache" \
  nvim --headless +qa >"$headless_log" 2>&1; then
  cat "$headless_log" >&2
  fail "Neovim can load the Lua config in headless plugin-free mode"
fi

guard_assert_path "$tmp_home" "$register_test" create
cat >"$register_test" <<'LUA'
local function assert_eq(actual, expected, message)
  if actual ~= expected then
    error(message .. ": expected " .. vim.inspect(expected) .. ", got " .. vim.inspect(actual), 0)
  end
end

local function feed(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt", false)
end

local function buffer_text()
  return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
end

local function reset(lines)
  vim.cmd("enew!")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.fn.setreg('"', "sentinel", "v")
  vim.fn.setreg("+", "clip-sentinel", "v")
end

reset({ "alpha", "beta" })
feed("dd")
assert_eq(buffer_text(), "beta", "dd deletes the current line")
assert_eq(vim.fn.getreg('"'), "sentinel", "dd preserves the default register")
assert_eq(vim.fn.getreg("+"), "clip-sentinel", "dd preserves the clipboard register")

reset({ "alpha beta" })
feed("diw")
assert_eq(buffer_text(), " beta", "diw deletes the inner word")
assert_eq(vim.fn.getreg('"'), "sentinel", "diw preserves the default register")
assert_eq(vim.fn.getreg("+"), "clip-sentinel", "diw preserves the clipboard register")

reset({ "alpha", "beta" })
feed("mm")
assert_eq(buffer_text(), "beta", "mm cuts the current line")
assert_eq(vim.fn.getreg('"'), "alpha", "mm writes to the default register")

reset({ "alpha beta" })
feed("miw")
assert_eq(buffer_text(), " beta", "miw cuts the inner word")
assert_eq(vim.fn.getreg('"'), "alpha", "miw writes to the default register")
LUA

guard_assert_path "$tmp_home" "$register_log" create
if ! RAVY_NVIM_SKIP_PLUGINS=1 \
  XDG_CONFIG_HOME="$tmp_home/.config" \
  XDG_DATA_HOME="$tmp_home/.local/share" \
  XDG_STATE_HOME="$tmp_home/.local/state" \
  XDG_CACHE_HOME="$tmp_home/.cache" \
  nvim --headless +"luafile $register_test" +qa! >"$register_log" 2>&1; then
  cat "$register_log" >&2
  fail "Neovim preserves cutlass-style delete and cut register behavior"
fi

if [ "$failures" -eq 0 ]; then
  echo 'All nvim config tests passed'
fi

exit "$failures"
