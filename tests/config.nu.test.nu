#!/usr/bin/env nu

const script_path = (path self | path expand)
const repo_root = ($script_path | path dirname | path dirname)
let real_chezmoi = (which chezmoi | where type == external | get path | first)
let nu_bin = (which nu | where type == external | get path | first)

mut failures = []

def fail [message: string] {
    $env.__RAVY_NU_FAILURES = (($env.__RAVY_NU_FAILURES? | default []) | append $message)
}

def assert-true [condition: bool, message: string] {
    if not $condition {
        fail $message
    }
}

def assert-equal [actual: any, expected: any, message: string] {
    if $actual != $expected {
        fail $"($message): got '($actual)' expected '($expected)'"
    }
}

def write-file [path: string, content: string] {
    mkdir ($path | path dirname)
    $content | save -f $path
}

def write-stub [path: string, body: string] {
    write-file $path $body
    chmod +x $path
}

def render-config [tmp_home: string, target: string] {
    let rendered = (do {
        run-external $real_chezmoi "-S" $repo_root "-D" $tmp_home "cat" $target
    } | complete)
    $rendered.stdout | save -f $target
}

let tmp_home = (
    do { run-external "mktemp" "-d" $"($repo_root)/.tmp_nu_home.XXXXXX" }
    | complete
    | get stdout
    | str trim
)

mkdir $"($tmp_home)/bin"
mkdir $"($tmp_home)/.config/nushell"
mkdir $"($tmp_home)/.config/chezmoi"
mkdir $"($tmp_home)/.config/ravy"
mkdir $"($tmp_home)/.local/bin"
mkdir $"($tmp_home)/.local/share"

"seed = 1\n" | save -f $"($tmp_home)/.config/chezmoi/chezmoi.toml"

write-stub $"($tmp_home)/bin/starship" '#!/usr/bin/env sh
if [ "$1" = "prompt" ]; then
  exit 0
fi
if [ "$1" = "init" ] && [ "$2" = "nu" ]; then
  cat <<'"'"'EOF'"'"'
export-env {
  $env.__RAVY_STARSHIP_INIT = "1"
}
EOF
  exit 0
fi
exit 0
'

write-stub $"($tmp_home)/bin/zoxide" '#!/usr/bin/env sh
case "$1" in
  query)
    if [ "$2" = "--interactive" ]; then
      printf "%s\n" "$HOME"
    else
      printf "%s\n" "$HOME"
    fi
    exit 0
    ;;
  add)
    exit 0
    ;;
  init)
    cat <<'"'"'EOF'"'"'
export-env {
  $env.__RAVY_ZOXIDE_INIT = "1"
}
EOF
    exit 0
    ;;
esac
exit 0
'

write-stub $"($tmp_home)/bin/atuin" '#!/usr/bin/env sh
case "$1" in
  history)
    case "$2" in
      start)
        printf "%s\n" "test-history-id"
        exit 0
        ;;
      end)
        exit 0
        ;;
    esac
    ;;
  search)
    printf "%s\n" "echo from-atuin"
    exit 0
    ;;
  init)
    cat <<'"'"'EOF'"'"'
export-env {
  $env.__RAVY_ATUIN_INIT = "1"
}
EOF
    exit 0
    ;;
esac
exit 0
'

write-stub $"($tmp_home)/bin/mise" '#!/usr/bin/env sh
if [ "$1" = "upgrade" ]; then
  printf "%s\n" "$*" >> "$HOME/mise.log"
  exit 0
fi
if [ "$1" = "hook-env" ]; then
  cat <<'"'"'EOF'"'"'
set,PATH,'"$tmp_home"'/bin:'"$tmp_home"'/.local/bin:'"$repo_root"'/bin
EOF
  exit 0
fi
if [ "$1" = "activate" ]; then
  cat <<'"'"'EOF'"'"'
$env.__RAVY_MISE_INIT = "1"
EOF
  exit 0
fi
printf "%s\n" "$*" >> "$HOME/mise.log"
exit 0
'

write-stub $"($tmp_home)/bin/fd" '#!/usr/bin/env sh
if [ "$1" = "-t" ] && [ "$2" = "d" ]; then
  printf "%s\n" .
  printf "%s\n" "$HOME"
  exit 0
fi
printf "%s\n" "$HOME/example.txt"
exit 0
'

write-stub $"($tmp_home)/bin/fzf" '#!/usr/bin/env sh
awk '"'"'NF { print; exit }'"'"'
'

write-stub $"($tmp_home)/bin/rg" '#!/usr/bin/env sh
printf "%s\n" "$HOME/example.txt"
'

write-stub $"($tmp_home)/bin/open" '#!/usr/bin/env sh
exit 0
'

write-stub $"($tmp_home)/bin/eza" '#!/usr/bin/env sh
exit 0
'

write-file $"($tmp_home)/example.txt" "example\n"

let rendered_env = $"($tmp_home)/.config/nushell/env.nu"
let rendered_config = $"($tmp_home)/.config/nushell/config.nu"
render-config $tmp_home $rendered_env
render-config $tmp_home $rendered_config

mkdir $"($tmp_home)/work/one/two"

let probe = (
    do {
        with-env {
            HOME: $tmp_home
            XDG_CONFIG_HOME: $"($tmp_home)/.config"
            XDG_DATA_HOME: $"($tmp_home)/.local/share"
            PATH: [$"($tmp_home)/bin" "/usr/bin" "/bin"]
            RAVY_HOST: "test-host"
            RAVY_PRIVATE_HOME: $"($tmp_home)/.missing-private"
            RAVY_SKIP_BREW: "1"
        } {
            run-external $nu_bin "--env-config" $rendered_env "--config" $rendered_config "-i" "-c" $'
                cd "'"($tmp_home)"'/work/one/two"
                cd "'"($tmp_home)"'/work/one/two/missing/file.txt"
                let nearest = $env.PWD
                cd -
                let bounced = $env.PWD
                mu
                {
                    RAVY_HOME: $env.RAVY_HOME
                    RAVY_PRIVATE_HOME: ($env.RAVY_PRIVATE_HOME? | default null)
                    PATH: $env.PATH
                    PROMPT_COMMAND: ("PROMPT_COMMAND" in $env)
                    PROMPT_INDICATOR: ($env.PROMPT_INDICATOR? | default null)
                    __RAVY_MISE_INIT: ($env.__RAVY_MISE_INIT? | default null)
                    commands: (["ravysource" "ravy" "z" "zi" "mu" "rgh"] | each {|name| { name: $name, exists: ((which $name | length) > 0) } })
                    keybindings: ($env.config.keybindings | get name)
                    nearest: $nearest
                    bounced: $bounced
                } | to json -r
            '
        }
    }
    | complete
)

assert-equal $probe.exit_code 0 "nushell probe command failed"
if $probe.exit_code != 0 {
    if not (($probe.stderr | default "" | str trim) | is-empty) {
        fail $"nushell probe stderr: ($probe.stderr | str trim)"
    }
}

if $probe.exit_code == 0 and not (($probe.stdout | default "" | str trim) | is-empty) {
    let data = ($probe.stdout | from json)
    assert-equal $data.RAVY_HOME $repo_root "RAVY_HOME should resolve to repo root"
    assert-equal $data.RAVY_PRIVATE_HOME null "RAVY_PRIVATE_HOME should stay unset for an invalid explicit path"
    assert-true (($data.PATH | any {|entry| $entry == $"($repo_root)/bin" })) "PATH should include repo bin"
    assert-true (($data.PATH | any {|entry| $entry == $"($tmp_home)/.local/bin" })) "PATH should include HOME/.local/bin"
    assert-true $data.PROMPT_COMMAND "PROMPT_COMMAND should be configured"
    assert-true ($data.PROMPT_INDICATOR == "") "PROMPT_INDICATOR should be set by the prompt integration"
    assert-equal $data.__RAVY_MISE_INIT "1" "mise integration marker should be set"

    for row in $data.commands {
        assert-true $row.exists $"command should exist: ($row.name)"
    }

    for name in ["ravy_history" "atuin" "ravy_history_token_backward" "ravy_history_token_forward"] {
        assert-true (($data.keybindings | any {|binding| $binding == $name })) $"keybinding should exist: ($name)"
    }

    assert-equal $data.nearest $"($tmp_home)/work/one/two" "cd should keep the nearest existing directory"
    assert-equal $data.bounced $"($tmp_home)/work/one/two" "cd - should bounce back to the previous directory"

    let mise_log = (open $"($tmp_home)/mise.log" | lines)
    assert-true (($mise_log | any {|line| $line | str contains "upgrade" })) "mu should call mise upgrade"
}

let failures = ($env.__RAVY_NU_FAILURES? | default [])
if ($failures | is-empty) {
    print "All config.nu tests passed"
    exit 0
}

for message in $failures {
    print -e $"FAIL ($message)"
}
exit ($failures | length)
