#!/usr/bin/env bash
set -euo pipefail

script_path=$(realpath "${BASH_SOURCE[0]}")
repo_root=$(realpath "$(dirname "$script_path")/..")
real_chezmoi=$(command -v chezmoi)
bash_bin=$(command -v bash)
zsh_bin=$(command -v zsh)

failures=0
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
  mkdir -p "$tmp_home/bin" "$tmp_home/.config/fish"
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

run_shell() {
  local shell_name=$1
  local tmp_home=$2
  local stub_bin=$3
  local command=$4
  local output
  local status

  if [ "$shell_name" = bash ]; then
    set +e
    output=$(env -i \
      HOME="$tmp_home" \
      PATH="$stub_bin:/usr/bin:/bin" \
      RAVY_SKIP_BREW=1 \
      RAVY_SKIP_CUSTOM=1 \
      "$bash_bin" --noprofile --rcfile "$tmp_home/.bashrc" -ic "$command" 2>&1)
    status=$?
    set -e
  else
    set +e
    output=$(env -i \
      HOME="$tmp_home" \
      ZDOTDIR="$tmp_home" \
      PATH="$stub_bin:/usr/bin:/bin" \
      RAVY_SKIP_BREW=1 \
      RAVY_SKIP_CUSTOM=1 \
      "$zsh_bin" -f -ic "source ~/.zshrc >/dev/null 2>&1; $command" 2>&1)
    status=$?
    set -e
  fi

  printf '%s\n__RAVY_OUTPUT__\n%s\n__RAVY_END__' "$status" "$output"
}

run_bash_login() {
  local tmp_home=$1
  local stub_bin=$2
  local command=$3
  local output
  local status

  set +e
  output=$(env -i \
    HOME="$tmp_home" \
    PATH="$stub_bin:/usr/bin:/bin" \
    RAVY_SKIP_BREW=1 \
    RAVY_SKIP_CUSTOM=1 \
    "$bash_bin" --login -i -c "$command" 2>&1)
  status=$?
  set -e

  printf '%s\n__RAVY_OUTPUT__\n%s\n__RAVY_END__' "$status" "$output"
}

check_shared_surface() {
  local shell_name=$1
  local tmp_home=$2
  local stub_bin=$3
  local repo_custom="$repo_root/custom"
  local fn_check

  if [ "$shell_name" = bash ]; then
    fn_check='declare -F'
  else
    fn_check='typeset -f'
  fi

  local command="
    test \"\$RAVY_HOME\" = \"$repo_root\" &&
    test \"\$RAVY_CUSTOM\" = \"$repo_custom\" &&
    case \":\$PATH:\" in *\":$repo_root/bin:\"*) ;; *) exit 1 ;; esac &&
    case \":\$PATH:\" in *\":$repo_custom/bin:\"*) ;; *) exit 1 ;; esac &&
    $fn_check d >/dev/null &&
    $fn_check ravy >/dev/null &&
    $fn_check ravycustom >/dev/null &&
    $fn_check ravysource >/dev/null &&
    $fn_check scd >/dev/null &&
    $fn_check scrall >/dev/null &&
    $fn_check drc >/dev/null &&
    $fn_check dri >/dev/null &&
    $fn_check reset >/dev/null &&
    type dpri >/dev/null 2>&1 &&
    type dprs >/dev/null 2>&1 &&
    type dli >/dev/null 2>&1 &&
    type dls >/dev/null 2>&1 &&
    type dry >/dev/null 2>&1 &&
    type ravyc >/dev/null 2>&1 &&
    type ravys >/dev/null 2>&1 &&
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
    ravycustom && test \"\$PWD\" = \"$repo_custom\"
  "

  local result
  result=$(run_shell "$shell_name" "$tmp_home" "$stub_bin" "$command")
  local status=${result%%$'\n'*}
  local output=${result#*$'\n__RAVY_OUTPUT__\n'}
  output=${output%$'\n__RAVY_END__'}
  if [ "$shell_name" = bash ]; then
    output=$(strip_bash_noise "$output")
  fi
  assert_status_zero "$status" "$shell_name shared surface check failed" "$output"
}

check_clean_start() {
  local shell_name=$1
  local tmp_home=$2
  local stub_bin=$3
  local result
  result=$(run_shell "$shell_name" "$tmp_home" "$stub_bin" 'true >/dev/null')
  local status=${result%%$'\n'*}
  local output=${result#*$'\n__RAVY_OUTPUT__\n'}
  output=${output%$'\n__RAVY_END__'}
  if [ "$shell_name" = bash ]; then
    output=$(strip_bash_noise "$output")
  fi
  assert_status_zero "$status" "$shell_name startup failed" "$output"
  assert_empty "$output" "$shell_name startup emitted stderr"
}

bash_home=$(setup_home)
trap 'rm -rf "$bash_home" "$zsh_home"' EXIT
render_config "$bash_home" "$bash_home/.bashrc"
render_config "$bash_home" "$bash_home/.bash_profile"
setup_base_stubs "$bash_home/bin"
check_clean_start bash "$bash_home" "$bash_home/bin"
setup_tool_stubs "$bash_home/bin"
check_shared_surface bash "$bash_home" "$bash_home/bin"

login_result=$(run_bash_login "$bash_home" "$bash_home/bin" 'type ravy >/dev/null 2>&1 && command -v ep >/dev/null 2>&1')
login_status=${login_result%%$'\n'*}
login_output=${login_result#*$'\n__RAVY_OUTPUT__\n'}
login_output=${login_output%$'\n__RAVY_END__'}
login_output=$(strip_bash_noise "$login_output")
assert_status_zero "$login_status" 'bash login startup failed' "$login_output"
assert_empty "$login_output" 'bash login startup emitted stderr'

zsh_home=$(setup_home)
render_config "$zsh_home" "$zsh_home/.zshrc"
setup_base_stubs "$zsh_home/bin"
check_clean_start zsh "$zsh_home" "$zsh_home/bin"
setup_tool_stubs "$zsh_home/bin"
check_shared_surface zsh "$zsh_home" "$zsh_home/bin"

if [ "$failures" -eq 0 ]; then
  echo 'All sh shell config tests passed'
fi

exit "$failures"
