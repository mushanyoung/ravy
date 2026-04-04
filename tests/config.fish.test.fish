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
            case system
                set target "$__ravy_test_tmp_home/usr/bin/mise"
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
EOF
  exit 0
fi
exit 0
"

    __write_stub dpkg-query "#!/usr/bin/env sh
if [ \"\$1\" = \"-S\" ] && [ \"\${RAVY_MISE_OWNER:-}\" = apt ] && [ \"\$2\" = \"\$HOME/usr/bin/mise\" ]; then
  printf 'mise: %s\n' \"\$2\"
  exit 0
fi
exit 1
"

    __write_stub apt "#!/usr/bin/env sh
printf \"%s\n\" \"\$*\" >> \"\$HOME/apt.log\"
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

function setup_private_overlay
    set -l private_home "$HOME/.local/share/ravy-private"
    mkdir -p \
        "$private_home/shell" \
        "$private_home/bin/common" \
        "$HOME/.config/ravy"

    printf "%s\n" "set -gx __RAVY_PRIVATE_COMMON 1" > "$private_home/shell/config.fish"
    cat "$repo_root/custom/dot_config/ravy/private_secrets.fish" > "$HOME/.config/ravy/secrets.fish"
    printf "%s\t%s\n%s\t%s\n" __RAVY_SECRETS_FISH " 1" RAVY_TSV_VALUE " value" > "$HOME/.config/ravy/secrets.tsv"
    printf "%s\n" "#!/usr/bin/env sh\nexit 0\n" > "$private_home/bin/common/private-helper"
    chmod +x "$private_home/bin/common/private-helper"
    printf "%s\n" $private_home
end

set -l expected_ravy_home (realpath "$repo_root")
set -l rendered_config "$HOME/.config/fish/config.fish"
set -l rendered_theme "$HOME/.config/fish/themes/ravy.theme"

mkdir -p (dirname $rendered_config)
mkdir -p (dirname $rendered_theme)
chezmoi cat "$rendered_config" > $rendered_config
chezmoi cat "$rendered_theme" > $rendered_theme

source $rendered_config

assert_equal $RAVY_HOME $expected_ravy_home "RAVY_HOME set from chezmoi source-path"
assert_true "not set -q RAVY_PRIVATE_HOME" "RAVY_PRIVATE_HOME stays unset when private repo is missing"
assert_contains "$RAVY_HOME/bin" $PATH "PATH includes RAVY_HOME/bin"
assert_contains "$HOME/bin" $PATH "PATH includes HOME/bin"
assert_contains "$HOME/.local/bin" $PATH "PATH includes HOME/.local/bin"
assert_contains 005fd7 $fish_color_command "fish theme sets command color"
assert_contains 555 $fish_color_autosuggestion "fish theme sets autosuggestion fallback color"
assert_contains brblack $fish_color_autosuggestion "fish theme sets autosuggestion named fallback"
assert_true "functions -q __starship_set_job_count" "starship prompt initialized"
assert_true "functions -q __ravy_zoxide_init" "zoxide hook initialized"
assert_true "functions -q _atuin_preexec" "atuin hook initialized"
assert_true "test \"$__RAVY_MISE_INIT\" = 1" "mise activated"
assert_true "functions -q d" "cd helper function defined"
assert_true "functions -q ravy" "ravy helper defined"
assert_true "functions -q ravyprivatecd" "private repo helper defined"
assert_true "functions -q chez" "chez alias defined"
assert_true "functions -q chezp" "chezp helper defined"
assert_true "functions -q ravysource" "ravysource helper defined"
assert_true "functions -q l" "generic alias 'l' defined"
assert_true "functions -q ravyc" "compat alias 'ravyc' defined"
assert_true "functions -q rgh" "rgh alias defined"
assert_true "functions -q mu" "mu alias defined"
assert_true "command -v mumu >/dev/null" "mumu command defined"
functions mu | string match -q '*mise upgrade*'
or fail "mu expands to mise upgrade"
functions rgh | string match -q '*rg -S --hidden*'
or fail "rgh expands to hidden rg search"
if command -q brew
    assert_true "functions -q bi" "brew alias is defined when command exists"
else
    assert_true "not functions -q bi" "brew alias is gated behind command availability"
end
if command -q apt
    assert_true "functions -q au" "apt alias is defined when command exists"
else
    assert_true "not functions -q au" "apt alias is gated behind command availability"
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

rm -f "$HOME/mise.log"
mu
grep -F "upgrade" "$HOME/mise.log" >/dev/null
or fail "mu runs mise upgrade"

rm -f "$HOME/mise.log" "$HOME/apt.log" "$HOME/sudo.log"
rm -rf "$HOME/opt/mise/lib" "$HOME/usr/lib"
mumu
grep -F "self-update" "$HOME/mise.log" >/dev/null
or fail "mumu uses mise self-update when not apt-managed"
grep -F "upgrade" "$HOME/mise.log" >/dev/null
or fail "mumu runs mise upgrade when not apt-managed"
test ! -f "$HOME/apt.log"
or fail "mumu should not call apt when not apt-managed"
test ! -f "$HOME/sudo.log"
or fail "mumu should not call sudo when not apt-managed"

rm -f "$HOME/mise.log" "$HOME/apt.log" "$HOME/sudo.log"
rm -rf "$HOME/usr/lib"
mkdir -p "$HOME/usr/bin"
printf "%s" "#!/usr/bin/env sh
if [ \"\$1\" = \"activate\" ]; then
  cat <<'EOF'
set -gx __RAVY_MISE_INIT 1
EOF
  exit 0
fi
printf \"%s\n\" \"\$*\" >> \"\$HOME/mise.log\"
exit 0
" > "$HOME/usr/bin/mise"
chmod +x "$HOME/usr/bin/mise"
ln -sfn "$HOME/usr/bin/mise" "$HOME/bin/mise"
mkdir -p "$HOME/usr/lib"
touch "$HOME/usr/lib/.disable-self-update"
set -gx RAVY_MISE_OWNER apt
mumu
set -e RAVY_MISE_OWNER
grep -F "apt update" "$HOME/sudo.log" >/dev/null
or fail "mumu uses sudo apt update when apt-managed"
grep -F "apt install --only-upgrade mise" "$HOME/sudo.log" >/dev/null
or fail "mumu uses sudo apt install --only-upgrade mise when apt-managed"
grep -F "update" "$HOME/apt.log" >/dev/null
or fail "apt stub records update when apt-managed"
grep -F "install --only-upgrade mise" "$HOME/apt.log" >/dev/null
or fail "apt stub records install command when apt-managed"
grep -F "upgrade" "$HOME/mise.log" >/dev/null
or fail "mumu runs mise upgrade when apt-managed"
if grep -F "self-update" "$HOME/mise.log" >/dev/null
    fail "mumu should not call mise self-update when apt-managed"
end

rm -f "$HOME/chezmoi.log"
assert_equal (chez source-path) $expected_ravy_home "chez resolves to public chezmoi source"
chez init >/dev/null 2>/dev/null
test ! -f "$HOME/.config/chezmoi/ravy-public.toml"
or fail "chez does not create a dedicated public config file"
grep -F "subcommand=source-path source=$expected_ravy_home config= state=" "$HOME/chezmoi.log" >/dev/null
or fail "chez keeps using the default chezmoi config/state"
grep -F "subcommand=init source=$expected_ravy_home config= state= config_path=" "$HOME/chezmoi.log" >/dev/null
or fail "chez init keeps using the default chezmoi config/state"

ravycustom >/dev/null 2>/dev/null
if test $status -eq 0
    fail "ravycustom should fail without a private repo"
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
assert_true "test \"$__RAVY_PRIVATE_COMMON\" = 1" "private common overlay loaded"
assert_true "test \"$__RAVY_SECRETS_FISH\" = 1" "managed secret fish overrides loaded"
assert_equal "$RAVY_TSV_VALUE" value "managed secret fish loader trims delimiter padding"
assert_true "command -v private-helper >/dev/null" "private helper command exists"
rm -f "$HOME/chezmoi.log"
assert_equal (chezp source-path) $private_home "chezp resolves to the private chezmoi source"
test -f "$HOME/.config/chezmoi/ravy-private.toml"
or fail "chezp seeds a dedicated private config file"
grep -F "seed = 1" "$HOME/.config/chezmoi/ravy-private.toml" >/dev/null
or fail "chezp copies the existing config into the dedicated private config"
chezp init >/dev/null 2>/dev/null
grep -F "subcommand=source-path source=$private_home config=$HOME/.config/chezmoi/ravy-private.toml state=$HOME/.config/chezmoi/ravy-private-state.boltdb" "$HOME/chezmoi.log" >/dev/null
or fail "chezp uses dedicated private config"
grep -F "subcommand=init source=$private_home config=$HOME/.config/chezmoi/ravy-private.toml state=$HOME/.config/chezmoi/ravy-private-state.boltdb config_path=$HOME/.config/chezmoi/ravy-private.toml" "$HOME/chezmoi.log" >/dev/null
or fail "chezp init regenerates the private config file"

set -l orig_pwd $PWD
ravycustom
assert_equal $PWD $private_home "ravycustom jumps to private repo"
cd $orig_pwd

set -l rendered_gitconfig "$HOME/.gitconfig"
chezmoi cat "$rendered_gitconfig" > "$rendered_gitconfig"
grep -F 'path = ~/.config/ravy/private.gitconfig' "$rendered_gitconfig" >/dev/null
or fail "rendered gitconfig is missing private include shim"

if test $__failures -eq 0
    echo "All config.fish tests passed"
end

exit $__failures
