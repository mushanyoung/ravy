#!/usr/bin/env bash
set -euo pipefail

script_path=$(realpath "${BASH_SOURCE[0]}")
repo_root=$(realpath "$(dirname "$script_path")/..")
# shellcheck source=tests/prefix_guard_common.sh
source "$repo_root/tests/prefix_guard_common.sh"
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
  guard_assert_repo_tmp_root "$repo_root" "$tmp_home" || return 1
  guard_exec "$tmp_home" mkdir -p "$tmp_home/bin" "$tmp_home/.ssh" "$tmp_home/.config/ravy" "$tmp_home/.config/chezmoi"
  guard_install_wrappers "$tmp_home" "$tmp_home/bin"
  guard_assert_path "$tmp_home" "$tmp_home/.config/chezmoi/chezmoi.toml" create || return 1
  printf '%s\n' '# default config' > "$tmp_home/.config/chezmoi/chezmoi.toml"

  write_stub "$tmp_home/bin/chezmoi" "#!/usr/bin/env sh
source_path=\"$repo_root\"
config_path=''
state_path=''
subcommand=''
while [ \"\$#\" -gt 0 ]; do
  case \"\$1\" in
    -S|--source)
      source_path=\"\$2\"
      shift 2
      ;;
    -c|--config)
      config_path=\"\$2\"
      shift 2
      ;;
    --persistent-state)
      state_path=\"\$2\"
      shift 2
      ;;
    source-path|init|apply)
      subcommand=\"\$1\"
      shift
      break
      ;;
    *)
      shift
      ;;
  esac
done
if [ \"\$subcommand\" = \"source-path\" ]; then
  echo \"$repo_root\"
  exit 0
fi

if [ \"\$subcommand\" = \"init\" ]; then
  init_config_path=''
  while [ \"\$#\" -gt 0 ]; do
    case \"\$1\" in
      -C|--config-path)
        init_config_path=\"\$2\"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done
  printf '%s\n' \"subcommand=init source=\$source_path config=\$config_path state=\$state_path config_path=\$init_config_path\" >> \"$tmp_home/chezmoi.log\"
  exit 0
fi

if [ \"\$subcommand\" = \"apply\" ]; then
  printf '%s\n' \"subcommand=apply source=\$source_path config=\$config_path state=\$state_path\" >> \"$tmp_home/chezmoi.log\"
  exit 0
fi

exit 0
"

  write_stub "$tmp_home/bin/age" "#!/usr/bin/env sh
output=''
while [ \"\$#\" -gt 0 ]; do
  case \"\$1\" in
    -o)
      output=\"\$2\"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
if [ -n \"\$output\" ]; then
  printf '%s\n' '# bootstrapped age identity' > \"\$output\"
fi
exit 0
"

  guard_assert_path "$tmp_home" "$tmp_home/.config/ravy/private.gitconfig" create || return 1
  printf '%s\n' '[user]' '    name = Test User' > "$tmp_home/.config/ravy/private.gitconfig"
  guard_assert_path "$tmp_home" "$tmp_home/.config/ravy/ssh.config" create || return 1
  printf '%s\n' 'Host private' '    HostName private.example' > "$tmp_home/.config/ravy/ssh.config"

  # Create a fake private repo for testing
  local fake_private="$tmp_home/private"
  guard_exec "$tmp_home" mkdir -p "$fake_private/.git" "$fake_private/bootstrap"
  guard_exec "$tmp_home" touch "$fake_private/bootstrap/key.txt.age"
  
  write_stub "$fake_private/install.sh" "#!/usr/bin/env bash
rm -f \"\$HOME/.ssh/config\"
cp \"\$HOME/legacy-ssh.config\" \"\$HOME/.ssh/config\"
echo \"Include \$HOME/.config/ravy/ssh.config\" >> \"\$HOME/.ssh/config\"
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
    RAVY_PRIVATE_HOME="$tmp_home/private" \
    "$bash_bin" "$repo_root/install.sh" 2>&1)
  status_code=$?
  set -e

  printf '%s\n__RAVY_OUTPUT__\n%s\n__RAVY_END__' "$status_code" "$output"
}

setup_home
trap '
  if [ -n "${tmp_home:-}" ] && [ -d "$tmp_home" ]; then
    guard_exec "$tmp_home" rm -rf "$tmp_home"
  fi
' EXIT

guard_assert_path "$tmp_home" "$tmp_home/legacy-ssh.config" create
printf '%s\n' 'Host legacy' '    HostName legacy.example' > "$tmp_home/legacy-ssh.config"
guard_exec "$tmp_home" ln -s "$tmp_home/legacy-ssh.config" "$tmp_home/.ssh/config"

result=$(run_install)
status_code=${result%%$'\n'*}
output=${result#*$'\n__RAVY_OUTPUT__\n'}
output=${output%$'\n__RAVY_END__'}
assert_status_zero "$status_code" 'install.sh failed' "$output"

assert_not_symlink "$tmp_home/.config/ravy/private.gitconfig"
assert_not_symlink "$tmp_home/.config/ravy/ssh.config"
assert_not_symlink "$tmp_home/.ssh/config"
assert_file_contains "$tmp_home/.config/chezmoi/key.txt" '# bootstrapped age identity'
assert_file_contains "$tmp_home/.config/chezmoi/ravy-private.toml" '# default config'
assert_file_contains "$tmp_home/.ssh/config" 'Host legacy'
assert_file_contains "$tmp_home/.ssh/config" "Include $tmp_home/.config/ravy/ssh.config"
assert_file_contains "$tmp_home/chezmoi.log" "subcommand=init source=$repo_root config= state= config_path="
assert_file_contains "$tmp_home/chezmoi.log" "subcommand=init source=$tmp_home/private config=$tmp_home/.config/chezmoi/ravy-private.toml state=$tmp_home/.config/chezmoi/ravy-private-state.boltdb config_path=$tmp_home/.config/chezmoi/ravy-private.toml"
assert_file_contains "$tmp_home/chezmoi.log" "subcommand=apply source=$tmp_home/private config=$tmp_home/.config/chezmoi/ravy-private.toml state=$tmp_home/.config/chezmoi/ravy-private-state.boltdb"

if [ "$failures" -eq 0 ]; then
  echo 'All install tests passed'
fi

exit "$failures"
