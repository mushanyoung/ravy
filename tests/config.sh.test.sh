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

assert_empty() {
  local actual=$1
  local msg=$2
  if [ -n "$actual" ]; then
    fail "$msg: $actual"
  fi
}

strip_bash_noise() {
  printf '%s' "$1" | awk '!/no job control in this shell$/'
}

write_stub() {
  local target=$1
  local body=$2
  printf '%s' "$body" > "$target"
  chmod +x "$target"
}

setup_home() {
  local tmp_home
  tmp_home=$(mktemp -d "$repo_root/.tmp_shell_home.XXXXXX")
  mkdir -p "$tmp_home/bin" "$tmp_home/.config/fish" "$tmp_home/.config/ravy" "$tmp_home/.local/bin"
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
if [ \"\$1\" = \"source-path\" ]; then
  echo \"$repo_root\"
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

  write_stub "$stub_bin/mise" "#!/usr/bin/env sh
if [ \"\$1\" = \"activate\" ]; then
  cat <<'EOF'
export __RAVY_MISE_INIT=1
EOF
  exit 0
fi
exit 0
"
}

setup_private_overlay() {
  local tmp_home=$1
  local private_home="$tmp_home/.local/share/ravy-private"

  mkdir -p \
    "$private_home/shell" \
    "$private_home/hosts/test-host/shell" \
    "$private_home/bin/common" \
    "$tmp_home/.config/ravy"

  printf '%s\n' 'export __RAVY_PRIVATE_COMMON=1' > "$private_home/shell/config.sh"
  printf '%s\n' 'export __RAVY_PRIVATE_HOST=1' > "$private_home/hosts/test-host/shell/config.sh"
  printf '%s\n' 'export __RAVY_LOCAL_SH=1' > "$tmp_home/.config/ravy/local.sh"

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
    $fn_check ravysource >/dev/null &&
    type ravyc >/dev/null 2>&1 &&
    type ravys >/dev/null 2>&1 &&
    ! type bi >/dev/null 2>&1 &&
    ! type au >/dev/null 2>&1 &&
    ! type pupu >/dev/null 2>&1 &&
    command -v ep >/dev/null 2>&1 &&
    command -v jl >/dev/null 2>&1 &&
    command -v lines >/dev/null 2>&1 &&
    command -v downcase-exts >/dev/null 2>&1 &&
    $fn_check __ravy_starship_init >/dev/null &&
    $fn_check __ravy_zoxide_init >/dev/null &&
    $fn_check __ravy_atuin_init >/dev/null &&
    test \"\${__RAVY_MISE_INIT:-}\" = 1 &&
    cd \"\$HOME\" &&
    ravy && test \"\$PWD\" = \"$repo_root\" &&
    ! ravycustom >/dev/null 2>&1
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
    test \"\${__RAVY_PRIVATE_HOST:-}\" = 1 &&
    test \"\${__RAVY_LOCAL_SH:-}\" = 1 &&
    command -v private-helper >/dev/null 2>&1 &&
    cd \"\$HOME\" &&
    ravycustom && test \"\$PWD\" = \"$private_home\"
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
setup_base_stubs "$bash_home/bin"
check_clean_start bash "$bash_home" "$bash_home/bin" "$bash_home/.missing-private"
setup_tool_stubs "$bash_home/bin"
check_public_surface bash "$bash_home" "$bash_home/bin"
check_private_surface bash "$bash_home" "$bash_home/bin" "$(setup_private_overlay "$bash_home")"
check_rendered_gitconfig "$bash_home"

login_result=$(run_bash_login "$bash_home" "$bash_home/bin" "$bash_home/.missing-private" 'type ravy >/dev/null 2>&1 && command -v ep >/dev/null 2>&1')
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
check_public_surface zsh "$zsh_home" "$zsh_home/bin"
check_private_surface zsh "$zsh_home" "$zsh_home/bin" "$(setup_private_overlay "$zsh_home")"
check_rendered_gitconfig "$zsh_home"

if [ "$failures" -eq 0 ]; then
  echo 'All sh shell config tests passed'
fi

exit "$failures"
