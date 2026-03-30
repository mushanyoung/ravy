#!/usr/bin/env bash
set -euo pipefail

script_path=$(realpath "${BASH_SOURCE[0]}")
repo_root=$(realpath "$(dirname "$script_path")/..")
# shellcheck source=tests/prefix_guard_common.sh
source "$repo_root/tests/prefix_guard_common.sh"
bash_bin=$(command -v bash)
nu_bin=$(command -v nu)
harness_script="$repo_root/scripts/nushell-harness.sh"

failures=0

fail() {
  echo "FAIL $1" >&2
  failures=$((failures + 1))
}

assert_status_zero() {
  local status=$1
  local msg=$2
  local output=${3:-}

  if [ "$status" -ne 0 ]; then
    fail "$msg${output:+: $output}"
  fi
}

assert_exists() {
  local path=$1

  if [ ! -e "$path" ] && [ ! -L "$path" ]; then
    fail "$path does not exist"
  fi
}

assert_not_exists() {
  local path=$1

  if [ -e "$path" ] || [ -L "$path" ]; then
    fail "$path should not exist"
  fi
}

assert_file_contains() {
  local path=$1
  local expected=$2

  if ! grep -F "$expected" "$path" >/dev/null 2>&1; then
    fail "$path is missing: $expected"
  fi
}

assert_symlink_target() {
  local path=$1
  local target=$2

  if [ ! -L "$path" ]; then
    fail "$path is not a symlink"
    return
  fi

  if [ "$(readlink "$path")" != "$target" ]; then
    fail "$path points to $(readlink "$path"), expected $target"
  fi
}

darwin_home=$(mktemp -d "$repo_root/.tmp_nushell_harness_home.XXXXXX")
linux_home=$(mktemp -d "$repo_root/.tmp_nushell_harness_linux.XXXXXX")
guard_assert_repo_tmp_root "$repo_root" "$darwin_home"
guard_assert_repo_tmp_root "$repo_root" "$linux_home"
trap '
  if [ -n "${darwin_home:-}" ] && [ -d "$darwin_home" ]; then
    guard_exec "$darwin_home" rm -rf "$darwin_home"
  fi
  if [ -n "${linux_home:-}" ] && [ -d "$linux_home" ]; then
    guard_exec "$linux_home" rm -rf "$linux_home"
  fi
' EXIT

canonical_dir="$darwin_home/.config/nushell"
native_dir="$darwin_home/Library/Application Support/nushell"
canonical_history="$canonical_dir/history.txt"
native_history="$native_dir/history.txt"

guard_exec "$darwin_home" mkdir -p "$canonical_dir" "$native_dir" "$darwin_home/bin"
guard_exec "$linux_home" mkdir -p "$linux_home/bin"
guard_install_wrappers "$darwin_home" "$darwin_home/bin"
guard_install_wrappers "$linux_home" "$linux_home/bin"

guard_assert_path "$darwin_home" "$canonical_dir/env.nu" create
cat > "$canonical_dir/env.nu" <<'EOF'
$env.__RAVY_CANONICAL_ENV = "1"
EOF

guard_assert_path "$darwin_home" "$canonical_dir/config.nu" create
cat > "$canonical_dir/config.nu" <<'EOF'
$env.__RAVY_CANONICAL_CONFIG = "1"
EOF

guard_assert_path "$darwin_home" "$canonical_dir/login.nu" create
cat > "$canonical_dir/login.nu" <<'EOF'
$env.__RAVY_LOGIN_INIT = "1"
EOF

guard_assert_path "$darwin_home" "$canonical_history" create
printf '%s\n' 'canonical-entry' > "$canonical_history"
guard_assert_path "$darwin_home" "$native_history" create
printf '%s\n' 'native-entry' > "$native_history"

set +e
darwin_output=$(env -i HOME="$darwin_home" PATH="$darwin_home/bin:/usr/bin:/bin" RAVY_NUSHELL_OS=Darwin "$bash_bin" "$harness_script" 2>&1)
darwin_status=$?
set -e
assert_status_zero "$darwin_status" 'nushell harness failed for Darwin' "$darwin_output"

assert_exists "$native_dir/env.nu"
assert_exists "$native_dir/config.nu"
assert_exists "$native_dir/login.nu"
assert_file_contains "$native_dir/env.nu" 'source-env ($ravy_canonical | path join "env.nu")'
assert_file_contains "$native_dir/config.nu" 'source ($ravy_canonical | path join "config.nu")'
assert_file_contains "$native_dir/login.nu" 'source ($ravy_canonical | path join "login.nu")'
assert_symlink_target "$native_history" "$canonical_history"
assert_file_contains "$canonical_history" 'canonical-entry'
assert_file_contains "$canonical_history" 'native-entry'

set +e
darwin_output_2=$(env -i HOME="$darwin_home" PATH="$darwin_home/bin:/usr/bin:/bin" RAVY_NUSHELL_OS=Darwin "$bash_bin" "$harness_script" 2>&1)
darwin_status_2=$?
set -e
assert_status_zero "$darwin_status_2" 'nushell harness should be idempotent' "$darwin_output_2"

if [ "$(grep -c '^native-entry$' "$canonical_history")" -ne 1 ]; then
  fail "native history entry should only appear once after rerun"
fi

if [ "$(grep -c '^canonical-entry$' "$canonical_history")" -ne 1 ]; then
  fail "canonical history entry should only appear once after rerun"
fi

set +e
probe_output=$(env -i HOME="$darwin_home" PATH="$darwin_home/bin:/usr/bin:/bin" "$nu_bin" --env-config "$native_dir/env.nu" --config "$native_dir/config.nu" -c '{ env: ($env.__RAVY_CANONICAL_ENV? | default null), config: ($env.__RAVY_CANONICAL_CONFIG? | default null) } | to json -r' 2>&1)
probe_status=$?
set -e
assert_status_zero "$probe_status" 'macOS Nushell shim should load canonical env/config' "$probe_output"
case "$probe_output" in
  *'"env":"1"'*'"config":"1"'*) ;;
  *)
    fail "unexpected macOS Nushell probe output: $probe_output"
    ;;
esac

login_code=$(cat <<EOF
source '$native_dir/login.nu'
{ login: (\$env.__RAVY_LOGIN_INIT? | default null) } | to json -r
EOF
)

set +e
login_output=$(env -i HOME="$darwin_home" PATH="$darwin_home/bin:/usr/bin:/bin" "$nu_bin" --env-config "$native_dir/env.nu" --config "$native_dir/config.nu" -c "$login_code" 2>&1)
login_status=$?
set -e
assert_status_zero "$login_status" 'macOS Nushell shim should load canonical login config' "$login_output"
case "$login_output" in
  *'"login":"1"'*) ;;
  *)
    fail "unexpected macOS Nushell login output: $login_output"
    ;;
esac

set +e
linux_output=$(env -i HOME="$linux_home" PATH="$linux_home/bin:/usr/bin:/bin" RAVY_NUSHELL_OS=Linux "$bash_bin" "$harness_script" 2>&1)
linux_status=$?
set -e
assert_status_zero "$linux_status" 'nushell harness failed for Linux no-op path' "$linux_output"
assert_not_exists "$linux_home/Library/Application Support/nushell"

if [ "$failures" -eq 0 ]; then
  echo 'All Nushell harness tests passed'
fi

exit "$failures"
