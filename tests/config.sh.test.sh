#!/usr/bin/env bash
set -euo pipefail

script_path=$(realpath "${BASH_SOURCE[0]}")
repo_root=$(realpath "$(dirname "$script_path")/..")
real_chezmoi=$(command -v chezmoi)
bash_bin=$(command -v bash)
zsh_bin=$(command -v zsh)

failures=0
bash_home=''
zsh_home=''

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

assert_status_nonzero() {
  local status=$1
  local msg=$2
  local output=${3:-}
  if [ "$status" -eq 0 ]; then
    fail "$msg${output:+: $output}"
  fi
}

assert_empty() {
  local actual=$1
  local msg=$2
  if [ -n "$actual" ]; then
    fail "$msg: $actual"
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

strip_bash_noise() {
  printf '%s' "$1" | awk '!/no job control in this shell$/ && !/cannot set terminal process group/ && !/Inappropriate ioctl for device/'
}

write_stub() {
  local target=$1
  local body=$2
  printf '%s' "$body" > "$target"
  chmod +x "$target"
}

mise_stub_body() {
  cat <<'EOF'
#!/usr/bin/env sh
if [ "$1" = "activate" ]; then
  cat <<'EOT'
export __RAVY_MISE_INIT=1
EOT
  exit 0
fi
printf '%s\n' "$*" >> "$HOME/mise.log"
exit 0
EOF
}

setup_home() {
  local tmp_home
  tmp_home=$(mktemp -d "$repo_root/.tmp_shell_home.XXXXXX")
  mkdir -p "$tmp_home/bin" "$tmp_home/.config/fish" "$tmp_home/.config/ravy" "$tmp_home/.config/chezmoi" "$tmp_home/.local/bin"
  printf '%s\n' 'seed = 1' > "$tmp_home/.config/chezmoi/chezmoi.toml"
  printf '%s\n' "$tmp_home"
}

render_config() {
  local tmp_home=$1
  local target=$2
  mkdir -p "$(dirname "$target")"
  "$real_chezmoi" -S "$repo_root" -D "$tmp_home" cat "$target" > "$target"
}

setup_base_stubs() {
  local stub_bin=$1
write_stub "$stub_bin/chezmoi" "#!/usr/bin/env sh
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
    source-path|init|cat|apply)
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
  printf '%s\\n' \"subcommand=source-path source=\$source_path config=\$config_path state=\$state_path\" >> \"\$HOME/chezmoi.log\"
  echo \"\$source_path\"
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
  printf '%s\\n' \"subcommand=init source=\$source_path config=\$config_path state=\$state_path config_path=\$init_config_path\" >> \"\$HOME/chezmoi.log\"
  exit 0
fi
exit 0
"
}

setup_tool_stubs() {
  local stub_bin=$1

  write_stub "$stub_bin/starship" "#!/usr/bin/env sh
if [ \"\$1\" = \"init\" ]; then
  cat <<'EOF'
__ravy_starship_init() {
  :
}
EOF
  exit 0
fi
exit 0
"

  write_stub "$stub_bin/zoxide" "#!/usr/bin/env sh
if [ \"\$1\" = \"init\" ]; then
  cat <<'EOF'
__ravy_zoxide_init() {
  :
}
EOF
  exit 0
fi
exit 0
"

  write_stub "$stub_bin/atuin" "#!/usr/bin/env sh
if [ \"\$1\" = \"init\" ]; then
  cat <<'EOF'
__ravy_atuin_init() {
  :
}
EOF
  exit 0
fi
exit 0
"

  write_stub "$stub_bin/brew" "#!/usr/bin/env sh
case \"\$1:\$2\" in
  --cellar:mise)
    printf '%s\n' \"\$HOME/homebrew/Cellar/mise\"
    exit 0
    ;;
  --prefix:mise)
    printf '%s\n' \"\$HOME/homebrew/opt/mise\"
    exit 0
    ;;
  upgrade:mise)
    printf '%s\n' \"\$*\" >> \"\$HOME/brew.log\"
    exit 0
    ;;
esac
exit 1
"

  write_stub "$stub_bin/dpkg-query" "#!/usr/bin/env sh
if [ \"\$1\" = \"-S\" ] && [ \"\${RAVY_MISE_OWNER:-}\" = apt ] && [ \"\$2\" = \"\$HOME/usr/bin/mise\" ]; then
  printf 'mise: %s\n' \"\$2\"
  exit 0
fi
exit 1
"

  write_stub "$stub_bin/rpm" "#!/usr/bin/env sh
if [ \"\$1\" = \"-qf\" ] && [ \"\${RAVY_MISE_OWNER:-}\" = dnf ] && [ \"\$2\" = \"\$HOME/usr/bin/mise\" ]; then
  printf '%s\n' 'mise-1.0-1'
  exit 0
fi
exit 1
"

  write_stub "$stub_bin/dnf" "#!/usr/bin/env sh
printf '%s\n' \"\$*\" >> \"\$HOME/dnf.log\"
exit 0
"

  write_stub "$stub_bin/pacman" "#!/usr/bin/env sh
if [ \"\$1\" = \"-Qo\" ] && [ \"\${RAVY_MISE_OWNER:-}\" = pacman ] && [ \"\$2\" = \"\$HOME/usr/bin/mise\" ]; then
  printf '%s is owned by mise 1.0-1\n' \"\$2\"
  exit 0
fi
if [ \"\$1\" = \"-Qo\" ]; then
  exit 1
fi
printf '%s\n' \"\$*\" >> \"\$HOME/pacman.log\"
exit 0
"

  write_stub "$stub_bin/apk" "#!/usr/bin/env sh
if [ \"\$1\" = info ] && [ \"\$2\" = --who-owns ] && [ \"\${RAVY_MISE_OWNER:-}\" = apk ] && [ \"\$3\" = \"\$HOME/usr/bin/mise\" ]; then
  printf '%s is owned by mise-1.0-r0\n' \"\$3\"
  exit 0
fi
if [ \"\$1\" = info ] && [ \"\$2\" = --who-owns ]; then
  exit 1
fi
printf '%s\n' \"\$*\" >> \"\$HOME/apk.log\"
exit 0
"

  write_stub "$stub_bin/apt" "#!/usr/bin/env sh
printf '%s\n' \"\$*\" >> \"\$HOME/apt.log\"
exit 0
"

  write_stub "$stub_bin/sudo" "#!/usr/bin/env sh
printf '%s\n' \"\$*\" >> \"\$HOME/sudo.log\"
exec \"\$@\"
"
}

install_mise_stub() {
  local tmp_home=$1
  local layout=$2
  local target

  case "$layout" in
    self)
      target="$tmp_home/opt/mise/bin/mise"
      ;;
    brew)
      target="$tmp_home/homebrew/Cellar/mise/current/bin/mise"
      ;;
    system)
      target="$tmp_home/usr/bin/mise"
      ;;
    *)
      fail "unknown mise stub layout: $layout"
      return 1
      ;;
  esac

  mkdir -p "$(dirname "$target")" "$tmp_home/bin"
  write_stub "$target" "$(mise_stub_body)"
  ln -sfn "$target" "$tmp_home/bin/mise"
}

setup_private_overlay() {
  local tmp_home=$1
  local private_home="$tmp_home/.local/share/ravy-private"

  mkdir -p \
    "$private_home/shell" \
    "$private_home/bin/common" \
    "$tmp_home/.config/ravy"

  printf '%s\n' 'export __RAVY_PRIVATE_COMMON=1' > "$private_home/shell/config.sh"
  printf '%s\n' 'export __RAVY_SECRETS_SH=1' > "$tmp_home/.config/ravy/secrets.sh"

  write_stub "$private_home/bin/common/private-helper" "#!/usr/bin/env sh
exit 0
"

  printf '%s\n' "$private_home"
}

run_shell() {
  local shell_name=$1
  local tmp_home=$2
  local stub_bin=$3
  local private_home=$4
  local command=$5
  local output
  local status_code

  if [ "$shell_name" = bash ]; then
    set +e
    output=$(env -i \
      HOME="$tmp_home" \
      PATH="$stub_bin:/usr/bin:/bin" \
      RAVY_HOST="test-host" \
      RAVY_SKIP_BREW=1 \
      RAVY_PRIVATE_HOME="$private_home" \
      "$bash_bin" --noprofile --rcfile "$tmp_home/.bashrc" -ic "$command" 2>&1)
    status_code=$?
    set -e
  else
    set +e
    output=$(env -i \
      HOME="$tmp_home" \
      ZDOTDIR="$tmp_home" \
      PATH="$stub_bin:/usr/bin:/bin" \
      RAVY_HOST="test-host" \
      RAVY_SKIP_BREW=1 \
      RAVY_PRIVATE_HOME="$private_home" \
      "$zsh_bin" -f -ic "source ~/.zshrc >/dev/null 2>&1; $command" 2>&1)
    status_code=$?
    set -e
  fi

  printf '%s\n__RAVY_OUTPUT__\n%s\n__RAVY_END__' "$status_code" "$output"
}

run_bash_login() {
  local tmp_home=$1
  local stub_bin=$2
  local private_home=$3
  local command=$4
  local output
  local status_code

  set +e
  output=$(env -i \
    HOME="$tmp_home" \
    PATH="$stub_bin:/usr/bin:/bin" \
    RAVY_HOME="$repo_root" \
    RAVY_HOST="test-host" \
    RAVY_SKIP_BREW=1 \
    RAVY_PRIVATE_HOME="$private_home" \
    "$bash_bin" --login -i -c "$command" 2>&1)
  status_code=$?
  set -e

  printf '%s\n__RAVY_OUTPUT__\n%s\n__RAVY_END__' "$status_code" "$output"
}

extract_result() {
  local result=$1
  local output
  local status_code=${result%%$'\n'*}
  output=${result#*$'\n__RAVY_OUTPUT__\n'}
  output=${output%$'\n__RAVY_END__'}
  printf '%s\n__RAVY_OUTPUT__\n%s' "$status_code" "$output"
}

check_clean_start() {
  local shell_name=$1
  local tmp_home=$2
  local stub_bin=$3
  local private_home=$4
  local result
  result=$(run_shell "$shell_name" "$tmp_home" "$stub_bin" "$private_home" 'true >/dev/null')
  local status_code=${result%%$'\n'*}
  local output=${result#*$'\n__RAVY_OUTPUT__\n'}
  output=${output%$'\n__RAVY_END__'}
  if [ "$shell_name" = bash ]; then
    output=$(strip_bash_noise "$output")
  fi
  assert_status_zero "$status_code" "$shell_name startup failed" "$output"
  assert_empty "$output" "$shell_name startup emitted stderr"
}

check_public_surface() {
  local shell_name=$1
  local tmp_home=$2
  local stub_bin=$3
  local fn_check

  if [ "$shell_name" = bash ]; then
    fn_check='declare -F'
  else
    fn_check='typeset -f'
  fi

  local command="
    test \"\$RAVY_HOME\" = \"$repo_root\" &&
    test -z \"\${RAVY_PRIVATE_HOME:-}\" &&
    case \":\$PATH:\" in *\":$repo_root/bin:\"*) ;; *) exit 1 ;; esac &&
    case \":\$PATH:\" in *\":$tmp_home/.local/bin:\"*) ;; *) exit 1 ;; esac &&
    $fn_check d >/dev/null &&
    $fn_check ravy >/dev/null &&
    $fn_check ravycustom >/dev/null &&
    $fn_check ravyprivatecd >/dev/null &&
    $fn_check chezp >/dev/null &&
    $fn_check ravysource >/dev/null &&
    type chez >/dev/null 2>&1 &&
    type ravyc >/dev/null 2>&1 &&
    type ravys >/dev/null 2>&1 &&
    alias mu 2>/dev/null | grep -F 'mise upgrade' >/dev/null 2>&1 &&
    command -v mumu >/dev/null 2>&1 &&
    alias rgh 2>/dev/null | grep -F 'rg -S --hidden' >/dev/null 2>&1 &&
    ( if command -v brew >/dev/null 2>&1; then type bi >/dev/null 2>&1; else ! type bi >/dev/null 2>&1; fi ) &&
    ( if command -v apt >/dev/null 2>&1; then type au >/dev/null 2>&1; else ! type au >/dev/null 2>&1; fi ) &&
    ( if command -v pacman >/dev/null 2>&1; then type pupu >/dev/null 2>&1; else ! type pupu >/dev/null 2>&1; fi ) &&
    command -v ep >/dev/null 2>&1 &&
    command -v jl >/dev/null 2>&1 &&
    command -v lines >/dev/null 2>&1 &&
    command -v downcase-exts >/dev/null 2>&1 &&
    $fn_check __ravy_starship_init >/dev/null &&
    $fn_check __ravy_zoxide_init >/dev/null &&
    $fn_check __ravy_atuin_init >/dev/null &&
    test \"\${__RAVY_MISE_INIT:-}\" = 1 &&
    rm -f \"\$HOME/chezmoi.log\" &&
    cd \"\$HOME\" &&
    ravy && test \"\$PWD\" = \"$repo_root\" &&
    test \"\$(chez source-path)\" = \"$repo_root\" &&
    chez init >/dev/null 2>&1 &&
    ! ravycustom >/dev/null 2>&1 &&
    ! chezp source-path >/dev/null 2>&1 &&
    test ! -f \"\$HOME/.config/chezmoi/ravy-public.toml\" &&
    grep -F 'subcommand=source-path source=$repo_root config= state=' \"\$HOME/chezmoi.log\" >/dev/null 2>&1 &&
    grep -F 'subcommand=init source=$repo_root config= state= config_path=' \"\$HOME/chezmoi.log\" >/dev/null 2>&1
  "

  local result
  result=$(run_shell "$shell_name" "$tmp_home" "$stub_bin" "$tmp_home/.missing-private" "$command")
  local status_code=${result%%$'\n'*}
  local output=${result#*$'\n__RAVY_OUTPUT__\n'}
  output=${output%$'\n__RAVY_END__'}
  if [ "$shell_name" = bash ]; then
    output=$(strip_bash_noise "$output")
  fi
  assert_status_zero "$status_code" "$shell_name public surface check failed" "$output"
}

check_mise_upgrade_helpers() {
  local shell_name=$1
  local tmp_home=$2
  local stub_bin=$3
  local result
  local status_code
  local output

  install_mise_stub "$tmp_home" self
  result=$(run_shell "$shell_name" "$tmp_home" "$stub_bin" "$tmp_home/.missing-private" '
    rm -f "$HOME/mise.log" &&
    eval mu &&
    grep -F "upgrade" "$HOME/mise.log" >/dev/null 2>&1
  ')
  status_code=${result%%$'\n'*}
  output=${result#*$'\n__RAVY_OUTPUT__\n'}
  output=${output%$'\n__RAVY_END__'}
  if [ "$shell_name" = bash ]; then
    output=$(strip_bash_noise "$output")
  fi
  assert_status_zero "$status_code" "$shell_name mu upgrade path failed" "$output"

  result=$(run_shell "$shell_name" "$tmp_home" "$stub_bin" "$tmp_home/.missing-private" '
    rm -f "$HOME/mise.log" "$HOME/apt.log" "$HOME/sudo.log" "$HOME/brew.log" "$HOME/dnf.log" "$HOME/pacman.log" "$HOME/apk.log" &&
    rm -rf "$HOME/opt/mise/lib" "$HOME/usr/lib" "$HOME/homebrew/Cellar/mise/current/lib" &&
    unset RAVY_MISE_OWNER MISE_SELF_UPDATE_AVAILABLE MISE_SELF_UPDATE_INSTRUCTIONS &&
    mumu &&
    grep -F "self-update" "$HOME/mise.log" >/dev/null 2>&1 &&
    grep -F "upgrade" "$HOME/mise.log" >/dev/null 2>&1 &&
    test ! -e "$HOME/apt.log" &&
    test ! -e "$HOME/sudo.log" &&
    test ! -e "$HOME/brew.log" &&
    test ! -e "$HOME/dnf.log" &&
    test ! -e "$HOME/pacman.log" &&
    test ! -e "$HOME/apk.log"
  ')
  status_code=${result%%$'\n'*}
  output=${result#*$'\n__RAVY_OUTPUT__\n'}
  output=${output%$'\n__RAVY_END__'}
  if [ "$shell_name" = bash ]; then
    output=$(strip_bash_noise "$output")
  fi
  assert_status_zero "$status_code" "$shell_name mumu self-update path failed" "$output"

  install_mise_stub "$tmp_home" brew
  result=$(run_shell "$shell_name" "$tmp_home" "$stub_bin" "$tmp_home/.missing-private" '
    rm -f "$HOME/mise.log" "$HOME/apt.log" "$HOME/sudo.log" "$HOME/brew.log" "$HOME/dnf.log" "$HOME/pacman.log" "$HOME/apk.log" &&
    rm -rf "$HOME/homebrew/Cellar/mise/current/lib" &&
    mkdir -p "$HOME/homebrew/Cellar/mise/current/lib" &&
    : > "$HOME/homebrew/Cellar/mise/current/lib/.disable-self-update" &&
    mumu &&
    grep -F "upgrade mise" "$HOME/brew.log" >/dev/null 2>&1 &&
    grep -F "upgrade" "$HOME/mise.log" >/dev/null 2>&1 &&
    ! grep -F "self-update" "$HOME/mise.log" >/dev/null 2>&1 &&
    test ! -e "$HOME/apt.log" &&
    test ! -e "$HOME/sudo.log" &&
    test ! -e "$HOME/dnf.log" &&
    test ! -e "$HOME/pacman.log" &&
    test ! -e "$HOME/apk.log"
  ')
  status_code=${result%%$'\n'*}
  output=${result#*$'\n__RAVY_OUTPUT__\n'}
  output=${output%$'\n__RAVY_END__'}
  if [ "$shell_name" = bash ]; then
    output=$(strip_bash_noise "$output")
  fi
  assert_status_zero "$status_code" "$shell_name mumu brew-managed path failed" "$output"

  install_mise_stub "$tmp_home" system
  result=$(run_shell "$shell_name" "$tmp_home" "$stub_bin" "$tmp_home/.missing-private" '
    rm -f "$HOME/mise.log" "$HOME/apt.log" "$HOME/sudo.log" "$HOME/brew.log" "$HOME/dnf.log" "$HOME/pacman.log" "$HOME/apk.log" &&
    rm -rf "$HOME/usr/lib" &&
    mkdir -p "$HOME/usr/lib" &&
    : > "$HOME/usr/lib/.disable-self-update" &&
    export RAVY_MISE_OWNER=apt &&
    mumu &&
    unset RAVY_MISE_OWNER &&
    grep -F "apt update" "$HOME/sudo.log" >/dev/null 2>&1 &&
    grep -F "apt install --only-upgrade mise" "$HOME/sudo.log" >/dev/null 2>&1 &&
    grep -F "update" "$HOME/apt.log" >/dev/null 2>&1 &&
    grep -F "install --only-upgrade mise" "$HOME/apt.log" >/dev/null 2>&1 &&
    grep -F "upgrade" "$HOME/mise.log" >/dev/null 2>&1 &&
    ! grep -F "self-update" "$HOME/mise.log" >/dev/null 2>&1 &&
    test ! -e "$HOME/brew.log" &&
    test ! -e "$HOME/dnf.log" &&
    test ! -e "$HOME/pacman.log" &&
    test ! -e "$HOME/apk.log"
  ')
  status_code=${result%%$'\n'*}
  output=${result#*$'\n__RAVY_OUTPUT__\n'}
  output=${output%$'\n__RAVY_END__'}
  if [ "$shell_name" = bash ]; then
    output=$(strip_bash_noise "$output")
  fi
  assert_status_zero "$status_code" "$shell_name mumu apt-managed path failed" "$output"

  install_mise_stub "$tmp_home" system
  result=$(run_shell "$shell_name" "$tmp_home" "$stub_bin" "$tmp_home/.missing-private" '
    rm -f "$HOME/mise.log" "$HOME/apt.log" "$HOME/sudo.log" "$HOME/brew.log" "$HOME/dnf.log" "$HOME/pacman.log" "$HOME/apk.log" &&
    rm -rf "$HOME/usr/lib" &&
    mkdir -p "$HOME/usr/lib" &&
    : > "$HOME/usr/lib/.disable-self-update" &&
    export RAVY_MISE_OWNER=dnf &&
    mumu &&
    unset RAVY_MISE_OWNER &&
    grep -F "dnf upgrade mise" "$HOME/sudo.log" >/dev/null 2>&1 &&
    grep -F "upgrade mise" "$HOME/dnf.log" >/dev/null 2>&1 &&
    grep -F "upgrade" "$HOME/mise.log" >/dev/null 2>&1 &&
    ! grep -F "self-update" "$HOME/mise.log" >/dev/null 2>&1 &&
    test ! -e "$HOME/brew.log" &&
    test ! -e "$HOME/apt.log" &&
    test ! -e "$HOME/pacman.log" &&
    test ! -e "$HOME/apk.log"
  ')
  status_code=${result%%$'\n'*}
  output=${result#*$'\n__RAVY_OUTPUT__\n'}
  output=${output%$'\n__RAVY_END__'}
  if [ "$shell_name" = bash ]; then
    output=$(strip_bash_noise "$output")
  fi
  assert_status_zero "$status_code" "$shell_name mumu dnf-managed path failed" "$output"

  install_mise_stub "$tmp_home" system
  result=$(run_shell "$shell_name" "$tmp_home" "$stub_bin" "$tmp_home/.missing-private" '
    rm -f "$HOME/mise.log" "$HOME/apt.log" "$HOME/sudo.log" "$HOME/brew.log" "$HOME/dnf.log" "$HOME/pacman.log" "$HOME/apk.log" &&
    rm -rf "$HOME/usr/lib" &&
    mkdir -p "$HOME/usr/lib" &&
    : > "$HOME/usr/lib/.disable-self-update" &&
    export RAVY_MISE_OWNER=pacman &&
    mumu &&
    unset RAVY_MISE_OWNER &&
    grep -F "pacman -Syu mise" "$HOME/sudo.log" >/dev/null 2>&1 &&
    grep -F -- "-Syu mise" "$HOME/pacman.log" >/dev/null 2>&1 &&
    grep -F "upgrade" "$HOME/mise.log" >/dev/null 2>&1 &&
    ! grep -F "self-update" "$HOME/mise.log" >/dev/null 2>&1 &&
    test ! -e "$HOME/brew.log" &&
    test ! -e "$HOME/apt.log" &&
    test ! -e "$HOME/dnf.log" &&
    test ! -e "$HOME/apk.log"
  ')
  status_code=${result%%$'\n'*}
  output=${result#*$'\n__RAVY_OUTPUT__\n'}
  output=${output%$'\n__RAVY_END__'}
  if [ "$shell_name" = bash ]; then
    output=$(strip_bash_noise "$output")
  fi
  assert_status_zero "$status_code" "$shell_name mumu pacman-managed path failed" "$output"

  install_mise_stub "$tmp_home" system
  result=$(run_shell "$shell_name" "$tmp_home" "$stub_bin" "$tmp_home/.missing-private" '
    rm -f "$HOME/mise.log" "$HOME/apt.log" "$HOME/sudo.log" "$HOME/brew.log" "$HOME/dnf.log" "$HOME/pacman.log" "$HOME/apk.log" &&
    rm -rf "$HOME/usr/lib" &&
    mkdir -p "$HOME/usr/lib" &&
    : > "$HOME/usr/lib/.disable-self-update" &&
    export RAVY_MISE_OWNER=apk &&
    mumu &&
    unset RAVY_MISE_OWNER &&
    grep -F "apk update" "$HOME/sudo.log" >/dev/null 2>&1 &&
    grep -F "apk upgrade mise" "$HOME/sudo.log" >/dev/null 2>&1 &&
    grep -F "update" "$HOME/apk.log" >/dev/null 2>&1 &&
    grep -F "upgrade mise" "$HOME/apk.log" >/dev/null 2>&1 &&
    grep -F "upgrade" "$HOME/mise.log" >/dev/null 2>&1 &&
    ! grep -F "self-update" "$HOME/mise.log" >/dev/null 2>&1 &&
    test ! -e "$HOME/brew.log" &&
    test ! -e "$HOME/apt.log" &&
    test ! -e "$HOME/dnf.log" &&
    test ! -e "$HOME/pacman.log"
  ')
  status_code=${result%%$'\n'*}
  output=${result#*$'\n__RAVY_OUTPUT__\n'}
  output=${output%$'\n__RAVY_END__'}
  if [ "$shell_name" = bash ]; then
    output=$(strip_bash_noise "$output")
  fi
  assert_status_zero "$status_code" "$shell_name mumu apk-managed path failed" "$output"

  install_mise_stub "$tmp_home" system
  result=$(run_shell "$shell_name" "$tmp_home" "$stub_bin" "$tmp_home/.missing-private" '
    rm -f "$HOME/mise.log" "$HOME/apt.log" "$HOME/sudo.log" "$HOME/brew.log" "$HOME/dnf.log" "$HOME/pacman.log" "$HOME/apk.log" &&
    rm -rf "$HOME/usr/lib" &&
    mkdir -p "$HOME/usr/lib" &&
    cat > "$HOME/usr/lib/mise-self-update-instructions.toml" <<'\''EOF'\''
message = "Use your distro package manager\n\n  custom update mise\n"
EOF
    unset RAVY_MISE_OWNER &&
    mumu
    cmd_status=$?
    test "$cmd_status" -ne 0
    test ! -e "$HOME/mise.log"
    test ! -e "$HOME/apt.log"
    test ! -e "$HOME/sudo.log"
    test ! -e "$HOME/brew.log"
    test ! -e "$HOME/dnf.log"
    test ! -e "$HOME/pacman.log"
    test ! -e "$HOME/apk.log"
  ')
  status_code=${result%%$'\n'*}
  output=${result#*$'\n__RAVY_OUTPUT__\n'}
  output=${output%$'\n__RAVY_END__'}
  if [ "$shell_name" = bash ]; then
    output=$(strip_bash_noise "$output")
  fi
  assert_status_zero "$status_code" "$shell_name mumu instructions fallback should report packaged instructions" "$output"
  if ! printf '%s' "$output" | grep -F 'custom update mise' >/dev/null 2>&1; then
    fail "$shell_name mumu instructions fallback should print packaged instructions"
  fi

  install_mise_stub "$tmp_home" system
  result=$(run_shell "$shell_name" "$tmp_home" "$stub_bin" "$tmp_home/.missing-private" '
    rm -f "$HOME/mise.log" "$HOME/apt.log" "$HOME/sudo.log" "$HOME/brew.log" "$HOME/dnf.log" "$HOME/pacman.log" "$HOME/apk.log" &&
    rm -rf "$HOME/usr/lib" &&
    mkdir -p "$HOME/usr/lib" &&
    : > "$HOME/usr/lib/.disable-self-update" &&
    unset RAVY_MISE_OWNER &&
    mumu
    cmd_status=$?
    test "$cmd_status" -ne 0
    test ! -e "$HOME/mise.log"
    test ! -e "$HOME/apt.log"
    test ! -e "$HOME/sudo.log"
    test ! -e "$HOME/brew.log"
    test ! -e "$HOME/dnf.log"
    test ! -e "$HOME/pacman.log"
    test ! -e "$HOME/apk.log"
  ')
  status_code=${result%%$'\n'*}
  output=${result#*$'\n__RAVY_OUTPUT__\n'}
  output=${output%$'\n__RAVY_END__'}
  if [ "$shell_name" = bash ]; then
    output=$(strip_bash_noise "$output")
  fi
  assert_status_zero "$status_code" "$shell_name mumu generic fallback should report manual guidance" "$output"
  if ! printf '%s' "$output" | grep -F 'installed via a package manager' >/dev/null 2>&1; then
    fail "$shell_name mumu generic fallback should print manual guidance"
  fi
}

check_private_surface() {
  local shell_name=$1
  local tmp_home=$2
  local stub_bin=$3
  local private_home=$4
  local fn_check

  if [ "$shell_name" = bash ]; then
    fn_check='declare -F'
  else
    fn_check='typeset -f'
  fi

  local command="
    test \"\$RAVY_PRIVATE_HOME\" = \"$private_home\" &&
    test \"\$RAVY_CUSTOM\" = \"$private_home\" &&
    case \":\$PATH:\" in *\":$private_home/bin/common:\"*) ;; *) exit 1 ;; esac &&
    test \"\${__RAVY_PRIVATE_COMMON:-}\" = 1 &&
    test \"\${__RAVY_SECRETS_SH:-}\" = 1 &&
    command -v private-helper >/dev/null 2>&1 &&
    rm -f \"\$HOME/chezmoi.log\" &&
    test \"\$(chezp source-path)\" = \"$private_home\" &&
    test -f \"\$HOME/.config/chezmoi/ravy-private.toml\" &&
    grep -F 'seed = 1' \"\$HOME/.config/chezmoi/ravy-private.toml\" >/dev/null 2>&1 &&
    chezp init >/dev/null 2>&1 &&
    cd \"\$HOME\" &&
    ravycustom && test \"\$PWD\" = \"$private_home\" &&
    grep -F 'subcommand=source-path source=$private_home config=$tmp_home/.config/chezmoi/ravy-private.toml state=$tmp_home/.config/chezmoi/ravy-private-state.boltdb' \"\$HOME/chezmoi.log\" >/dev/null 2>&1 &&
    grep -F 'subcommand=init source=$private_home config=$tmp_home/.config/chezmoi/ravy-private.toml state=$tmp_home/.config/chezmoi/ravy-private-state.boltdb config_path=$tmp_home/.config/chezmoi/ravy-private.toml' \"\$HOME/chezmoi.log\" >/dev/null 2>&1
  "

  local result
  result=$(run_shell "$shell_name" "$tmp_home" "$stub_bin" "$private_home" "$command")
  local status_code=${result%%$'\n'*}
  local output=${result#*$'\n__RAVY_OUTPUT__\n'}
  output=${output%$'\n__RAVY_END__'}
  if [ "$shell_name" = bash ]; then
    output=$(strip_bash_noise "$output")
  fi
  assert_status_zero "$status_code" "$shell_name private surface check failed" "$output"
}

check_rendered_gitconfig() {
  local tmp_home=$1
  local rendered_gitconfig="$tmp_home/.gitconfig"
  render_config "$tmp_home" "$rendered_gitconfig"

  if ! grep -F 'path = ~/.config/ravy/private.gitconfig' "$rendered_gitconfig" >/dev/null 2>&1; then
    fail 'rendered gitconfig is missing private include shim'
  fi
}

bash_home=$(setup_home)
trap 'rm -rf "$bash_home" "$zsh_home"' EXIT
render_config "$bash_home" "$bash_home/.bashrc"
render_config "$bash_home" "$bash_home/.bash_profile"

# Prepend stub_bin to PATH so that system chezmoi is not invoked on macOS login
tmp_profile=$(mktemp)
echo "export PATH=\"$bash_home/bin:\$PATH\"" > "$tmp_profile"
cat "$bash_home/.bash_profile" >> "$tmp_profile"
mv "$tmp_profile" "$bash_home/.bash_profile"

setup_base_stubs "$bash_home/bin"
check_clean_start bash "$bash_home" "$bash_home/bin" "$bash_home/.missing-private"
setup_tool_stubs "$bash_home/bin"
install_mise_stub "$bash_home" self
check_public_surface bash "$bash_home" "$bash_home/bin"
check_mise_upgrade_helpers bash "$bash_home" "$bash_home/bin"
check_private_surface bash "$bash_home" "$bash_home/bin" "$(setup_private_overlay "$bash_home")"
check_rendered_gitconfig "$bash_home"

login_result=$(run_bash_login "$bash_home" "$bash_home/bin" "$bash_home/.missing-private" 'if ! type ravy >/dev/null 2>&1; then echo "ravy missing"; exit 1; fi; if ! command -v ep >/dev/null 2>&1; then echo "ep missing, PATH=$PATH"; exit 1; fi')
login_status=${login_result%%$'\n'*}
login_output=${login_result#*$'\n__RAVY_OUTPUT__\n'}
login_output=${login_output%$'\n__RAVY_END__'}
login_output=$(strip_bash_noise "$login_output")
assert_status_zero "$login_status" 'bash login startup failed' "$login_output"
assert_empty "$login_output" 'bash login startup emitted stderr'

zsh_home=$(setup_home)
render_config "$zsh_home" "$zsh_home/.zshrc"
setup_base_stubs "$zsh_home/bin"
check_clean_start zsh "$zsh_home" "$zsh_home/bin" "$zsh_home/.missing-private"
setup_tool_stubs "$zsh_home/bin"
install_mise_stub "$zsh_home" self
check_public_surface zsh "$zsh_home" "$zsh_home/bin"
check_mise_upgrade_helpers zsh "$zsh_home" "$zsh_home/bin"
check_private_surface zsh "$zsh_home" "$zsh_home/bin" "$(setup_private_overlay "$zsh_home")"
check_rendered_gitconfig "$zsh_home"

if [ "$failures" -eq 0 ]; then
  echo 'All sh shell config tests passed'
fi

exit "$failures"
