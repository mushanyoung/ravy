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

assert_file_contains() {
  local file=$1
  local pattern=$2
  local msg=$3

  if ! grep -Eq "$pattern" "$file"; then
    fail "$msg: pattern '$pattern' not found in $file"
  fi
}

assert_file_not_contains() {
  local file=$1
  local pattern=$2
  local msg=$3

  if grep -Eq "$pattern" "$file"; then
    fail "$msg: unexpected pattern '$pattern' found in $file"
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

  assert_equal "$(cat "$tmp_root/zellij.log")" "attach --forget --create my-remote" "local cloudtop should use 10-char host prefix"
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

  assert_equal "$(cat "$tmp_root/remote-zellij.log")" "attach --forget --create remote-mac" "remote cloudtop should compute host prefix on the remote side"
}

test_local_zellij_mise_fallback() {
  guard_exec "$tmp_root" rm -f "$tmp_root/bin/zellij" "$tmp_root/mise.log" "$tmp_root/mise-zellij.log"
  guard_exec "$tmp_root" mkdir -p "$tmp_root/mise-zellij"

  write_stub "$tmp_root/bin/hostname" '#!/usr/bin/env sh
if [ "$1" = "-s" ]; then
  printf "%s\n" "My.Remote.Hostname"
else
  printf "%s\n" "My.Remote.Hostname.example.com"
fi
'
  write_stub "$tmp_root/mise-zellij/zellij" "#!/usr/bin/env sh
printf '%s\n' \"\$*\" > \"$tmp_root/mise-zellij.log\"
"
  write_stub "$tmp_root/bin/mise" "#!/usr/bin/env sh
printf '%s\n' \"\$*\" >> \"$tmp_root/mise.log\"
if [ \"\$1\" = \"which\" ] && [ \"\$2\" = \"zellij\" ]; then
  printf '%s\n' \"$tmp_root/mise-zellij/zellij\"
  exit 0
fi
if [ \"\$1\" = \"where\" ] && [ \"\$2\" = \"zellij\" ]; then
  printf '%s\n' \"$tmp_root/mise-zellij\"
  exit 0
fi
exit 1
"

  env -i \
    HOME="$tmp_root/home" \
    PATH="$tmp_root/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    "$repo_root/bin/cloudtop" >/dev/null

  assert_equal "$(head -n 1 "$tmp_root/mise.log")" "which zellij" "local cloudtop should ask mise for zellij"
  assert_equal "$(cat "$tmp_root/mise-zellij.log")" "attach --forget --create my-remote" "local cloudtop should use mise zellij when PATH has no zellij"
}

test_remote_zellij_mise_fallback() {
  guard_exec "$tmp_root" rm -f "$tmp_root/bin/zellij" "$tmp_root/remote-mise.log" "$tmp_root/remote-mise-zellij.log"
  guard_exec "$tmp_root" mkdir -p "$tmp_root/remote-mise-zellij"

  write_stub "$tmp_root/remote-mise-zellij/zellij" "#!/usr/bin/env sh
printf '%s\n' \"\$*\" > \"$tmp_root/remote-mise-zellij.log\"
"
  write_stub "$tmp_root/bin/mise" "#!/usr/bin/env sh
printf '%s\n' \"\$*\" >> \"$tmp_root/remote-mise.log\"
if [ \"\$1\" = \"which\" ] && [ \"\$2\" = \"zellij\" ]; then
  printf '%s\n' \"$tmp_root/remote-mise-zellij/zellij\"
  exit 0
fi
if [ \"\$1\" = \"where\" ] && [ \"\$2\" = \"zellij\" ]; then
  printf '%s\n' \"$tmp_root/remote-mise-zellij\"
  exit 0
fi
exit 1
"
  write_stub "$tmp_root/bin/ssh" '#!/usr/bin/env sh
last=
for arg do
  last=$arg
done
RAVY_ZELLIJ_HOST=Remote-Mise-Test
export RAVY_ZELLIJ_HOST
eval "$last"
'

  env -i \
    HOME="$tmp_root/home" \
    PATH="$tmp_root/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    SSH_COMMAND="$tmp_root/bin/ssh" \
    "$repo_root/bin/cloudtop" remote.example.com >/dev/null

  assert_equal "$(head -n 1 "$tmp_root/remote-mise.log")" "which zellij" "remote cloudtop should ask mise for zellij"
  assert_equal "$(cat "$tmp_root/remote-mise-zellij.log")" "attach --forget --create remote-mis" "remote cloudtop should use mise zellij when PATH has no zellij"
}

test_remote_ssh_auth_sock_bridge() {
  local agent_cmd
  local agent_sock

  agent_cmd=$(command -v ssh-agent 2>/dev/null || true)
  if [ -z "$agent_cmd" ]; then
    printf '%s\n' 'SKIP remote SSH auth sock bridge: ssh-agent not found' >&2
    return 0
  fi

  agent_sock="$tmp_root/agent.sock"
  guard_exec "$tmp_root" mkdir -p "$tmp_root/home/.ssh"
  guard_exec "$tmp_root" ln -s "$tmp_root/dead-agent.sock" "$tmp_root/home/.ssh/ssh_auth_sock"

  write_stub "$tmp_root/bin/zellij" "#!/usr/bin/env sh
{
  printf '%s\n' \"env=\${SSH_AUTH_SOCK:-}\"
  if [ -S \"\$HOME/.ssh/ssh_auth_sock\" ]; then
    printf '%s\n' 'stable_socket=1'
  else
    printf '%s\n' 'stable_socket=0'
  fi
  target=\$(readlink \"\$HOME/.ssh/ssh_auth_sock\" 2>/dev/null || true)
  printf '%s\n' \"target=\$target\"
} > \"$tmp_root/remote-agent.log\"
"
  write_stub "$tmp_root/bin/ssh" "#!/usr/bin/env sh
printf '%s\n' \"\$@\" > \"$tmp_root/remote-agent-ssh-args.log\"
last=
for arg do
  last=\$arg
done
RAVY_ZELLIJ_HOST=Remote-Agent-Test
export RAVY_ZELLIJ_HOST
eval \"\$last\"
"

  env -i \
    HOME="$tmp_root/home" \
    PATH="$tmp_root/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    SSH_COMMAND="$tmp_root/bin/ssh" \
    "$agent_cmd" -a "$agent_sock" "$repo_root/bin/cloudtop" remote.example.com >/dev/null

  assert_equal "$(awk 'prev == "-S" && $0 == "none" { print "present"; exit } { prev = $0 }' "$tmp_root/remote-agent-ssh-args.log")" "present" "remote cloudtop should disable SSH ControlMaster reuse"
  assert_equal "$(grep '^env=' "$tmp_root/remote-agent.log")" "env=$tmp_root/home/.ssh/ssh_auth_sock" "remote cloudtop should expose the stable SSH auth socket"
  assert_equal "$(grep '^stable_socket=' "$tmp_root/remote-agent.log")" "stable_socket=1" "remote cloudtop should point the stable SSH auth socket at a live socket"
  assert_equal "$(grep '^target=' "$tmp_root/remote-agent.log")" "target=$agent_sock" "remote cloudtop should repair a stale stable SSH auth socket target"
}

test_remote_helper_cache_short_command_and_reuse() {
  local helper_path
  local helper_dir

  guard_exec "$tmp_root" rm -rf "$tmp_root/home/.cache/cloudtop"
  guard_exec "$tmp_root" rm -f "$tmp_root/cache-ssh-args.log" "$tmp_root/cache-zellij.log"

  write_stub "$tmp_root/bin/zellij" "#!/usr/bin/env sh
printf '%s\n' \"\$*\" >> \"$tmp_root/cache-zellij.log\"
"
  write_stub "$tmp_root/bin/ssh" "#!/usr/bin/env sh
{
  printf '%s\n' '-- invocation --'
  for arg do
    printf '%s\n' \"\$arg\"
  done
} >> \"$tmp_root/cache-ssh-args.log\"
last=
for arg do
  last=\$arg
done
RAVY_ZELLIJ_HOST=Cache-Test-Host
export RAVY_ZELLIJ_HOST
eval \"\$last\"
"

  env -i \
    HOME="$tmp_root/home" \
    PATH="$tmp_root/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    SSH_COMMAND="$tmp_root/bin/ssh" \
    "$repo_root/bin/cloudtop" remote.example.com >/dev/null

  helper_path=$(find "$tmp_root/home/.cache/cloudtop" -path '*/attach' -type f -print | head -n 1)
  if [ -z "$helper_path" ]; then
    fail "remote cloudtop should install a cached helper"
    return
  fi

  helper_dir=$(dirname "$helper_path")
  guard_exec "$tmp_root" chmod 500 "$helper_dir"
  if ! env -i \
    HOME="$tmp_root/home" \
    PATH="$tmp_root/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    SSH_COMMAND="$tmp_root/bin/ssh" \
    "$repo_root/bin/cloudtop" remote.example.com >/dev/null
  then
    guard_exec "$tmp_root" chmod 700 "$helper_dir"
    fail "remote cloudtop should reuse an existing executable cached helper without overwriting it"
    return
  fi
  guard_exec "$tmp_root" chmod 700 "$helper_dir"

  assert_equal "$(grep -c '^-- invocation --$' "$tmp_root/cache-ssh-args.log")" "4" "remote cloudtop should run one install check and one attach command per SSH run"
  assert_equal "$(grep -c '^attach --forget --create cache-test$' "$tmp_root/cache-zellij.log")" "2" "remote cloudtop should attach through the cached helper on both runs"
  assert_file_contains "$tmp_root/cache-ssh-args.log" '\.cache/cloudtop/[0-9a-f]{5}/attach' "remote cloudtop should execute the cached helper path"
  assert_file_not_contains "$tmp_root/cache-ssh-args.log" 'find_zellij' "remote cloudtop should not inline helper function bodies in SSH argv"
  assert_file_contains "$tmp_root/cache-ssh-args.log" '^/bin/sh -lc '\''exec "\$HOME/[.]cache/cloudtop/[0-9a-f]{5}/attach" 1'\''$' "remote cloudtop should enter /bin/sh login shell before the cached helper"
}

test_mosh_uses_cached_helper() {
  guard_exec "$tmp_root" rm -rf "$tmp_root/home/.cache/cloudtop"
  guard_exec "$tmp_root" rm -f "$tmp_root/mosh-ssh-args.log" "$tmp_root/mosh-args.log" "$tmp_root/mosh-zellij.log"

  write_stub "$tmp_root/bin/zellij" "#!/usr/bin/env sh
printf '%s\n' \"\$*\" > \"$tmp_root/mosh-zellij.log\"
"
  write_stub "$tmp_root/bin/ssh" "#!/usr/bin/env sh
{
  printf '%s\n' '-- ssh invocation --'
  for arg do
    printf '%s\n' \"\$arg\"
  done
} >> \"$tmp_root/mosh-ssh-args.log\"
last=
for arg do
  last=\$arg
done
eval \"\$last\"
"
  write_stub "$tmp_root/bin/mosh" "#!/usr/bin/env sh
{
  printf '%s\n' '-- mosh invocation --'
  for arg do
    printf '%s\n' \"\$arg\"
  done
} > \"$tmp_root/mosh-args.log\"
found_sep=0
found_host=0
while [ \"\$#\" -gt 0 ]; do
  if [ \"\$found_sep\" = 0 ]; then
    if [ \"\$1\" = \"--\" ]; then
      found_sep=1
    fi
    shift
    continue
  fi
  if [ \"\$found_host\" = 0 ]; then
    found_host=1
    shift
    continue
  fi
  break
done
RAVY_ZELLIJ_HOST=Remote-Mosh-Test
export RAVY_ZELLIJ_HOST
\"\$@\"
"

  env -i \
    HOME="$tmp_root/home" \
    PATH="$tmp_root/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    SSH_COMMAND="$tmp_root/bin/ssh" \
    MOSH_COMMAND="$tmp_root/bin/mosh" \
    "$repo_root/bin/cloudtop" --mosh remote.example.com >/dev/null

  assert_equal "$(cat "$tmp_root/mosh-zellij.log")" "attach --forget --create remote-mos" "mosh cloudtop should attach through the cached helper"
  assert_equal "$(grep -c '^-- ssh invocation --$' "$tmp_root/mosh-ssh-args.log")" "1" "mosh cloudtop should use SSH once to install the cached helper"
  assert_file_contains "$tmp_root/mosh-args.log" '\.cache/cloudtop/[0-9a-f]{5}/attach" 0' "mosh cloudtop should run the cached helper with agent bridge disabled"
  assert_file_not_contains "$tmp_root/mosh-args.log" 'find_zellij' "mosh cloudtop should not inline helper function bodies in mosh argv"
}

test_tmux_is_rejected() {
  guard_exec "$tmp_root" rm -f "$tmp_root/tmux-error.log"

  if env -i \
    HOME="$tmp_root/home" \
    PATH="$tmp_root/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    "$repo_root/bin/cloudtop" --tmux > /dev/null 2>"$tmp_root/tmux-error.log"
  then
    fail "cloudtop should reject tmux mode"
    return
  fi

  assert_file_contains "$tmp_root/tmux-error.log" 'no longer supports tmux' "cloudtop should explain that tmux mode was removed"
}

trap cleanup EXIT

setup_tmp_root
test_local_zellij_session_name
test_remote_zellij_session_name
test_local_zellij_mise_fallback
test_remote_zellij_mise_fallback
test_remote_ssh_auth_sock_bridge
test_remote_helper_cache_short_command_and_reuse
test_mosh_uses_cached_helper
test_tmux_is_rejected

if [ "$failures" -ne 0 ]; then
  exit 1
fi
