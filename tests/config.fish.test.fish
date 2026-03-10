#!/usr/bin/env fish

set -l script_path (realpath (status --current-filename))
set -l repo_root (realpath (dirname $script_path)/..)

if not set -q RAVY_TEST_CHILD
    set -l tmp_home (mktemp -d "$repo_root/.tmp_fish_home.XXXXXX")
    set -g stub_bin "$tmp_home/bin"
    set -l real_chezmoi (command -s chezmoi)

    mkdir -p $stub_bin \
        "$tmp_home/.config/fish" \
        "$tmp_home/.config/ravy" \
        "$tmp_home/.local/bin" \
        "$tmp_home/.local/share"

    function __write_stub --argument-names name body
        set -l target "$stub_bin/$name"
        printf "%s" "$body" >$target
        chmod +x $target
    end

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

    __write_stub mise "#!/usr/bin/env sh
if [ \"\$1\" = \"activate\" ]; then
  cat <<'EOF'
set -gx __RAVY_MISE_INIT 1
EOF
  exit 0
fi
exit 0
"

    __write_stub chezmoi "#!/usr/bin/env sh
source_path=\"$repo_root\"
while [ \"\$#\" -gt 0 ]; do
  case \"\$1\" in
    -S|--source)
      source_path=\"\$2\"
      shift 2
      ;;
    *)
      break
      ;;
  esac
done
if [ \"\$1\" = \"source-path\" ]; then
  echo \"\$source_path\"
  exit 0
fi
if [ \"\$1\" = \"cat\" ]; then
  shift
  exec \"$real_chezmoi\" -S \"$repo_root\" -D \"$tmp_home\" cat \"\$@\"
fi
exit 0
"

    __write_stub eza "#!/usr/bin/env sh
exit 0
"

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
        rm -rf $tmp_home
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
    printf "%s\n" "set -gx __RAVY_SECRETS_FISH 1" > "$HOME/.config/ravy/secrets.fish"
    printf "%s\n" "#!/usr/bin/env sh\nexit 0\n" > "$private_home/bin/common/private-helper"
    chmod +x "$private_home/bin/common/private-helper"
    printf "%s\n" $private_home
end

set -l expected_ravy_home (realpath "$repo_root")
set -l rendered_config "$HOME/.config/fish/config.fish"

mkdir -p (dirname $rendered_config)
chezmoi cat "$rendered_config" > $rendered_config

source $rendered_config

assert_equal $RAVY_HOME $expected_ravy_home "RAVY_HOME set from chezmoi source-path"
assert_true "not set -q RAVY_PRIVATE_HOME" "RAVY_PRIVATE_HOME stays unset when private repo is missing"
assert_contains "$RAVY_HOME/bin" $PATH "PATH includes RAVY_HOME/bin"
assert_contains "$HOME/bin" $PATH "PATH includes HOME/bin"
assert_contains "$HOME/.local/bin" $PATH "PATH includes HOME/.local/bin"
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
assert_true "not functions -q bi" "brew alias is gated behind command availability"
assert_true "not functions -q au" "apt alias is gated behind command availability"
assert_true "not functions -q pupu" "pacman alias is gated behind command availability"
assert_true "command -v ep >/dev/null" "ep helper exists"
assert_true "command -v jl >/dev/null" "jl helper exists"
assert_true "command -v lines >/dev/null" "lines helper exists"
assert_true "command -v downcase-exts >/dev/null" "downcase-exts helper exists"
assert_equal (chez source-path) $expected_ravy_home "chez resolves to public chezmoi source"

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
assert_true "command -v private-helper >/dev/null" "private helper command exists"
assert_equal (chezp source-path) $private_home "chezp resolves to the private chezmoi source"

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
