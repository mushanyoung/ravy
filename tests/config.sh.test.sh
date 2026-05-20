#!/usr/bin/env bash
set -euo pipefail

script_path=$(realpath "${BASH_SOURCE[0]}")
repo_root=$(realpath "$(dirname "$script_path")/..")
# shellcheck source=tests/prefix_guard_common.sh
source "$repo_root/tests/prefix_guard_common.sh"
real_chezmoi=$(command -v chezmoi)
bash_bin=$(command -v bash)
zsh_bin=$(command -v zsh || true)

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
  guard_assert_repo_tmp_root "$repo_root" "$tmp_home" || return 1
  guard_exec "$tmp_home" mkdir -p "$tmp_home/bin" "$tmp_home/.config/fish" "$tmp_home/.config/ravy" "$tmp_home/.config/chezmoi" "$tmp_home/.local/bin"
  guard_assert_path "$tmp_home" "$tmp_home/.config/chezmoi/chezmoi.toml" create || return 1
  printf '%s\n' 'seed = 1' > "$tmp_home/.config/chezmoi/chezmoi.toml"
  printf '%s\n' "$tmp_home"
}

render_config() {
  local tmp_home=$1
  local target=$2
  guard_assert_path "$tmp_home" "$target" create || return 1
  guard_exec "$tmp_home" mkdir -p "$(dirname "$target")"
  "$real_chezmoi" -S "$repo_root" -D "$tmp_home" cat "$target" > "$target"
}

setup_base_stubs() {
  local stub_bin=$1
  local root

  root=$(dirname "$stub_bin")
  guard_install_wrappers "$root" "$stub_bin"
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
    source-path|init|cat|apply|diff|status)
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
if [ \"\$subcommand\" = \"apply\" ] || [ \"\$subcommand\" = \"diff\" ] || [ \"\$subcommand\" = \"status\" ]; then
  printf '%s\\n' \"subcommand=\$subcommand source=\$source_path config=\$config_path state=\$state_path\" >> \"\$HOME/chezmoi.log\"
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

  write_stub "$stub_bin/codex" "#!/usr/bin/env sh
printf '%s\n' \"\$*\" >> \"\$HOME/codex.log\"
exit 0
"

  write_stub "$stub_bin/pacman" "#!/usr/bin/env sh
printf '%s\n' \"\$*\" >> \"\$HOME/pacman.log\"
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
    *)
      fail "unknown mise stub layout: $layout"
      return 1
      ;;
  esac

  guard_exec "$tmp_home" mkdir -p "$(dirname "$target")" "$tmp_home/bin"
  write_stub "$target" "$(mise_stub_body)"
  guard_exec "$tmp_home" ln -sfn "$target" "$tmp_home/bin/mise"
}

setup_private_overlay() {
  local tmp_home=$1
  local private_home="$tmp_home/.local/share/ravy-private"

  guard_exec "$tmp_home" mkdir -p \
    "$private_home/shell" \
    "$private_home/bin/common" \
    "$private_home/ops" \
    "$tmp_home/.config/ravy"

  printf '%s\n' 'export __RAVY_PRIVATE_COMMON=1' > "$private_home/shell/config.sh"
  cat "$repo_root/tests/fixtures/private_secrets.sh" > "$tmp_home/.config/ravy/secrets.sh"
  printf '%s\t%s\n%s\t%s\n%s\t%s\n%s\t%s\n%s\t%s\n' \
    '__RAVY_SECRETS_SH' ' 1' \
    'RAVY_TSV_VALUE' ' value' \
    'RAVY_TSV_HOME_PATH' ' ~/example' \
    'RAVY_TSV_HOME_ROOT' ' ~' \
    'RAVY_TSV_HOME_OTHER' ' ~otheruser/example' \
    > "$tmp_home/.config/ravy/secrets.tsv"

  write_stub "$private_home/bin/common/private-helper" "#!/usr/bin/env sh
exit 0
"
  write_stub "$private_home/ops/private-op-helper" "#!/usr/bin/env sh
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
  local ssh_connection=${6:-}
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
      HOMEBREW_BUNDLE_FILE="$repo_root/Brewfile" \
      SSH_CONNECTION="$ssh_connection" \
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
      HOMEBREW_BUNDLE_FILE="$repo_root/Brewfile" \
      SSH_CONNECTION="$ssh_connection" \
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
    HOMEBREW_BUNDLE_FILE="$repo_root/Brewfile" \
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
    test \"\${HOMEBREW_BUNDLE_FILE:-}\" = \"$tmp_home/.config/homebrew/Brewfile\" &&
    test -z \"\${RAVY_PRIVATE_HOME:-}\" &&
    case \":\$PATH:\" in *\":$repo_root/bin:\"*) ;; *) exit 1 ;; esac &&
    case \":\$PATH:\" in *\":$tmp_home/.local/bin:\"*) ;; *) exit 1 ;; esac &&
    $fn_check d >/dev/null &&
    $fn_check ravy >/dev/null &&
    $fn_check ravyprivate >/dev/null &&
    $fn_check ravyc >/dev/null &&
    $fn_check codex >/dev/null &&
    ! $fn_check ravycustom >/dev/null &&
    ! $fn_check ravyprivatecd >/dev/null &&
    $fn_check chezp >/dev/null &&
    $fn_check ravysource >/dev/null &&
    type chez >/dev/null 2>&1 &&
    type ravyprivate >/dev/null 2>&1 &&
    type ravyc >/dev/null 2>&1 &&
    type ravys >/dev/null 2>&1 &&
    command -v mu >/dev/null 2>&1 &&
    ! alias mu >/dev/null 2>&1 &&
    command -v auau >/dev/null 2>&1 &&
    ! alias auau >/dev/null 2>&1 &&
    alias rgh 2>/dev/null | grep -F 'rg -S --hidden' >/dev/null 2>&1 &&
    ( if command -v brew >/dev/null 2>&1; then type bi >/dev/null 2>&1; else ! type bi >/dev/null 2>&1; fi ) &&
    ( if command -v pacman >/dev/null 2>&1; then type pupu >/dev/null 2>&1; else ! type pupu >/dev/null 2>&1; fi ) &&
    command -v ep >/dev/null 2>&1 &&
    command -v jl >/dev/null 2>&1 &&
    command -v lines >/dev/null 2>&1 &&
    command -v downcase-exts >/dev/null 2>&1 &&
    rm -f \"\$HOME/codex.log\" &&
    unset ZELLIJ &&
    codex resume abc123 >/dev/null &&
    grep -Fx 'resume abc123' \"\$HOME/codex.log\" >/dev/null 2>&1 &&
    rm -f \"\$HOME/codex.log\" &&
    ZELLIJ=1 codex resume abc123 >/dev/null &&
    grep -Fx -- '--no-alt-screen resume abc123' \"\$HOME/codex.log\" >/dev/null 2>&1 &&
    unset ZELLIJ &&
    $fn_check __ravy_starship_init >/dev/null &&
    $fn_check __ravy_zoxide_init >/dev/null &&
    $fn_check __ravy_atuin_init >/dev/null &&
    test \"\${__RAVY_MISE_INIT:-}\" = 1 &&
    cd \"\$HOME\" &&
    ravy && test \"\$PWD\" = \"$repo_root\" &&
    rm -f \"\$HOME/chezmoi.log\" &&
    test \"\$(chez source-path)\" = \"$repo_root\" &&
    grep -F 'subcommand=source-path source=$repo_root config= state=' \"\$HOME/chezmoi.log\" >/dev/null 2>&1 &&
    rm -f \"\$HOME/chezmoi.log\" &&
    chez diff --exclude scripts >/dev/null 2>&1 &&
    grep -F 'subcommand=diff source=$repo_root config= state=' \"\$HOME/chezmoi.log\" >/dev/null 2>&1 &&
    test \"\$(grep -c '^subcommand=diff ' \"\$HOME/chezmoi.log\")\" -eq 1 &&
    rm -f \"\$HOME/chezmoi.log\" &&
    chez status --path-style absolute >/dev/null 2>&1 &&
    grep -F 'subcommand=status source=$repo_root config= state=' \"\$HOME/chezmoi.log\" >/dev/null 2>&1 &&
    test \"\$(grep -c '^subcommand=status ' \"\$HOME/chezmoi.log\")\" -eq 1 &&
    rm -f \"\$HOME/chezmoi.log\" &&
    chez apply >/dev/null 2>&1 &&
    grep -F 'subcommand=apply source=$repo_root config= state=' \"\$HOME/chezmoi.log\" >/dev/null 2>&1 &&
    test \"\$(grep -c '^subcommand=apply ' \"\$HOME/chezmoi.log\")\" -eq 1 &&
    rm -f \"\$HOME/chezmoi.log\" &&
    chez init >/dev/null 2>&1 &&
    ! ravyprivate >/dev/null 2>&1 &&
    ! ravyc >/dev/null 2>&1 &&
    ! chez private source-path >/dev/null 2>&1 &&
    ! chezp source-path >/dev/null 2>&1 &&
    test ! -f \"\$HOME/.config/chezmoi/ravy-public.toml\" &&
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

check_ssh_auth_sock_bridge() {
  local shell_name=$1
  local tmp_home=$2
  local stub_bin=$3
  local agent_cmd
  local agent_output
  local agent_sock
  local old_auth_sock=''
  local old_auth_sock_set=0
  local old_agent_pid=''
  local old_agent_pid_set=0
  local result
  local status_code
  local output

  agent_cmd=$(command -v ssh-agent 2>/dev/null || true)
  if [ -z "$agent_cmd" ]; then
    printf '%s\n' "SKIP $shell_name SSH auth sock bridge: ssh-agent not found" >&2
    return 0
  fi

  if [ "${SSH_AUTH_SOCK+x}" = x ]; then
    old_auth_sock_set=1
    old_auth_sock=$SSH_AUTH_SOCK
  fi
  if [ "${SSH_AGENT_PID+x}" = x ]; then
    old_agent_pid_set=1
    old_agent_pid=$SSH_AGENT_PID
  fi

  agent_sock="$tmp_home/agent.sock"
  set +e
  agent_output=$("$agent_cmd" -a "$agent_sock" -s 2>&1)
  status_code=$?
  set -e
  if [ "$status_code" -ne 0 ]; then
    fail "$shell_name SSH auth sock bridge could not start ssh-agent: $agent_output"
    return 0
  fi

  eval "$agent_output" >/dev/null
  guard_exec "$tmp_home" mkdir -p "$tmp_home/.ssh"
  guard_exec "$tmp_home" ln -sfn "$agent_sock" "$tmp_home/.ssh/ssh_auth_sock"

  result=$(run_shell "$shell_name" "$tmp_home" "$stub_bin" "$tmp_home/.missing-private" 'test "${SSH_AUTH_SOCK:-}" = "$HOME/.ssh/ssh_auth_sock"' '127.0.0.1 1 127.0.0.1 2')
  status_code=${result%%$'\n'*}
  output=${result#*$'\n__RAVY_OUTPUT__\n'}
  output=${output%$'\n__RAVY_END__'}
  if [ "$shell_name" = bash ]; then
    output=$(strip_bash_noise "$output")
  fi

  "$agent_cmd" -k >/dev/null 2>&1 || true
  if [ "$old_auth_sock_set" -eq 1 ]; then
    SSH_AUTH_SOCK=$old_auth_sock
    export SSH_AUTH_SOCK
  else
    unset SSH_AUTH_SOCK
  fi
  if [ "$old_agent_pid_set" -eq 1 ]; then
    SSH_AGENT_PID=$old_agent_pid
    export SSH_AGENT_PID
  else
    unset SSH_AGENT_PID
  fi

  assert_status_zero "$status_code" "$shell_name should use stable forwarded SSH auth socket" "$output"
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
    rm -f "$HOME/mise.log" "$HOME/sudo.log" "$HOME/pacman.log" &&
    rm -rf "$HOME/opt/mise/lib" &&
    mu &&
    grep -F "self-update" "$HOME/mise.log" >/dev/null 2>&1 &&
    grep -F "upgrade" "$HOME/mise.log" >/dev/null 2>&1 &&
    test ! -e "$HOME/sudo.log" &&
    test ! -e "$HOME/pacman.log"
  ')
  status_code=${result%%$'\n'*}
  output=${result#*$'\n__RAVY_OUTPUT__\n'}
  output=${output%$'\n__RAVY_END__'}
  if [ "$shell_name" = bash ]; then
    output=$(strip_bash_noise "$output")
  fi
  assert_status_zero "$status_code" "$shell_name mu self-update path failed" "$output"

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
    case \":\$PATH:\" in *\":$private_home/ops:\"*) ;; *) exit 1 ;; esac &&
    test \"\${__RAVY_PRIVATE_COMMON:-}\" = 1 &&
    test \"\${__RAVY_SECRETS_SH:-}\" = 1 &&
    test \"\${RAVY_TSV_VALUE:-}\" = value &&
    test \"\${RAVY_TSV_HOME_PATH:-}\" = \"\$HOME/example\" &&
    test \"\${RAVY_TSV_HOME_ROOT:-}\" = \"\$HOME\" &&
    test \"\${RAVY_TSV_HOME_OTHER:-}\" = '~otheruser/example' &&
    command -v private-helper >/dev/null 2>&1 &&
    command -v private-op-helper >/dev/null 2>&1 &&
    $fn_check ravyprivate >/dev/null &&
    $fn_check ravyc >/dev/null &&
    ! $fn_check ravycustom >/dev/null &&
    ! $fn_check ravyprivatecd >/dev/null &&
    rm -f \"\$HOME/chezmoi.log\" &&
    test \"\$(chez source-path)\" = \"$repo_root\" &&
    grep -F 'subcommand=source-path source=$repo_root config= state=' \"\$HOME/chezmoi.log\" >/dev/null 2>&1 &&
    rm -f \"\$HOME/chezmoi.log\" &&
    test \"\$(chez private source-path)\" = \"$private_home\" &&
    grep -F 'subcommand=source-path source=$private_home config=$tmp_home/.config/chezmoi/ravy-private.toml state=$tmp_home/.config/chezmoi/ravy-private-state.boltdb' \"\$HOME/chezmoi.log\" >/dev/null 2>&1 &&
    rm -f \"\$HOME/chezmoi.log\" &&
    test \"\$(chezp source-path)\" = \"$private_home\" &&
    grep -F 'subcommand=source-path source=$private_home config=$tmp_home/.config/chezmoi/ravy-private.toml state=$tmp_home/.config/chezmoi/ravy-private-state.boltdb' \"\$HOME/chezmoi.log\" >/dev/null 2>&1 &&
    test -f \"\$HOME/.config/chezmoi/ravy-private.toml\" &&
    grep -F 'seed = 1' \"\$HOME/.config/chezmoi/ravy-private.toml\" >/dev/null 2>&1 &&
    rm -f \"\$HOME/chezmoi.log\" &&
    chezp init >/dev/null 2>&1 &&
    grep -F 'subcommand=init source=$private_home config=$tmp_home/.config/chezmoi/ravy-private.toml state=$tmp_home/.config/chezmoi/ravy-private-state.boltdb config_path=$tmp_home/.config/chezmoi/ravy-private.toml' \"\$HOME/chezmoi.log\" >/dev/null 2>&1 &&
    rm -f \"\$HOME/chezmoi.log\" &&
    chez diff --exclude scripts >/dev/null 2>&1 &&
    head -n 1 \"\$HOME/chezmoi.log\" | grep -F 'subcommand=diff source=$repo_root config= state=' >/dev/null 2>&1 &&
    tail -n 1 \"\$HOME/chezmoi.log\" | grep -F 'subcommand=diff source=$private_home config=$tmp_home/.config/chezmoi/ravy-private.toml state=$tmp_home/.config/chezmoi/ravy-private-state.boltdb' >/dev/null 2>&1 &&
    test \"\$(grep -c '^subcommand=diff ' \"\$HOME/chezmoi.log\")\" -eq 2 &&
    rm -f \"\$HOME/chezmoi.log\" &&
    chez status --path-style absolute >/dev/null 2>&1 &&
    head -n 1 \"\$HOME/chezmoi.log\" | grep -F 'subcommand=status source=$repo_root config= state=' >/dev/null 2>&1 &&
    tail -n 1 \"\$HOME/chezmoi.log\" | grep -F 'subcommand=status source=$private_home config=$tmp_home/.config/chezmoi/ravy-private.toml state=$tmp_home/.config/chezmoi/ravy-private-state.boltdb' >/dev/null 2>&1 &&
    test \"\$(grep -c '^subcommand=status ' \"\$HOME/chezmoi.log\")\" -eq 2 &&
    rm -f \"\$HOME/chezmoi.log\" &&
    chez apply >/dev/null 2>&1 &&
    head -n 1 \"\$HOME/chezmoi.log\" | grep -F 'subcommand=apply source=$repo_root config= state=' >/dev/null 2>&1 &&
    tail -n 1 \"\$HOME/chezmoi.log\" | grep -F 'subcommand=apply source=$private_home config=$tmp_home/.config/chezmoi/ravy-private.toml state=$tmp_home/.config/chezmoi/ravy-private-state.boltdb' >/dev/null 2>&1 &&
    test \"\$(grep -c '^subcommand=apply ' \"\$HOME/chezmoi.log\")\" -eq 2 &&
    rm -f \"\$HOME/chezmoi.log\" &&
    chez diff ~/.config/ravy/secrets.tsv >/dev/null 2>&1 &&
    grep -F 'subcommand=diff source=$repo_root config= state=' \"\$HOME/chezmoi.log\" >/dev/null 2>&1 &&
    test \"\$(grep -c '^subcommand=diff ' \"\$HOME/chezmoi.log\")\" -eq 1 &&
    rm -f \"\$HOME/chezmoi.log\" &&
    chez private diff ~/.config/ravy/secrets.tsv >/dev/null 2>&1 &&
    grep -F 'subcommand=diff source=$private_home config=$tmp_home/.config/chezmoi/ravy-private.toml state=$tmp_home/.config/chezmoi/ravy-private-state.boltdb' \"\$HOME/chezmoi.log\" >/dev/null 2>&1 &&
    test \"\$(grep -c '^subcommand=diff ' \"\$HOME/chezmoi.log\")\" -eq 1 &&
    cd \"\$HOME\" &&
    ravyprivate && test \"\$PWD\" = \"$private_home\" &&
    cd \"\$HOME\" &&
    ravyc && test \"\$PWD\" = \"$private_home\" &&
    true
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
trap '
  if [ -n "${bash_home:-}" ] && [ -d "$bash_home" ]; then
    guard_exec "$bash_home" rm -rf "$bash_home"
  fi
  if [ -n "${zsh_home:-}" ] && [ -d "$zsh_home" ]; then
    guard_exec "$zsh_home" rm -rf "$zsh_home"
  fi
' EXIT
render_config "$bash_home" "$bash_home/.bashrc"
render_config "$bash_home" "$bash_home/.bash_profile"

# Prepend stub_bin to PATH so that system chezmoi is not invoked on macOS login
tmp_profile=$(mktemp "$bash_home/.tmp_bash_profile.XXXXXX")
guard_assert_path "$bash_home" "$tmp_profile" create
echo "export PATH=\"$bash_home/bin:\$PATH\"" > "$tmp_profile"
cat "$bash_home/.bash_profile" >> "$tmp_profile"
guard_exec "$bash_home" mv "$tmp_profile" "$bash_home/.bash_profile"

setup_base_stubs "$bash_home/bin"
check_clean_start bash "$bash_home" "$bash_home/bin" "$bash_home/.missing-private"
setup_tool_stubs "$bash_home/bin"
install_mise_stub "$bash_home" self
check_public_surface bash "$bash_home" "$bash_home/bin"
check_ssh_auth_sock_bridge bash "$bash_home" "$bash_home/bin"
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

if [ -n "$zsh_bin" ]; then
  zsh_home=$(setup_home)
  render_config "$zsh_home" "$zsh_home/.zshrc"
  setup_base_stubs "$zsh_home/bin"
  check_clean_start zsh "$zsh_home" "$zsh_home/bin" "$zsh_home/.missing-private"
  setup_tool_stubs "$zsh_home/bin"
  install_mise_stub "$zsh_home" self
  check_public_surface zsh "$zsh_home" "$zsh_home/bin"
  check_ssh_auth_sock_bridge zsh "$zsh_home" "$zsh_home/bin"
  check_mise_upgrade_helpers zsh "$zsh_home" "$zsh_home/bin"
  check_private_surface zsh "$zsh_home" "$zsh_home/bin" "$(setup_private_overlay "$zsh_home")"
  check_rendered_gitconfig "$zsh_home"
else
  echo 'SKIP zsh shell config tests: zsh not found' >&2
fi

if [ "$failures" -eq 0 ]; then
  echo 'All sh shell config tests passed'
fi

exit "$failures"
