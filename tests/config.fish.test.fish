#!/usr/bin/env fish

set -g script_path (realpath (status --current-filename))
set -g repo_root (realpath (dirname $script_path)/..)
set -g guard_cmd "$repo_root/tests/prefix_guard_command.sh"

function __assert_guard_root --argument-names root
    set -l prefix "$repo_root/.tmp_"
    if test (string sub -s 1 -l (string length -- "$prefix") -- "$root") = "$prefix"
        return 0
    end

    echo "prefix guard blocked unexpected tmp root: $root" >&2
    exit 1
end

function __assert_guard_path --argument-names root path
    if test "$path" = "$root"
        return 0
    end

    set -l prefix "$root/"
    if test (string sub -s 1 -l (string length -- "$prefix") -- "$path") = "$prefix"
        return 0
    end

    echo "prefix guard blocked path outside root: $path" >&2
    exit 1
end

function __guard_exec --argument-names root
    "$guard_cmd" "$root" $argv[2..-1]
end

if not set -q RAVY_TEST_CHILD
    set -l tmp_home (mktemp -d "$repo_root/.tmp_fish_home.XXXXXX")
    __assert_guard_root "$tmp_home"
    set -g __ravy_test_tmp_home "$tmp_home"
    set -g stub_bin "$tmp_home/bin"
    set -l real_chezmoi (command -s chezmoi)

    __guard_exec "$tmp_home" mkdir -p $stub_bin \
        "$tmp_home/.config/fish" \
        "$tmp_home/.config/chezmoi" \
        "$tmp_home/.config/ravy" \
        "$tmp_home/.local/bin" \
        "$tmp_home/.local/share"
    __assert_guard_path "$tmp_home" "$tmp_home/.config/chezmoi/chezmoi.toml"
    printf "%s\n" "seed = 1" > "$tmp_home/.config/chezmoi/chezmoi.toml"

    function __write_exec --argument-names target body
        __assert_guard_path "$__ravy_test_tmp_home" "$target"
        __guard_exec "$__ravy_test_tmp_home" mkdir -p (dirname "$target")
        printf "%s" "$body" >$target
        __guard_exec "$__ravy_test_tmp_home" chmod +x $target
    end

    function __write_stub --argument-names name body
        __write_exec "$stub_bin/$name" "$body"
    end

    function __install_guard_wrappers --argument-names root bin_dir
        for cmd in rm cp mv ln mkdir touch chmod
            __write_exec "$bin_dir/$cmd" "#!/usr/bin/env bash
exec \"$guard_cmd\" \"$root\" \"$cmd\" \"\$@\"
"
        end
    end

    function __install_mise_stub --argument-names layout
        set -l target
        switch "$layout"
            case self
                set target "$__ravy_test_tmp_home/opt/mise/bin/mise"
            case '*'
                echo "unknown mise stub layout: $layout" >&2
                exit 1
        end

        __write_exec "$target" "#!/usr/bin/env sh
if [ \"\$1\" = \"activate\" ]; then
  cat <<'EOF'
set -gx __RAVY_MISE_INIT 1
EOF
  exit 0
fi
printf \"%s\n\" \"\$*\" >> \"\$HOME/mise.log\"
exit 0
"
        __guard_exec "$__ravy_test_tmp_home" ln -sfn "$target" "$stub_bin/mise"
    end

    __install_guard_wrappers "$tmp_home" "$stub_bin"

    __write_stub starship "#!/usr/bin/env sh
if [ \"\$1\" = \"init\" ] && [ \"\$2\" = \"fish\" ]; then
  cat <<'EOF'
function __starship_set_job_count
end
EOF
  exit 0
fi
exit 0
"

    __write_stub zoxide "#!/usr/bin/env sh
if [ \"\$1\" = \"init\" ] && [ \"\$2\" = \"fish\" ]; then
  cat <<'EOF'
function __ravy_zoxide_init
end
EOF
  exit 0
fi
exit 0
"

    __write_stub atuin "#!/usr/bin/env sh
if [ \"\$1\" = \"init\" ] && [ \"\$2\" = \"fish\" ]; then
  cat <<'EOF'
function _atuin_preexec
end
function _atuin_search
end
function _atuin_bind_up
end
EOF
  exit 0
fi
if [ \"\$1\" = \"history\" ] && [ \"\$2\" = \"list\" ]; then
  printf 'local latest\\0g pp\\0chez apply\\0ravy\\0G CIA\\0cd custom/\\0'
  exit 0
fi
exit 0
"

    __write_stub carapace "#!/usr/bin/env sh
if [ \"\$1\" = \"_carapace\" ]; then
  cat <<'EOF'
function __ravy_carapace_init
end
complete -c bun -f -a 'install add run'
EOF
  exit 0
fi
exit 0
"

    __write_stub codex "#!/usr/bin/env sh
printf '%s\n' \"\$*\" >> \"\$HOME/codex.log\"
exit 0
"

    __write_stub zellij-lock-watch "#!/usr/bin/env sh
printf '%s\n' \"watch session=\${ZELLIJ_SESSION_NAME:-} pane=\${ZELLIJ_PANE_ID:-}\" >> \"\$HOME/zellij-lock-watch.log\"
exit 0
"

    __write_stub sudo "#!/usr/bin/env sh
printf \"%s\n\" \"\$*\" >> \"\$HOME/sudo.log\"
exec \"\$@\"
"

    __write_stub chezmoi "#!/usr/bin/env sh
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
  printf '%s\n' \"subcommand=source-path source=\$source_path config=\$config_path state=\$state_path\" >> \"\$HOME/chezmoi.log\"
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
  printf '%s\n' \"subcommand=init source=\$source_path config=\$config_path state=\$state_path config_path=\$init_config_path\" >> \"\$HOME/chezmoi.log\"
  exit 0
fi
if [ \"\$subcommand\" = \"apply\" ] || [ \"\$subcommand\" = \"diff\" ] || [ \"\$subcommand\" = \"status\" ]; then
  printf '%s\n' \"subcommand=\$subcommand source=\$source_path config=\$config_path state=\$state_path\" >> \"\$HOME/chezmoi.log\"
  exit 0
fi
if [ \"\$subcommand\" = \"cat\" ]; then
  exec \"$real_chezmoi\" -S \"$repo_root\" -D \"$tmp_home\" cat \"\$@\"
fi
exit 0
"

    __write_stub eza "#!/usr/bin/env sh
exit 0
"

    __install_mise_stub self

    set -l fish_cmd (command -s fish)

    env HOME=$tmp_home \
        XDG_CONFIG_HOME=$tmp_home/.config \
        XDG_DATA_HOME=$tmp_home/.local/share \
        PATH="$stub_bin:/usr/bin:/bin" \
        RAVY_HOST=test-host \
        RAVY_PRIVATE_HOME=$tmp_home/.missing-private \
        RAVY_SKIP_BREW=1 \
        HOMEBREW_BUNDLE_FILE="$repo_root/Brewfile" \
        RAVY_TEST_FISH_CMD="$fish_cmd" \
        RAVY_TEST_CHILD=1 \
        $fish_cmd --private -i "$script_path"

    set -l status_code $status
    if not set -q RAVY_TEST_DEBUG
        __guard_exec "$tmp_home" rm -rf $tmp_home
    end
    exit $status_code
end

set -g __failures 0

function fail --argument-names msg detail
    set -l full_msg $msg
    if test -n "$detail"
        set full_msg "$msg: $detail"
    end
    echo "FAIL $full_msg" >&2
    set -g __failures (math $__failures + 1)
end

function assert_equal --argument-names actual expected msg
    if test "$actual" != "$expected"
        fail $msg "got '$actual' expected '$expected'"
    end
end

function assert_true --argument-names condition msg
    if not eval $condition
        fail $msg
    end
end

function assert_contains --argument-names needle
    set -l msg $argv[-1]
    set -l haystack $argv[2..-2]
    if not contains -- $needle $haystack
        fail $msg
    end
end

function check_ssh_auth_sock_bridge
    set -l agent_cmd (command -s ssh-agent)
    if test -z "$agent_cmd"
        echo "SKIP fish SSH auth sock bridge: ssh-agent not found" >&2
        return 0
    end

    set -l bridge_home "$HOME/ssh-auth-bridge-home"
    set -l agent_sock "$bridge_home/agent.sock"
    set -l fish_cmd "$RAVY_TEST_FISH_CMD"
    mkdir -p "$bridge_home/.ssh" "$bridge_home/.config" "$bridge_home/.local/share"
    ln -sfn "$agent_sock" "$bridge_home/.ssh/ssh_auth_sock"

    set -l probe_output ($agent_cmd -a "$agent_sock" env \
        HOME="$bridge_home" \
        XDG_CONFIG_HOME="$bridge_home/.config" \
        XDG_DATA_HOME="$bridge_home/.local/share" \
        PATH="$stub_bin:/usr/bin:/bin" \
        RAVY_HOST=test-host \
        RAVY_PRIVATE_HOME="$bridge_home/.missing-private" \
        RAVY_SKIP_BREW=1 \
        SSH_CONNECTION="127.0.0.1 1 127.0.0.1 2" \
        "$fish_cmd" --private -i -c "source '$rendered_config'; test \"\$SSH_AUTH_SOCK\" = \"\$HOME/.ssh/ssh_auth_sock\"" 2>&1)
    set -l probe_status $status
    if test $probe_status -ne 0
        fail "fish should use stable forwarded SSH auth socket" "$probe_output"
    end

    set -l old_sock "$bridge_home/old-agent.sock"
    set -l new_sock "$bridge_home/new-agent.sock"
    set -l old_agent_output ($agent_cmd -a "$old_sock" -s 2>&1)
    set -l old_agent_status $status
    if test $old_agent_status -ne 0
        fail "fish SSH auth sock bridge could not start old ssh-agent" "$old_agent_output"
        return 0
    end

    set -l old_agent_pid (string match -rg 'SSH_AGENT_PID=([0-9]+)' $old_agent_output | head -n1)
    ln -sfn "$old_sock" "$bridge_home/.ssh/ssh_auth_sock"
    set -l noninteractive_output ($agent_cmd -a "$new_sock" env \
        HOME="$bridge_home" \
        XDG_CONFIG_HOME="$bridge_home/.config" \
        XDG_DATA_HOME="$bridge_home/.local/share" \
        PATH="$stub_bin:/usr/bin:/bin" \
        RAVY_HOST=test-host \
        RAVY_PRIVATE_HOME="$bridge_home/.missing-private" \
        RAVY_SKIP_BREW=1 \
        SSH_CONNECTION="127.0.0.1 1 127.0.0.1 2" \
        "$fish_cmd" --private -c "source '$rendered_config'; test \"\$SSH_AUTH_SOCK\" = '$new_sock'" 2>&1)
    set -l noninteractive_status $status
    if test -n "$old_agent_pid"
        kill "$old_agent_pid" >/dev/null 2>/dev/null
    end
    if test $noninteractive_status -ne 0
        fail "fish non-interactive startup should preserve sshd forwarded SSH auth socket" "$noninteractive_output"
    end
end

function setup_private_overlay
    set -l private_home "$HOME/.local/share/ravy-private"
    mkdir -p \
        "$private_home/shell" \
        "$private_home/bin/common" \
        "$private_home/ops" \
        "$HOME/.config/ravy"

    printf "%s\n" "set -gx __RAVY_PRIVATE_COMMON 1" > "$private_home/shell/config.fish"
    cat "$repo_root/tests/fixtures/private_secrets.fish" > "$HOME/.config/ravy/secrets.fish"
    printf "%s\t%s\n%s\t%s\n%s\t%s\n%s\t%s\n%s\t%s\n" \
        __RAVY_SECRETS_FISH " 1" \
        RAVY_TSV_VALUE " value" \
        RAVY_TSV_HOME_PATH " ~/example" \
        RAVY_TSV_HOME_ROOT " ~" \
        RAVY_TSV_HOME_OTHER " ~otheruser/example" > "$HOME/.config/ravy/secrets.tsv"
    printf "%s\n" "#!/usr/bin/env sh\nexit 0\n" > "$private_home/bin/common/private-helper"
    printf "%s\n" "#!/usr/bin/env sh\nexit 0\n" > "$private_home/ops/private-op-helper"
    chmod +x "$private_home/bin/common/private-helper"
    chmod +x "$private_home/ops/private-op-helper"
    printf "%s\n" $private_home
end

set -l expected_ravy_home (realpath "$repo_root")
set -g rendered_config "$HOME/.config/fish/config.fish"
set -g rendered_key_bindings "$HOME/.config/fish/functions/fish_user_key_bindings.fish"
set -g rendered_theme "$HOME/.config/fish/themes/ravy.theme"

mkdir -p (dirname $rendered_config)
mkdir -p (dirname $rendered_key_bindings)
mkdir -p (dirname $rendered_theme)
chezmoi cat "$rendered_config" > $rendered_config
chezmoi cat "$rendered_key_bindings" > $rendered_key_bindings
chezmoi cat "$rendered_theme" > $rendered_theme

set -gx HOMEBREW_BUNDLE_FILE "$repo_root/Brewfile"
source $rendered_config
source $rendered_key_bindings

assert_equal $RAVY_HOME $expected_ravy_home "RAVY_HOME set from chezmoi source-path"
assert_equal $HOMEBREW_BUNDLE_FILE "$HOME/.config/homebrew/Brewfile" "HOMEBREW_BUNDLE_FILE points at applied Brewfile"
assert_true "not set -q RAVY_PRIVATE_HOME" "RAVY_PRIVATE_HOME stays unset when private repo is missing"
assert_contains "$RAVY_HOME/bin" $PATH "PATH includes RAVY_HOME/bin"
assert_contains "$HOME/bin" $PATH "PATH includes HOME/bin"
assert_contains "$HOME/.local/bin" $PATH "PATH includes HOME/.local/bin"
check_ssh_auth_sock_bridge
assert_contains green $fish_color_command "fish theme sets command color"
assert_contains 555 $fish_color_autosuggestion "fish theme sets autosuggestion fallback color"
assert_contains brblack $fish_color_autosuggestion "fish theme sets autosuggestion named fallback"
assert_true "functions -q __starship_set_job_count" "starship prompt initialized"
assert_true "functions -q __ravy_zoxide_init" "zoxide hook initialized"
assert_true "functions -q _atuin_preexec" "atuin hook initialized"
assert_true "functions -q _atuin_search" "atuin search function initialized"
assert_true "functions -q _atuin_bind_up" "atuin up binding function initialized"
assert_true "functions -q __fle_fzf_history" "fzf history helper defined"
assert_true "functions -q __fle_atuin_contains_search_backward" "atuin contains backward helper defined"
assert_true "functions -q __fle_atuin_contains_search_forward" "atuin contains forward helper defined"
history append "local latest"
assert_equal (__fle_atuin_contains_candidates '')[1] "local latest" "empty atuin contains search starts from latest local history"
assert_equal (__fle_atuin_contains_candidates '')[2] "g pp" "empty atuin contains search skips duplicate latest history"
assert_equal (__fle_atuin_contains_candidates pp)[1] "g pp" "atuin contains search matches command middle"
assert_equal (__fle_atuin_contains_candidates AP)[1] "chez apply" "atuin contains search is case-insensitive"
bind \er | string match -q '*__fle_fzf_history*'
or fail "Alt-r binds to fzf history helper"
bind \cr | string match -q '*_atuin_search*'
or fail "Ctrl-r binds to Atuin TUI search"
bind \cp | string match -q '*__fle_atuin_contains_search_backward*'
or fail "Ctrl-p binds to Atuin contains backward search"
bind \cn | string match -q '*__fle_atuin_contains_search_forward*'
or fail "Ctrl-n binds to Atuin contains forward search"
bind up | string match -q '*_atuin_bind_up*'
or fail "Up binds to Atuin up search"
assert_true "functions -q __ravy_carapace_init" "carapace completions initialized"
assert_equal "$CARAPACE_BRIDGES" zsh,fish,bash "carapace bridges default to zsh,fish,bash"
assert_equal "$CARAPACE_EXCLUDES" brew,git "carapace excludes default to brew,git"
complete -C "bun " | string match -q '*install*'
or fail "carapace provides bun completions"
assert_true "test \"$__RAVY_MISE_INIT\" = 1" "mise activated"
assert_true "functions -q d" "cd helper function defined"
assert_true "functions -q ravy" "ravy helper defined"
assert_true "functions -q ravyprivate" "private repo helper defined"
assert_true "functions -q chez" "chez alias defined"
assert_true "functions -q chezp" "chezp helper defined"
assert_true "functions -q ravysource" "ravysource helper defined"
assert_true "command -v codex >/dev/null" "codex command is available"
assert_true "functions -q l" "generic alias 'l' defined"
assert_true "functions -q ravyc" "private repo short helper defined"
assert_true "not functions -q ravycustom" "old private repo helper is removed"
assert_true "not functions -q ravyprivatecd" "old private repo cd helper is removed"
assert_true "functions -q rgh" "rgh alias defined"
assert_true "command -v mu >/dev/null" "mu command defined"
assert_true "not functions -q mu" "mu is not a fish function or alias"
assert_true "command -v auau >/dev/null" "auau command defined"
assert_true "not functions -q auau" "auau is not a fish function or alias"
functions rgh | string match -q '*rg -S --hidden*'
or fail "rgh expands to hidden rg search"
if command -q brew
    assert_true "functions -q bi" "brew alias is defined when command exists"
else
    assert_true "not functions -q bi" "brew alias is gated behind command availability"
end
if command -q pacman
    assert_true "functions -q pupu" "pacman alias is defined when command exists"
else
    assert_true "not functions -q pupu" "pacman alias is gated behind command availability"
end
assert_true "command -v ep >/dev/null" "ep helper exists"
assert_true "command -v jl >/dev/null" "jl helper exists"
assert_true "command -v lines >/dev/null" "lines helper exists"
assert_true "command -v downcase-exts >/dev/null" "downcase-exts helper exists"

rm -f "$HOME/codex.log"
set -e ZELLIJ
codex resume abc123 >/dev/null
grep -Fx "resume abc123" "$HOME/codex.log" >/dev/null
or fail "codex command should pass args through outside Zellij"
rm -f "$HOME/codex.log"
set -gx ZELLIJ 1
set -gx ZELLIJ_PANE_ID 7
codex resume abc123 >/dev/null
set -e ZELLIJ
set -e ZELLIJ_PANE_ID
grep -Fx -- "resume abc123" "$HOME/codex.log" >/dev/null
or fail "codex command should pass args through inside Zellij"

rm -f "$HOME/zellij-lock-watch.log"
set -gx PATH "$HOME/bin" $PATH
set -gx ZELLIJ 1
set -gx ZELLIJ_PANE_ID 7
set -gx ZELLIJ_SESSION_NAME test-session
__ravy_zellij_lock_watch_start
sleep 0.1
set -e ZELLIJ
set -e ZELLIJ_PANE_ID
set -e ZELLIJ_SESSION_NAME
grep -Fx "watch session=test-session pane=7" "$HOME/zellij-lock-watch.log" >/dev/null
or fail "interactive shell can start zellij-lock-watch inside Zellij"

rm -f "$HOME/mise.log" "$HOME/sudo.log"
rm -rf "$HOME/opt/mise/lib" "$HOME/usr/lib"
mu
grep -F "self-update" "$HOME/mise.log" >/dev/null
or fail "mu uses mise self-update"
grep -F "upgrade" "$HOME/mise.log" >/dev/null
or fail "mu runs mise upgrade"
test ! -f "$HOME/sudo.log"
or fail "mu should not call sudo"

rm -f "$HOME/chezmoi.log"
assert_equal (chez source-path) $expected_ravy_home "chez resolves to public chezmoi source"
grep -F "subcommand=source-path source=$expected_ravy_home config= state=" "$HOME/chezmoi.log" >/dev/null
or fail "chez keeps using the default chezmoi config/state"
rm -f "$HOME/chezmoi.log"
chez diff --exclude scripts >/dev/null 2>/dev/null
grep -F "subcommand=diff source=$expected_ravy_home config= state=" "$HOME/chezmoi.log" >/dev/null
or fail "chez diff should stay public-only when private is missing"
test (grep -c '^subcommand=diff ' "$HOME/chezmoi.log") -eq 1
or fail "chez diff should only run once without a private repo"
rm -f "$HOME/chezmoi.log"
chez status --path-style absolute >/dev/null 2>/dev/null
grep -F "subcommand=status source=$expected_ravy_home config= state=" "$HOME/chezmoi.log" >/dev/null
or fail "chez status should stay public-only when private is missing"
test (grep -c '^subcommand=status ' "$HOME/chezmoi.log") -eq 1
or fail "chez status should only run once without a private repo"
rm -f "$HOME/chezmoi.log"
chez apply >/dev/null 2>/dev/null
grep -F "subcommand=apply source=$expected_ravy_home config= state=" "$HOME/chezmoi.log" >/dev/null
or fail "chez apply should stay public-only when private is missing"
test (grep -c '^subcommand=apply ' "$HOME/chezmoi.log") -eq 1
or fail "chez apply should only run once without a private repo"
rm -f "$HOME/chezmoi.log"
chez init >/dev/null 2>/dev/null
test ! -f "$HOME/.config/chezmoi/ravy-public.toml"
or fail "chez does not create a dedicated public config file"
grep -F "subcommand=init source=$expected_ravy_home config= state= config_path=" "$HOME/chezmoi.log" >/dev/null
or fail "chez init keeps using the default chezmoi config/state"

ravyprivate >/dev/null 2>/dev/null
if test $status -eq 0
    fail "ravyprivate should fail without a private repo"
end

ravyc >/dev/null 2>/dev/null
if test $status -eq 0
    fail "ravyc should fail without a private repo"
end

chez private source-path >/dev/null 2>/dev/null
if test $status -eq 0
    fail "chez private should fail without a private repo"
end

chezp source-path >/dev/null 2>/dev/null
if test $status -eq 0
    fail "chezp should fail without a private repo"
end

set -l private_home (setup_private_overlay)
set -gx RAVY_PRIVATE_HOME "$private_home"
source $rendered_config

assert_equal $RAVY_PRIVATE_HOME $private_home "RAVY_PRIVATE_HOME resolves to the explicit private repo"
assert_equal $RAVY_CUSTOM $private_home "RAVY_CUSTOM compatibility variable follows RAVY_PRIVATE_HOME"
assert_contains "$private_home/bin/common" $PATH "PATH includes private common bin directory"
assert_contains "$private_home/ops" $PATH "PATH includes private ops directory"
assert_true "test \"$__RAVY_PRIVATE_COMMON\" = 1" "private common overlay loaded"
assert_true "test \"$__RAVY_SECRETS_FISH\" = 1" "managed secret fish overrides loaded"
assert_equal "$RAVY_TSV_VALUE" value "managed secret fish loader trims delimiter padding"
assert_equal "$RAVY_TSV_HOME_PATH" "$HOME/example" "managed secret fish loader expands ~/ paths"
assert_equal "$RAVY_TSV_HOME_ROOT" "$HOME" "managed secret fish loader expands bare ~"
assert_equal "$RAVY_TSV_HOME_OTHER" "~otheruser/example" "managed secret fish loader keeps other-user tildes literal"
assert_true "command -v private-helper >/dev/null" "private helper command exists"
assert_true "command -v private-op-helper >/dev/null" "private ops command exists"
rm -f "$HOME/chezmoi.log"
assert_equal (chez source-path) $expected_ravy_home "chez source-path stays public when private is present"
grep -F "subcommand=source-path source=$expected_ravy_home config= state=" "$HOME/chezmoi.log" >/dev/null
or fail "chez source-path should keep targeting the public repo"
rm -f "$HOME/chezmoi.log"
assert_equal (chez private source-path) $private_home "chez private resolves to the private chezmoi source"
grep -F "subcommand=source-path source=$private_home config=$HOME/.config/chezmoi/ravy-private.toml state=$HOME/.config/chezmoi/ravy-private-state.boltdb" "$HOME/chezmoi.log" >/dev/null
or fail "chez private should use the dedicated private config/state"
rm -f "$HOME/chezmoi.log"
assert_equal (chezp source-path) $private_home "chezp resolves to the private chezmoi source"
test -f "$HOME/.config/chezmoi/ravy-private.toml"
or fail "chezp seeds a dedicated private config file"
grep -F "seed = 1" "$HOME/.config/chezmoi/ravy-private.toml" >/dev/null
or fail "chezp copies the existing config into the dedicated private config"
grep -F "subcommand=source-path source=$private_home config=$HOME/.config/chezmoi/ravy-private.toml state=$HOME/.config/chezmoi/ravy-private-state.boltdb" "$HOME/chezmoi.log" >/dev/null
or fail "chezp should remain a compatibility alias for the private repo"
rm -f "$HOME/chezmoi.log"
chezp init >/dev/null 2>/dev/null
grep -F "subcommand=init source=$private_home config=$HOME/.config/chezmoi/ravy-private.toml state=$HOME/.config/chezmoi/ravy-private-state.boltdb config_path=$HOME/.config/chezmoi/ravy-private.toml" "$HOME/chezmoi.log" >/dev/null
or fail "chezp init regenerates the private config file"
rm -f "$HOME/chezmoi.log"
chez diff --exclude scripts >/dev/null 2>/dev/null
head -n 1 "$HOME/chezmoi.log" | grep -F "subcommand=diff source=$expected_ravy_home config= state=" >/dev/null
or fail "chez diff should run the public repo first"
tail -n 1 "$HOME/chezmoi.log" | grep -F "subcommand=diff source=$private_home config=$HOME/.config/chezmoi/ravy-private.toml state=$HOME/.config/chezmoi/ravy-private-state.boltdb" >/dev/null
or fail "chez diff should run the private repo second"
test (grep -c '^subcommand=diff ' "$HOME/chezmoi.log") -eq 2
or fail "chez diff should run both repos when private is configured"
rm -f "$HOME/chezmoi.log"
chez status --path-style absolute >/dev/null 2>/dev/null
head -n 1 "$HOME/chezmoi.log" | grep -F "subcommand=status source=$expected_ravy_home config= state=" >/dev/null
or fail "chez status should run the public repo first"
tail -n 1 "$HOME/chezmoi.log" | grep -F "subcommand=status source=$private_home config=$HOME/.config/chezmoi/ravy-private.toml state=$HOME/.config/chezmoi/ravy-private-state.boltdb" >/dev/null
or fail "chez status should run the private repo second"
test (grep -c '^subcommand=status ' "$HOME/chezmoi.log") -eq 2
or fail "chez status should run both repos when private is configured"
rm -f "$HOME/chezmoi.log"
chez apply >/dev/null 2>/dev/null
head -n 1 "$HOME/chezmoi.log" | grep -F "subcommand=apply source=$expected_ravy_home config= state=" >/dev/null
or fail "chez apply should run the public repo first"
tail -n 1 "$HOME/chezmoi.log" | grep -F "subcommand=apply source=$private_home config=$HOME/.config/chezmoi/ravy-private.toml state=$HOME/.config/chezmoi/ravy-private-state.boltdb" >/dev/null
or fail "chez apply should run the private repo second"
test (grep -c '^subcommand=apply ' "$HOME/chezmoi.log") -eq 2
or fail "chez apply should run both repos when private is configured"
rm -f "$HOME/chezmoi.log"
chez diff ~/.config/ravy/secrets.tsv >/dev/null 2>/dev/null
grep -F "subcommand=diff source=$expected_ravy_home config= state=" "$HOME/chezmoi.log" >/dev/null
or fail "path-scoped chez diff should stay public-only"
test (grep -c '^subcommand=diff ' "$HOME/chezmoi.log") -eq 1
or fail "path-scoped chez diff should not fan out to the private repo"
rm -f "$HOME/chezmoi.log"
chez private diff ~/.config/ravy/secrets.tsv >/dev/null 2>/dev/null
grep -F "subcommand=diff source=$private_home config=$HOME/.config/chezmoi/ravy-private.toml state=$HOME/.config/chezmoi/ravy-private-state.boltdb" "$HOME/chezmoi.log" >/dev/null
or fail "chez private diff should target the private repo explicitly"
test (grep -c '^subcommand=diff ' "$HOME/chezmoi.log") -eq 1
or fail "chez private diff should only run once"

set -l orig_pwd $PWD
ravyprivate
assert_equal $PWD $private_home "ravyprivate jumps to private repo"
cd $orig_pwd
ravyc
assert_equal $PWD $private_home "ravyc jumps to private repo"
cd $orig_pwd

set -l rendered_gitconfig "$HOME/.gitconfig"
chezmoi cat "$rendered_gitconfig" > "$rendered_gitconfig"
grep -F 'path = ~/.config/ravy/private.gitconfig' "$rendered_gitconfig" >/dev/null
or fail "rendered gitconfig is missing private include shim"

if test $__failures -eq 0
    echo "All config.fish tests passed"
end

exit $__failures
