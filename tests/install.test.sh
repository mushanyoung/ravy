#!/usr/bin/env bash
set -euo pipefail

script_path=$(realpath "${BASH_SOURCE[0]}")
repo_root=$(realpath "$(dirname "$script_path")/..")
# shellcheck source=tests/prefix_guard_common.sh
source "$repo_root/tests/prefix_guard_common.sh"
bash_bin=$(command -v bash)

failures=0
tmp_home=''
tmp_homes=()

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

  if ! grep -F -- "$expected" "$path" >/dev/null 2>&1; then
    fail "$path is missing: $expected"
  fi
}

assert_output_contains() {
  local output=$1
  local expected=$2
  local msg=$3

  if ! printf '%s' "$output" | grep -F "$expected" >/dev/null 2>&1; then
    fail "$msg"
  fi
}

setup_home() {
  tmp_home=$(mktemp -d "$repo_root/.tmp_install_home.XXXXXX")
  tmp_homes+=("$tmp_home")
  guard_assert_repo_tmp_root "$repo_root" "$tmp_home" || return 1
  guard_exec "$tmp_home" mkdir -p "$tmp_home/bin" "$tmp_home/etc" "$tmp_home/.ssh" "$tmp_home/.config/ravy" "$tmp_home/.config/chezmoi"
  guard_install_wrappers "$tmp_home" "$tmp_home/bin"
  guard_assert_path "$tmp_home" "$tmp_home/.config/chezmoi/chezmoi.toml" create || return 1
  printf '%s\n' '# default config' > "$tmp_home/.config/chezmoi/chezmoi.toml"
  guard_assert_path "$tmp_home" "$tmp_home/etc/shells" create || return 1
  printf '%s\n' '/bin/sh' '/bin/bash' > "$tmp_home/etc/shells"

  write_stub "$tmp_home/bin/uname" "#!/usr/bin/env sh
case \"\${1:-}\" in
  -s)
    printf '%s\n' 'Linux'
    ;;
  -m)
    printf '%s\n' 'x86_64'
    ;;
  *)
    printf '%s\n' 'Linux'
    ;;
esac
"

  write_stub "$tmp_home/bin/brew" "#!/usr/bin/env sh
printf '%s\n' \"unexpected brew args: \$*\" >> \"\$HOME/brew.log\"
exit 1
"

  write_stub "$tmp_home/bin/git" "#!/usr/bin/env sh
printf '%s\n' \"git \$*\" >> \"\$HOME/git.log\"
exit 0
"

  write_stub "$tmp_home/bin/id" "#!/usr/bin/env sh
case \"\${1:-}\" in
  -u)
    printf '%s\n' '1000'
    ;;
  -un)
    printf '%s\n' 'test-user'
    ;;
  *)
    printf '%s\n' 'uid=1000(test-user) gid=1000(test-user)'
    ;;
esac
"

  write_stub "$tmp_home/bin/getent" "#!/usr/bin/env sh
if [ \"\${1:-}\" = passwd ]; then
  printf '%s\n' \"\${2:-test-user}:x:1000:1000:Test User:\$HOME:/bin/bash\"
  exit 0
fi
exit 1
"

  write_stub "$tmp_home/bin/sudo" "#!/usr/bin/env sh
printf '%s\n' \"\$*\" >> \"\$HOME/sudo.log\"
exec \"\$@\"
"

  write_stub "$tmp_home/bin/chsh" "#!/usr/bin/env sh
printf '%s\n' \"\$*\" >> \"\$HOME/chsh.log\"
exit 0
"

  write_stub "$tmp_home/bin/apt-get" "#!/usr/bin/env sh
printf '%s\n' \"\$*\" >> \"\$HOME/apt-get.log\"
case \" \$* \" in
  *' install '*' software-properties-common '*)
    printf '%s\n' \
      '#!/usr/bin/env sh' \
      'printf '\\''%s\n'\\'' \"\$*\" >> \"\$HOME/add-apt-repository.log\"' \
      'exit 0' \
      > \"\$HOME/bin/add-apt-repository\"
    chmod +x \"\$HOME/bin/add-apt-repository\"
    ;;
esac
case \" \$* \" in
  *' install '*' fish '*)
    mkdir -p \"\$HOME/usr/bin\"
    printf '%s\n' '#!/usr/bin/env sh' 'exit 0' > \"\$HOME/usr/bin/fish\"
    chmod +x \"\$HOME/usr/bin/fish\"
    ln -sfn \"\$HOME/usr/bin/fish\" \"\$HOME/bin/fish\"
    ;;
esac
exit 0
"

  write_stub "$tmp_home/mise-template" "#!/usr/bin/env sh
log=\"\$HOME/mise.log\"

if [ \"\${1:-}\" = \"exec\" ]; then
  shift
  tools=''
  while [ \"\$#\" -gt 0 ]; do
    case \"\$1\" in
      --)
        shift
        break
        ;;
      *)
        tools=\"\${tools}\${tools:+ }\$1\"
        shift
        ;;
    esac
  done
  printf '%s\n' \"exec tools=\$tools command=\$*\" >> \"\$log\"
  exec \"\$@\"
fi

if [ \"\${1:-}\" = \"install\" ]; then
  shift
  cd_path=''
  if [ \"\${1:-}\" = \"-C\" ]; then
    cd_path=\"\$2\"
    shift 2
  fi
  printf '%s\n' \"install cd=\$cd_path tools=\$*\" >> \"\$log\"
  exit 0
fi

if [ \"\${1:-}\" = \"--version\" ]; then
  printf '%s\n' 'mise test'
  exit 0
fi

printf '%s\n' \"mise \$*\" >> \"\$log\"
exit 0
"

  write_stub "$tmp_home/bin/curl" "#!/usr/bin/env sh
case \"\$*\" in
  *https://mise.run*)
    printf '%s\n' \
      '#!/usr/bin/env sh' \
      'set -eu' \
      'mkdir -p \"\$HOME/.local/bin\"' \
      'cp \"\$HOME/mise-template\" \"\$HOME/.local/bin/mise\"' \
      'chmod +x \"\$HOME/.local/bin/mise\"'
    exit 0
    ;;
esac

printf '%s\n' \"unexpected curl args: \$*\" >&2
exit 1
"

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
  if [ \"\$source_path\" = \"$repo_root\" ]; then
    mkdir -p \"$tmp_home/.config/mise/conf.d\"
    printf '%s\n' \
      '[tools]' \
      'chezmoi = \"latest\"' \
      'age = \"latest\"' \
      > \"$tmp_home/.config/mise/config.toml\"
    printf '%s\n' \
      '[tools]' \
      'node = \"26\"' \
      '\"npm:pyright\" = \"latest\"' \
      > \"$tmp_home/.config/mise/conf.d/99-custom.toml\"
  fi
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
  local install_path

  install_path="${RAVY_TEST_PATH:-$tmp_home/bin:/usr/bin:/bin}"
  set +e
  output=$(env -i \
    HOME="$tmp_home" \
    PATH="$install_path" \
    RAVY_PRIVATE_HOME="$tmp_home/private" \
    RAVY_GIT_BIN="${RAVY_GIT_BIN:-}" \
    RAVY_APT_GET="${RAVY_APT_GET:-}" \
    RAVY_ETC_SHELLS="$tmp_home/etc/shells" \
    RAVY_CHSH_USER="test-user" \
    RAVY_SKIP_CHSH="${RAVY_SKIP_CHSH:-}" \
    "$bash_bin" "$repo_root/install.sh" 2>&1)
  status_code=$?
  set -e

  printf '%s\n__RAVY_OUTPUT__\n%s\n__RAVY_END__' "$status_code" "$output"
}

setup_home
trap '
  for __ravy_tmp_home in "${tmp_homes[@]}"; do
    if [ -n "$__ravy_tmp_home" ] && [ -d "$__ravy_tmp_home" ]; then
      guard_exec "$__ravy_tmp_home" rm -rf "$__ravy_tmp_home"
    fi
  done
' EXIT

RAVY_GIT_BIN="$tmp_home/missing-git"
result=$(run_install)
unset RAVY_GIT_BIN
status_code=${result%%$'\n'*}
output=${result#*$'\n__RAVY_OUTPUT__\n'}
output=${output%$'\n__RAVY_END__'}
if [ "$status_code" -eq 0 ]; then
  fail "install.sh should fail when git is missing"
fi
assert_output_contains "$output" "git is required to install Ravy" "missing git should report a clear error"

setup_home

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
assert_file_contains "$tmp_home/mise.log" "exec tools=chezmoi@latest command=chezmoi --version"
assert_file_contains "$tmp_home/mise.log" "exec tools=age@latest command=age --version"
assert_file_contains "$tmp_home/mise.log" "exec tools=age@latest command=age --decrypt -o $tmp_home/.config/chezmoi/key.txt $tmp_home/private/bootstrap/key.txt.age"
assert_file_contains "$tmp_home/mise.log" "install cd=$tmp_home tools=node"
assert_file_contains "$tmp_home/mise.log" "install cd=$tmp_home tools="
if [ -e "$tmp_home/brew.log" ]; then
  fail "non-macOS install should not call brew"
fi
assert_file_contains "$tmp_home/apt-get.log" "update"
assert_file_contains "$tmp_home/apt-get.log" "install -y software-properties-common"
assert_file_contains "$tmp_home/add-apt-repository.log" "-y ppa:fish-shell/release-4"
assert_file_contains "$tmp_home/apt-get.log" "install -y fish"
assert_file_contains "$tmp_home/etc/shells" "$tmp_home/bin/fish"
assert_file_contains "$tmp_home/chsh.log" "-s $tmp_home/bin/fish test-user"

setup_home
guard_assert_path "$tmp_home" "$tmp_home/legacy-ssh.config" create
printf '%s\n' 'Host legacy' '    HostName legacy.example' > "$tmp_home/legacy-ssh.config"
guard_exec "$tmp_home" ln -s "$tmp_home/legacy-ssh.config" "$tmp_home/.ssh/config"

RAVY_APT_GET="$tmp_home/missing-apt-get"
result=$(run_install)
unset RAVY_APT_GET
status_code=${result%%$'\n'*}
output=${result#*$'\n__RAVY_OUTPUT__\n'}
output=${output%$'\n__RAVY_END__'}
assert_status_zero "$status_code" 'non-apt Linux install.sh failed' "$output"
if [ -e "$tmp_home/apt-get.log" ]; then
  fail "non-apt Linux install should not call apt-get"
fi
if [ -e "$tmp_home/chsh.log" ]; then
  fail "non-apt Linux install should not call chsh"
fi

setup_home
guard_assert_path "$tmp_home" "$tmp_home/legacy-ssh.config" create
printf '%s\n' 'Host legacy' '    HostName legacy.example' > "$tmp_home/legacy-ssh.config"
guard_exec "$tmp_home" ln -s "$tmp_home/legacy-ssh.config" "$tmp_home/.ssh/config"

RAVY_SKIP_CHSH=1
result=$(run_install)
unset RAVY_SKIP_CHSH
status_code=${result%%$'\n'*}
output=${result#*$'\n__RAVY_OUTPUT__\n'}
output=${output%$'\n__RAVY_END__'}
assert_status_zero "$status_code" 'apt-managed install.sh with RAVY_SKIP_CHSH failed' "$output"
assert_file_contains "$tmp_home/apt-get.log" "install -y fish"
if grep -F "$tmp_home/bin/fish" "$tmp_home/etc/shells" >/dev/null 2>&1; then
  fail "RAVY_SKIP_CHSH should not add fish to shells file"
fi
if [ -e "$tmp_home/chsh.log" ]; then
  fail "RAVY_SKIP_CHSH should not call chsh"
fi

setup_home
write_stub "$tmp_home/bin/uname" "#!/usr/bin/env sh
case \"\${1:-}\" in
  -s)
    printf '%s\n' 'Darwin'
    ;;
  -m)
    printf '%s\n' 'arm64'
    ;;
  *)
    printf '%s\n' 'Darwin'
    ;;
esac
"
write_stub "$tmp_home/bin/brew" "#!/usr/bin/env sh
if [ \"\${1:-}\" = --prefix ] && [ \"\${2:-}\" = fish ]; then
  printf '%s\n' \"\$HOME/non-default-homebrew/opt/fish\"
  exit 0
fi
case \"\${1:-}\" in
  --prefix)
    printf '%s\n' \"\$HOME/non-default-homebrew\"
    exit 0
    ;;
  bundle)
    mkdir -p \"\$HOME/non-default-homebrew/opt/fish/bin\"
    printf '%s\n' '#!/usr/bin/env sh' 'exit 0' > \"\$HOME/non-default-homebrew/opt/fish/bin/fish\"
    chmod +x \"\$HOME/non-default-homebrew/opt/fish/bin/fish\"
    printf '%s\n' \"bundle file=\$HOMEBREW_BUNDLE_FILE\" >> \"\$HOME/brew.log\"
    exit 0
    ;;
esac

printf '%s\n' \"unexpected brew args: \$*\" >> \"\$HOME/brew.log\"
exit 1
"
guard_assert_path "$tmp_home" "$tmp_home/legacy-ssh.config" create
printf '%s\n' 'Host legacy' '    HostName legacy.example' > "$tmp_home/legacy-ssh.config"
guard_exec "$tmp_home" ln -s "$tmp_home/legacy-ssh.config" "$tmp_home/.ssh/config"

result=$(run_install)
status_code=${result%%$'\n'*}
output=${result#*$'\n__RAVY_OUTPUT__\n'}
output=${output%$'\n__RAVY_END__'}
assert_status_zero "$status_code" 'macOS install.sh failed' "$output"
assert_file_contains "$tmp_home/brew.log" "bundle file=$repo_root/Brewfile"
assert_file_contains "$tmp_home/etc/shells" "$tmp_home/non-default-homebrew/opt/fish/bin/fish"
assert_file_contains "$tmp_home/chsh.log" "-s $tmp_home/non-default-homebrew/opt/fish/bin/fish test-user"
assert_output_contains "$output" "Continuing with existing Homebrew." "macOS non-default Homebrew prefix should warn and continue"
assert_output_contains "$output" "HOMEBREW_BUNDLE_FILE=$repo_root/Brewfile" "macOS install should report HOMEBREW_BUNDLE_FILE"

if [ "$failures" -eq 0 ]; then
  echo 'All install tests passed'
fi

exit "$failures"
