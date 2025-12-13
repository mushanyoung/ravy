#!/usr/bin/env fish

# Ensure we run in an interactive shell with isolated config directories so
# config.fish executes its interactive-only branches safely.
set -l script_path (realpath (status --current-filename))
    set -l repo_root (realpath (dirname $script_path)/..)

if not set -q RAVY_TEST_CHILD
    set -l tmp_home (mktemp -d "$repo_root/.tmp_fish_home.XXXXXX")
    set -g stub_bin "$tmp_home/bin"
    set -l real_chezmoi (command -s chezmoi)

    mkdir -p $stub_bin \
        "$tmp_home/.config/fish" \
        "$tmp_home/.local/bin" \
        "$tmp_home/.local/share" \

    # Helper to write simple stub executables.
    function __write_stub --argument-names name body
        set -l target "$stub_bin/$name"
        printf "%s" "$body" >$target
        chmod +x $target
    end

    # Stubs for tools config.fish hooks into.
    __write_stub starship "#!/usr/bin/env sh
if [ -n \"$tmp_home\" ]; then echo starship > \"$tmp_home/starship_ran\"; fi
if [ \"\$1\" = \"init\" ] && [ \"\$2\" = \"fish\" ]; then
  cat <<'EOF'
function __starship_set_job_count
end
EOF
  exit 0
fi
echo \"# starship stub\"
"

    __write_stub direnv "#!/usr/bin/env sh
if [ -n \"$tmp_home\" ]; then echo direnv > \"$tmp_home/direnv_ran\"; fi
if [ \"\$1\" = \"hook\" ] && [ \"\$2\" = \"fish\" ]; then
  cat <<'EOF'
function __direnv_export_eval
end
EOF
  exit 0
fi
echo \"# direnv stub\"
"

    __write_stub atuin "#!/usr/bin/env sh
if [ -n \"$tmp_home\" ]; then echo atuin > \"$tmp_home/atuin_ran\"; fi
if [ \"\$1\" = \"init\" ] && [ \"\$2\" = \"fish\" ]; then
  cat <<'EOF'
function _atuin_preexec
end
EOF
  exit 0
fi
echo \"# atuin stub\"
"

    __write_stub chezmoi "#!/usr/bin/env sh
if [ \"\$1\" = \"source-path\" ]; then
  echo \"$repo_root\"
  exit 0
fi
if [ \"\$1\" = \"execute-template\" ]; then
  shift
  exec \"$real_chezmoi\" execute-template \"\$@\"
fi
if [ \"\$1\" = \"cat\" ]; then
  shift
  exec \"$real_chezmoi\" -S \"$repo_root\" -D \"$tmp_home\" cat \"\$@\"
fi
exit 0
"

    # Stubs used by wrapper functions.
    __write_stub eza "#!/usr/bin/env sh
printf \"%s\\n\" \"\$@\" > \"$tmp_home/eza_args\"
"

    __write_stub gdu "#!/usr/bin/env sh
printf \"%s\\n\" \"\$@\" > \"$tmp_home/gdu_args\"
"

    set -l fish_cmd (command -s fish)

    env HOME=$tmp_home \
        XDG_CONFIG_HOME=$tmp_home/.config \
        XDG_DATA_HOME=$tmp_home/.local/share \
        PATH="$stub_bin:/usr/bin:/bin" \
        RAVY_SKIP_BREW=1 \
        RAVY_TEST_CHILD=1 \
        RAVY_TEST_TEMP_HOME=$tmp_home \
        STUB_BIN=$stub_bin \
        $fish_cmd --private -i "$script_path"

    set -l status_code $status
    if not set -q RAVY_TEST_DEBUG
        rm -rf $tmp_home
    end
    exit $status_code
end

# Interactive section starts here.
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

set -l expected_ravy_home (realpath "$repo_root")

# Ensure cursor-related variables don't force pager to cat.
set -e CURSOR_AGENT
set -e CURSOR_TRACE_ID

# Render the chezmoi template to a real config file, then source it.
set -l rendered_config "$HOME/.config/fish/config.fish"
mkdir -p (dirname $rendered_config)
chezmoi cat "$rendered_config" > $rendered_config
source $rendered_config

if set -q RAVY_TEST_DEBUG
    echo "DEBUG PATH entries:"
    printf "%s\n" $PATH
end

# Path setup
assert_equal $RAVY_HOME $expected_ravy_home "RAVY_HOME set from chezmoi source-path"
assert_contains "$RAVY_HOME/bin" $PATH "PATH includes RAVY_HOME/bin"
assert_contains "$HOME/bin" $PATH "PATH includes HOME/bin"
assert_contains "$HOME/.local/bin" $PATH "PATH includes HOME/.local/bin"

# Brew detection
set -l expected_brew_prefix ''
for brewprefix in /opt/homebrew /usr/local /home/linuxbrew/.linuxbrew "$HOME/.brew" "$HOME/.linuxbrew"
    if test -f "$brewprefix/bin/brew"
        set expected_brew_prefix $brewprefix
        break
    end
end

if test -n "$expected_brew_prefix"
    assert_equal $HOMEBREW_PREFIX $expected_brew_prefix "Homebrew prefix detected"
    assert_equal $HOMEBREW_CELLAR "$expected_brew_prefix/Cellar" "Homebrew cellar set"
    assert_equal $HOMEBREW_REPOSITORY "$expected_brew_prefix/Homebrew" "Homebrew repository set"
    assert_equal $HOMEBREW_NO_ANALYTICS 1 "Homebrew analytics disabled"
else
    assert_true "not set -q HOMEBREW_PREFIX" "Homebrew variables remain unset when brew is missing"
end

# Tool hooks
if command -v starship >/dev/null
    assert_equal $STARSHIP_CONFIG "$HOME/.config/starship.toml" "Starship config path exported"
    assert_true "functions -q __starship_set_job_count" "Starship prompt initialized"
else
    assert_true "not set -q STARSHIP_CONFIG" "Starship config skipped when unavailable"
end

if command -v direnv >/dev/null
    assert_true "functions -q __direnv_export_eval" "direnv hook initialized"
end

if command -v atuin >/dev/null
    assert_true "functions -q _atuin_preexec" "atuin hook initialized"
end

# Core environment
assert_equal $LANG en_US.UTF-8 "LANG set"
assert_equal $LANGUAGE en_US.UTF-8 "LANGUAGE set"
assert_equal $EDITOR nvim "EDITOR set"
assert_equal $GIT_EDITOR nvim "GIT_EDITOR set"
assert_equal $PAGER less "PAGER set"
assert_equal $MANPAGER less "MANPAGER set"
assert_equal $GIT_PAGER less "GIT_PAGER set"
assert_equal $LESS FRSXMi "LESS options set"
assert_contains "--bind=ctrl-f:page-down,ctrl-b:page-up" $FZF_DEFAULT_OPTS "FZF opts bound"
assert_equal $FZF_DEFAULT_COMMAND fd "FZF default command set"
assert_equal $EZA_CONFIG_DIR "$HOME/.config/eza" "EZA config dir set"
assert_true "set -q FISH_TITLE" "FISH_TITLE defined"

if test -z "$LESS_TERMCAP_mb" -o -z "$LESS_TERMCAP_md" -o -z "$LESS_TERMCAP_so"
    fail "LESS_TERMCAP variables configured"
end

# Functions and aliases
for fn in prepend_to_path imv lines d ep history-stat ls du fish_title __fish_title_or_pwd jl downcase-exts
    assert_true "functions -q $fn" "Function '$fn' defined"
end

for alias_name in l la lt ld ll ta df g t hs tf rd rb v vi vim grep ts ci pa pc bi au pupu pd dp dcl dcb dud dpdu dudp dpri dprs dli dls drc dri dry reset ravy ravycustom ravysource
    assert_true "functions -q $alias_name" "Alias '$alias_name' defined"
end

# Script helpers (shared across shells via $RAVY_HOME/bin)
for cmd in dc retry ping pip-update-all free
    assert_true "command -v $cmd >/dev/null" "Command '$cmd' exists"
end

# Wrapper behavior: ls and du should execute without errors.
ls "$RAVY_HOME" >/dev/null
assert_true "test $status -eq 0" "ls wrapper executes successfully"

du >/dev/null
assert_true "test $status -eq 0" "du wrapper executes successfully"

# Aliases that change directories.
set -l orig_pwd $PWD
ravy
assert_equal $PWD $expected_ravy_home "ravy jumps to chezmoi source-path"
cd $orig_pwd

set -l before_title (__fish_title_or_pwd)
cd $HOME
assert_equal (__fish_title_or_pwd) "~" "__fish_title_or_pwd replaces home with ~"
cd $orig_pwd

set -x FISH_TITLE "Custom"
assert_equal (__fish_title_or_pwd) "Custom" "__fish_title_or_pwd respects FISH_TITLE"
set -e FISH_TITLE

if test $__failures -eq 0
    echo "All config.fish tests passed"
end

exit $__failures
