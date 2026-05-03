#!/usr/bin/env bash
set -euo pipefail

script_path=$(realpath "${BASH_SOURCE[0]}")
repo_root=$(realpath "$(dirname "$script_path")/..")
# shellcheck source=tests/prefix_guard_common.sh
source "$repo_root/tests/prefix_guard_common.sh"

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
  printf '%s' "$body" > "$target"
  guard_exec "$root" chmod +x "$target"
}

setup_tmp_root() {
  tmp_root=$(mktemp -d "$repo_root/.tmp_cloudtop.XXXXXX")
  guard_assert_repo_tmp_root "$repo_root" "$tmp_root" || return 1
  guard_exec "$tmp_root" mkdir -p "$tmp_root/bin" "$tmp_root/home"
}

cleanup() {
  if [ -n "$tmp_root" ] && [ -d "$tmp_root" ]; then
    guard_assert_repo_tmp_root "$repo_root" "$tmp_root" && guard_exec "$tmp_root" rm -rf "$tmp_root"
  fi
}

test_local_zellij_session_name() {
  write_stub "$tmp_root/bin/hostname" '#!/usr/bin/env sh
if [ "$1" = "-s" ]; then
  printf "%s\n" "My.Remote.Hostname"
else
  printf "%s\n" "My.Remote.Hostname.example.com"
fi
'
  write_stub "$tmp_root/bin/zellij" "#!/usr/bin/env sh
printf '%s\n' \"\$*\" > \"$tmp_root/zellij.log\"
"

  env -i \
    HOME="$tmp_root/home" \
    PATH="$tmp_root/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    "$repo_root/bin/cloudtop" >/dev/null

  assert_equal "$(cat "$tmp_root/zellij.log")" "attach --create my-remote" "local cloudtop should use 10-char host prefix"
}

test_remote_zellij_session_name() {
  write_stub "$tmp_root/bin/zellij" "#!/usr/bin/env sh
printf '%s\n' \"\$*\" > \"$tmp_root/remote-zellij.log\"
"
  write_stub "$tmp_root/bin/ssh" '#!/usr/bin/env sh
last=
for arg do
  last=$arg
done
RAVY_ZELLIJ_HOST=Remote-Machine-999
export RAVY_ZELLIJ_HOST
eval "$last"
'

  env -i \
    HOME="$tmp_root/home" \
    PATH="$tmp_root/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    SSH_COMMAND="$tmp_root/bin/ssh" \
    "$repo_root/bin/cloudtop" remote.example.com >/dev/null

  assert_equal "$(cat "$tmp_root/remote-zellij.log")" "attach --create remote-mac" "remote cloudtop should compute host prefix on the remote side"
}

trap cleanup EXIT

setup_tmp_root
test_local_zellij_session_name
test_remote_zellij_session_name

if [ "$failures" -ne 0 ]; then
  exit 1
fi
