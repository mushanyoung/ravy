#!/usr/bin/env bash
set -euo pipefail

script_path=$(realpath "${BASH_SOURCE[0]}")
repo_root=$(realpath "$(dirname "$script_path")/..")
bash_bin=$(command -v bash)

failures=0
tmp_home=''

fail() {
  echo "FAIL $1" >&2
  failures=$((failures + 1))
}

write_stub() {
  local target=$1
  local body=$2
  printf '%s' "$body" > "$target"
  chmod +x "$target"
}

assert_status_zero() {
  local status=$1
  local msg=$2
  local output=${3:-}
  if [ "$status" -ne 0 ]; then
    fail "$msg${output:+: $output}"
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

assert_not_symlink() {
  local path=$1

  if [ -L "$path" ]; then
    fail "$path should not be a symlink"
  fi
}

assert_file_contains() {
  local path=$1
  local expected=$2

  if ! grep -F "$expected" "$path" >/dev/null 2>&1; then
    fail "$path is missing: $expected"
  fi
}

setup_home() {
  tmp_home=$(mktemp -d "$repo_root/.tmp_install_home.XXXXXX")
  mkdir -p "$tmp_home/bin" "$tmp_home/.ssh"

  write_stub "$tmp_home/bin/chezmoi" "#!/usr/bin/env sh
if [ \"\$1\" = \"source-path\" ]; then
  echo \"$repo_root\"
  exit 0
fi

if [ \"\$1\" = \"init\" ]; then
  exit 0
fi

exit 0
"
}

run_install() {
  local output
  local status_code

  set +e
  output=$(env -i \
    HOME="$tmp_home" \
    PATH="$tmp_home/bin:/usr/bin:/bin" \
    RAVY_BOOTSTRAP_OPTIONAL=0 \
    "$bash_bin" "$repo_root/install.sh" 2>&1)
  status_code=$?
  set -e

  printf '%s\n__RAVY_OUTPUT__\n%s\n__RAVY_END__' "$status_code" "$output"
}

setup_home
trap 'rm -rf "$tmp_home"' EXIT

printf '%s\n' 'Host legacy' '    HostName legacy.example' > "$tmp_home/legacy-ssh.config"
ln -s "$tmp_home/legacy-ssh.config" "$tmp_home/.ssh/config"

result=$(run_install)
status_code=${result%%$'\n'*}
output=${result#*$'\n__RAVY_OUTPUT__\n'}
output=${output%$'\n__RAVY_END__'}
assert_status_zero "$status_code" 'install.sh failed' "$output"

assert_symlink_target \
  "$tmp_home/.config/ravy/private.gitconfig" \
  "$repo_root/custom/git/private.gitconfig"
assert_symlink_target \
  "$tmp_home/.config/ravy/ssh.config" \
  "$repo_root/custom/ssh/config"
assert_not_symlink "$tmp_home/.ssh/config"
assert_file_contains "$tmp_home/.ssh/config" 'Host legacy'
assert_file_contains "$tmp_home/.ssh/config" "Include $tmp_home/.config/ravy/ssh.config"

if [ "$failures" -eq 0 ]; then
  echo 'All install tests passed'
fi

exit "$failures"
