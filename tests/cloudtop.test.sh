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
if [ \"\$1\" = \"which\" ] && [ \"\$2\" = \"zellij\" ] && [ \"\$3\" = \"--tool\" ] && [ \"\$4\" = \"zellij@0.44.1\" ]; then
  printf '%s\n' \"$tmp_root/mise-zellij/zellij\"
  exit 0
fi
if [ \"\$1\" = \"where\" ] && [ \"\$2\" = \"zellij@0.44.1\" ]; then
  printf '%s\n' \"$tmp_root/mise-zellij\"
  exit 0
fi
exit 1
"

  env -i \
    HOME="$tmp_root/home" \
    PATH="$tmp_root/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    "$repo_root/bin/cloudtop" >/dev/null

  assert_equal "$(head -n 1 "$tmp_root/mise.log")" "which zellij --tool zellij@0.44.1" "local cloudtop should ask mise for the pinned zellij version"
  assert_equal "$(cat "$tmp_root/mise-zellij.log")" "attach --forget --create my-remote" "local cloudtop should use mise zellij when PATH has no zellij"
}

test_remote_zellij_mise_fallback_with_version_override() {
  guard_exec "$tmp_root" rm -f "$tmp_root/bin/zellij" "$tmp_root/remote-mise.log" "$tmp_root/remote-mise-zellij.log"
  guard_exec "$tmp_root" mkdir -p "$tmp_root/remote-mise-zellij"

  write_stub "$tmp_root/remote-mise-zellij/zellij" "#!/usr/bin/env sh
printf '%s\n' \"\$*\" > \"$tmp_root/remote-mise-zellij.log\"
"
  write_stub "$tmp_root/bin/mise" "#!/usr/bin/env sh
printf '%s\n' \"\$*\" >> \"$tmp_root/remote-mise.log\"
if [ \"\$1\" = \"which\" ] && [ \"\$2\" = \"zellij\" ] && [ \"\$3\" = \"--tool\" ] && [ \"\$4\" = \"zellij@0.44.0\" ]; then
  printf '%s\n' \"$tmp_root/remote-mise-zellij/zellij\"
  exit 0
fi
if [ \"\$1\" = \"where\" ] && [ \"\$2\" = \"zellij@0.44.0\" ]; then
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
unset CLOUDTOP_ZELLIJ_VERSION
eval "$last"
'

  env -i \
    HOME="$tmp_root/home" \
    PATH="$tmp_root/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    SSH_COMMAND="$tmp_root/bin/ssh" \
    CLOUDTOP_ZELLIJ_VERSION=0.44.0 \
    "$repo_root/bin/cloudtop" remote.example.com >/dev/null

  assert_equal "$(head -n 1 "$tmp_root/remote-mise.log")" "which zellij --tool zellij@0.44.0" "remote cloudtop should embed CLOUDTOP_ZELLIJ_VERSION in the remote script"
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

trap cleanup EXIT

setup_tmp_root
test_local_zellij_session_name
test_remote_zellij_session_name
test_local_zellij_mise_fallback
test_remote_zellij_mise_fallback_with_version_override
test_remote_ssh_auth_sock_bridge

if [ "$failures" -ne 0 ]; then
  exit 1
fi
