#!/usr/bin/env nu

const script_path = (path self | path expand)
const repo_root = ($script_path | path dirname | path dirname)
let real_chezmoi = (which chezmoi | where type == external | get path | first)
let nu_bin = (
    which nu
    | where type == external
    | get path
    | append $nu.current-exe
    | first
)

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

def maybe-lines [path: string] {
    if ($path | path exists) {
        open $path | lines
    } else {
        []
    }
}

def maybe-text [path: string] {
    if ($path | path exists) {
        open --raw $path
    } else {
        ""
    }
}

def clear-logs [tmp_home: string] {
    rm -f $"($tmp_home)/fd.log" $"($tmp_home)/fzf.log" $"($tmp_home)/fzf.stdin" $"($tmp_home)/rg.log" $"($tmp_home)/nvim.log" $"($tmp_home)/nvim-headless.log" $"($tmp_home)/chezmoi.log"
}

def run-probe [tmp_home: string, rendered_env: string, rendered_config: string, script: string, extra_env?: record] {
    let env_vars = ({
        HOME: $tmp_home
        XDG_CONFIG_HOME: $"($tmp_home)/.config"
        XDG_DATA_HOME: $"($tmp_home)/.local/share"
        PATH: [$"($tmp_home)/bin" "/usr/bin" "/bin"]
        RAVY_HOST: "test-host"
        RAVY_PRIVATE_HOME: $"($tmp_home)/.missing-private"
        RAVY_SKIP_BREW: "1"
    } | merge ($extra_env | default {}))

    do {
        with-env $env_vars {
            run-external $nu_bin "--env-config" $rendered_env "--config" $rendered_config "-i" "-c" $script
        }
    } | complete
}

def assert-probe-ok [probe: record, message: string] {
    assert-equal $probe.exit_code 0 $message
    if $probe.exit_code != 0 {
        if not (($probe.stderr | default "" | str trim) | is-empty) {
            fail $"($message): ($probe.stderr | str trim)"
        }
    }
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
$"__RAVY_SECRETS_NU(char tab) 1\nRAVY_TSV_VALUE(char tab) value\n" | save -f $"($tmp_home)/.config/ravy/secrets.tsv"

write-stub $"($tmp_home)/bin/chezmoi" ([
    '#!/usr/bin/env sh'
    $'source_path="($repo_root)"'
    "config_path=''"
    "state_path=''"
    "subcommand=''"
    'while [ "$#" -gt 0 ]; do'
    '  case "$1" in'
    '    -S|--source)'
    '      source_path="$2"'
    '      shift 2'
    '      ;;'
    '    -c|--config)'
    '      config_path="$2"'
    '      shift 2'
    '      ;;'
    '    --persistent-state)'
    '      state_path="$2"'
    '      shift 2'
    '      ;;'
    '    source-path|init|apply|diff|status)'
    '      subcommand="$1"'
    '      shift'
    '      break'
    '      ;;'
    '    *)'
    '      shift'
    '      ;;'
    '  esac'
    'done'
    'if [ "$subcommand" = "source-path" ]; then'
    '  printf "%s\n" "subcommand=source-path source=$source_path config=$config_path state=$state_path" >> "$HOME/chezmoi.log"'
    '  printf "%s\n" "$source_path"'
    '  exit 0'
    'fi'
    'if [ "$subcommand" = "init" ]; then'
    "  init_config_path=''"
    '  while [ "$#" -gt 0 ]; do'
    '    case "$1" in'
    '      -C|--config-path)'
    '        init_config_path="$2"'
    '        shift 2'
    '        ;;'
    '      *)'
    '        shift'
    '        ;;'
    '    esac'
    '  done'
    '  printf "%s\n" "subcommand=init source=$source_path config=$config_path state=$state_path config_path=$init_config_path" >> "$HOME/chezmoi.log"'
    '  exit 0'
    'fi'
    'if [ "$subcommand" = "apply" ] || [ "$subcommand" = "diff" ] || [ "$subcommand" = "status" ]; then'
    '  printf "%s\n" "subcommand=$subcommand source=$source_path config=$config_path state=$state_path" >> "$HOME/chezmoi.log"'
    '  exit 0'
    'fi'
    'exit 0'
] | str join (char newline))

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
printf "%s\n" "$*" >> "$HOME/fd.log"
if [ "$1" = "-H" ] && [ "$2" = "-t" ] && [ "$3" = "d" ]; then
  printf "%s\n" "$HOME/.hidden-dir"
  exit 0
fi
if [ "$1" = "-t" ] && [ "$2" = "d" ]; then
  printf "%s\n" "$HOME/dir-one"
  exit 0
fi
if [ "$1" = "-H" ] && [ "$2" = "-t" ] && [ "$3" = "f" ]; then
  printf "%s\n" "$HOME/.hidden-file.txt"
  exit 0
fi
if [ "$1" = "-t" ] && [ "$2" = "f" ]; then
  printf "%s\n" "$HOME/example.txt"
  exit 0
fi
printf "%s\n" "$HOME/example.txt"
exit 0
'

write-stub $"($tmp_home)/bin/fzf" '#!/usr/bin/env sh
printf "%s\n" "$*" >> "$HOME/fzf.log"
cat > "$HOME/fzf.stdin"
printf "%s" "${RAVY_TEST_FZF_OUT:-}"
'

write-stub $"($tmp_home)/bin/rg" '#!/usr/bin/env sh
printf "%s\n" "$*" >> "$HOME/rg.log"
printf "%s\n" "$HOME/rg-match.txt"
exit 0
'

write-stub $"($tmp_home)/bin/open" '#!/usr/bin/env sh
exit 0
'

write-stub $"($tmp_home)/bin/bat" '#!/usr/bin/env sh
exit 0
'

write-stub $"($tmp_home)/bin/nvim" '#!/usr/bin/env sh
if [ "$1" = "--headless" ]; then
  printf "%s\n" "$*" >> "$HOME/nvim-headless.log"
  printf "%s\n" "$HOME/oldfile.txt"
  exit 0
fi
printf "%s\n" "$*" >> "$HOME/nvim.log"
exit 0
'

write-stub $"($tmp_home)/bin/eza" '#!/usr/bin/env sh
exit 0
'

write-file $"($tmp_home)/example.txt" "example\n"
write-file $"($tmp_home)/.hidden-file.txt" "hidden\n"
write-file $"($tmp_home)/oldfile.txt" "old\n"
write-file $"($tmp_home)/rg-match.txt" "match\n"
mkdir $"($tmp_home)/dir-one"
mkdir $"($tmp_home)/.hidden-dir"
let private_home = $"($tmp_home)/private-repo"
mkdir $private_home

let rendered_env = $"($tmp_home)/.config/nushell/env.nu"
let rendered_config = $"($tmp_home)/.config/nushell/config.nu"
let rendered_login = $"($tmp_home)/.config/nushell/login.nu"
render-config $tmp_home $rendered_env
render-config $tmp_home $rendered_config
render-config $tmp_home $rendered_login

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
                    __RAVY_SECRETS_NU: ($env.__RAVY_SECRETS_NU? | default null)
                    RAVY_TSV_VALUE: ($env.RAVY_TSV_VALUE? | default null)
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
    assert-equal $data.__RAVY_SECRETS_NU "1" "secrets.tsv should load the nu marker"
    assert-equal $data.RAVY_TSV_VALUE "value" "secrets.tsv loader should trim delimiter padding"

    for row in $data.commands {
        assert-true $row.exists $"command should exist: ($row.name)"
    }

    for name in [
        "ravy_history"
        "ravy_files"
        "ravy_files_hidden"
        "ravy_dirs"
        "ravy_dirs_hidden"
        "ravy_nvim_oldfiles"
        "ravy_rg"
        "atuin"
        "ravy_history_token_backward"
        "ravy_history_token_forward"
    ] {
        assert-true (($data.keybindings | any {|binding| $binding == $name })) $"keybinding should exist: ($name)"
    }

    assert-equal $data.nearest $"($tmp_home)/work/one/two" "cd should keep the nearest existing directory"
    assert-equal $data.bounced $"($tmp_home)/work/one/two" "cd - should bounce back to the previous directory"

    let mise_log = (open $"($tmp_home)/mise.log" | lines)
    assert-true (($mise_log | any {|line| $line | str contains "upgrade" })) "mu should call mise upgrade"
}

let public_chez_probe = (run-probe $tmp_home $rendered_env $rendered_config '
    rm -f $"($env.HOME)/chezmoi.log"
    let source_path = (chez source-path | str trim)
    let source_log = (open $"($env.HOME)/chezmoi.log" | lines)
    rm -f $"($env.HOME)/chezmoi.log"
    chez diff --exclude scripts
    let diff_log = (open $"($env.HOME)/chezmoi.log" | lines)
    rm -f $"($env.HOME)/chezmoi.log"
    chez status --path-style absolute
    let status_log = (open $"($env.HOME)/chezmoi.log" | lines)
    rm -f $"($env.HOME)/chezmoi.log"
    chez apply
    let apply_log = (open $"($env.HOME)/chezmoi.log" | lines)
    {
        source_path: $source_path
        source_log: $source_log
        diff_log: $diff_log
        status_log: $status_log
        apply_log: $apply_log
    } | to json -r
')
assert-probe-ok $public_chez_probe "nushell public chez probe command failed"
if $public_chez_probe.exit_code == 0 and not (($public_chez_probe.stdout | default "" | str trim) | is-empty) {
    let public_chez = ($public_chez_probe.stdout | from json)
    assert-equal $public_chez.source_path $repo_root "chez source-path should stay public when private is missing"
    assert-equal ($public_chez.source_log | length) 1 "public chez source-path should log once"
    assert-equal ($public_chez.source_log | first) $"subcommand=source-path source=($repo_root) config= state=" "public chez source-path should use the default config/state"
    assert-equal ($public_chez.diff_log | length) 1 "public chez diff should only run once without a private repo"
    assert-equal ($public_chez.diff_log | first) $"subcommand=diff source=($repo_root) config= state=" "public chez diff should stay public-only when private is missing"
    assert-equal ($public_chez.status_log | length) 1 "public chez status should only run once without a private repo"
    assert-equal ($public_chez.status_log | first) $"subcommand=status source=($repo_root) config= state=" "public chez status should stay public-only when private is missing"
    assert-equal ($public_chez.apply_log | length) 1 "public chez apply should only run once without a private repo"
    assert-equal ($public_chez.apply_log | first) $"subcommand=apply source=($repo_root) config= state=" "public chez apply should stay public-only when private is missing"
}

let private_chez_probe = (run-probe $tmp_home $rendered_env $rendered_config '
    let private_config = $"($env.HOME)/.config/chezmoi/ravy-private.toml"
    let private_state = $"($env.HOME)/.config/chezmoi/ravy-private-state.boltdb"

    rm -f $"($env.HOME)/chezmoi.log"
    let public_source_path = (chez source-path | str trim)
    let public_source_log = (open $"($env.HOME)/chezmoi.log" | lines)

    rm -f $"($env.HOME)/chezmoi.log"
    let private_source_path = (chez private source-path | str trim)
    let private_source_log = (open $"($env.HOME)/chezmoi.log" | lines)

    rm -f $"($env.HOME)/chezmoi.log"
    let compat_source_path = (chezp source-path | str trim)
    let compat_source_log = (open $"($env.HOME)/chezmoi.log" | lines)

    let private_config_exists = ($private_config | path exists)
    let private_config_text = (open --raw $private_config)

    rm -f $"($env.HOME)/chezmoi.log"
    chezp init
    let init_log = (open $"($env.HOME)/chezmoi.log" | lines)

    rm -f $"($env.HOME)/chezmoi.log"
    chez diff --exclude scripts
    let dual_diff_log = (open $"($env.HOME)/chezmoi.log" | lines)

    rm -f $"($env.HOME)/chezmoi.log"
    chez status --path-style absolute
    let dual_status_log = (open $"($env.HOME)/chezmoi.log" | lines)

    rm -f $"($env.HOME)/chezmoi.log"
    chez apply
    let dual_apply_log = (open $"($env.HOME)/chezmoi.log" | lines)

    rm -f $"($env.HOME)/chezmoi.log"
    chez diff ~/.config/ravy/secrets.tsv
    let scoped_public_diff_log = (open $"($env.HOME)/chezmoi.log" | lines)

    rm -f $"($env.HOME)/chezmoi.log"
    chez private diff ~/.config/ravy/secrets.tsv
    let scoped_private_diff_log = (open $"($env.HOME)/chezmoi.log" | lines)

    {
        private_state: $private_state
        public_source_path: $public_source_path
        public_source_log: $public_source_log
        private_source_path: $private_source_path
        private_source_log: $private_source_log
        compat_source_path: $compat_source_path
        compat_source_log: $compat_source_log
        private_config_exists: $private_config_exists
        private_config_text: $private_config_text
        init_log: $init_log
        dual_diff_log: $dual_diff_log
        dual_status_log: $dual_status_log
        dual_apply_log: $dual_apply_log
        scoped_public_diff_log: $scoped_public_diff_log
        scoped_private_diff_log: $scoped_private_diff_log
    } | to json -r
' {
    RAVY_PRIVATE_HOME: $private_home
})
assert-probe-ok $private_chez_probe "nushell private chez probe command failed"
if $private_chez_probe.exit_code == 0 and not (($private_chez_probe.stdout | default "" | str trim) | is-empty) {
    let private_chez = ($private_chez_probe.stdout | from json)
    let private_config_path = $"($tmp_home)/.config/chezmoi/ravy-private.toml"
    let private_state_path = $"($tmp_home)/.config/chezmoi/ravy-private-state.boltdb"

    assert-equal $private_chez.public_source_path $repo_root "chez source-path should stay public when private is configured"
    assert-equal ($private_chez.public_source_log | length) 1 "chez source-path should log one public invocation"
    assert-equal ($private_chez.public_source_log | first) $"subcommand=source-path source=($repo_root) config= state=" "chez source-path should keep the default public config/state"
    assert-equal $private_chez.private_source_path $private_home "chez private source-path should resolve to the private repo"
    assert-equal ($private_chez.private_source_log | length) 1 "chez private source-path should log once"
    assert-equal ($private_chez.private_source_log | first) $"subcommand=source-path source=($private_home) config=($private_config_path) state=($private_state_path)" "chez private source-path should use the dedicated private config/state"
    assert-equal $private_chez.compat_source_path $private_home "chezp should remain a compatibility alias for the private repo"
    assert-equal ($private_chez.compat_source_log | length) 1 "chezp source-path should log once"
    assert-equal ($private_chez.compat_source_log | first) $"subcommand=source-path source=($private_home) config=($private_config_path) state=($private_state_path)" "chezp should use the dedicated private config/state"
    assert-true $private_chez.private_config_exists "private chez wrapper should seed the dedicated private config file"
    assert-true ($private_chez.private_config_text | str contains "seed = 1") "private chez wrapper should seed the private config from the default config"
    assert-equal ($private_chez.init_log | length) 1 "chezp init should log once"
    assert-equal ($private_chez.init_log | first) $"subcommand=init source=($private_home) config=($private_config_path) state=($private_state_path) config_path=($private_config_path)" "chezp init should keep the dedicated private config/state"
    assert-equal ($private_chez.dual_diff_log | length) 2 "chez diff should fan out to both repos when private is configured"
    assert-equal ($private_chez.dual_diff_log | get 0) $"subcommand=diff source=($repo_root) config= state=" "chez diff should run the public repo first"
    assert-equal ($private_chez.dual_diff_log | get 1) $"subcommand=diff source=($private_home) config=($private_config_path) state=($private_state_path)" "chez diff should run the private repo second"
    assert-equal ($private_chez.dual_status_log | length) 2 "chez status should fan out to both repos when private is configured"
    assert-equal ($private_chez.dual_status_log | get 0) $"subcommand=status source=($repo_root) config= state=" "chez status should run the public repo first"
    assert-equal ($private_chez.dual_status_log | get 1) $"subcommand=status source=($private_home) config=($private_config_path) state=($private_state_path)" "chez status should run the private repo second"
    assert-equal ($private_chez.dual_apply_log | length) 2 "chez apply should fan out to both repos when private is configured"
    assert-equal ($private_chez.dual_apply_log | get 0) $"subcommand=apply source=($repo_root) config= state=" "chez apply should run the public repo first"
    assert-equal ($private_chez.dual_apply_log | get 1) $"subcommand=apply source=($private_home) config=($private_config_path) state=($private_state_path)" "chez apply should run the private repo second"
    assert-equal ($private_chez.scoped_public_diff_log | length) 1 "path-scoped chez diff should stay public-only"
    assert-equal ($private_chez.scoped_public_diff_log | first) $"subcommand=diff source=($repo_root) config= state=" "path-scoped chez diff should not fan out to the private repo"
    assert-equal ($private_chez.scoped_private_diff_log | length) 1 "chez private diff should only run once"
    assert-equal ($private_chez.scoped_private_diff_log | first) $"subcommand=diff source=($private_home) config=($private_config_path) state=($private_state_path)" "chez private diff should target the private repo explicitly"
}

clear-logs $tmp_home
let files_probe = (run-probe $tmp_home $rendered_env $rendered_config 'ravy-fzf-files' {
    RAVY_TEST_FZF_OUT: $"($tmp_home)/example.txt"
})
assert-probe-ok $files_probe "nushell files probe command failed"
let files_fzf_log = (maybe-lines $"($tmp_home)/fzf.log")
let files_fd_log = (maybe-lines $"($tmp_home)/fd.log")
let files_nvim_log = (maybe-lines $"($tmp_home)/nvim.log")
assert-true (($files_fd_log | any {|line| $line | str contains "-t f" })) "file picker should ask fd for files"
assert-true (($files_fzf_log | any {|line| $line | str contains "--preview bat --color=always --style=numbers --line-range=:500 -- {}" })) "file picker should use bat preview"
assert-true (($files_nvim_log | any {|line| $line == $"-- ($tmp_home)/example.txt" })) "file picker should open the selected file in nvim"
assert-true ((maybe-text $"($tmp_home)/fzf.stdin") | str contains $"($tmp_home)/example.txt") "file picker should feed fd results into fzf"

clear-logs $tmp_home
let hidden_files_probe = (run-probe $tmp_home $rendered_env $rendered_config 'ravy-fzf-files-hidden' {
    RAVY_TEST_FZF_OUT: $"($tmp_home)/.hidden-file.txt"
})
assert-probe-ok $hidden_files_probe "nushell hidden files probe command failed"
let hidden_files_fd_log = (maybe-lines $"($tmp_home)/fd.log")
let hidden_files_nvim_log = (maybe-lines $"($tmp_home)/nvim.log")
assert-true (($hidden_files_fd_log | any {|line| $line | str contains "-H -t f" })) "hidden file picker should ask fd for hidden files"
assert-true (($hidden_files_nvim_log | any {|line| $line == $"-- ($tmp_home)/.hidden-file.txt" })) "hidden file picker should open the selected hidden file in nvim"

clear-logs $tmp_home
let dirs_probe = (run-probe $tmp_home $rendered_env $rendered_config 'cd $env.HOME; ravy-fzf-dirs; print $env.PWD' {
    RAVY_TEST_FZF_OUT: $"($tmp_home)/dir-one"
})
assert-probe-ok $dirs_probe "nushell dirs probe command failed"
assert-equal ($dirs_probe.stdout | str trim) $"($tmp_home)/dir-one" "dir picker should cd into the selected directory"
let dirs_fd_log = (maybe-lines $"($tmp_home)/fd.log")
assert-true (($dirs_fd_log | any {|line| $line | str contains "-t d" })) "dir picker should ask fd for directories"

clear-logs $tmp_home
let hidden_dirs_probe = (run-probe $tmp_home $rendered_env $rendered_config 'cd $env.HOME; ravy-fzf-dirs-hidden; print $env.PWD' {
    RAVY_TEST_FZF_OUT: $"($tmp_home)/.hidden-dir"
})
assert-probe-ok $hidden_dirs_probe "nushell hidden dirs probe command failed"
assert-equal ($hidden_dirs_probe.stdout | str trim) $"($tmp_home)/.hidden-dir" "hidden dir picker should cd into the selected hidden directory"
let hidden_dirs_fd_log = (maybe-lines $"($tmp_home)/fd.log")
assert-true (($hidden_dirs_fd_log | any {|line| $line | str contains "-H -t d" })) "hidden dir picker should ask fd for hidden directories"

clear-logs $tmp_home
let history_probe = (run-probe $tmp_home $rendered_env $rendered_config 'commandline edit "ec"; ravy-fzf-history; print (commandline)' {
    RAVY_TEST_FZF_OUT: "echo from history"
})
assert-probe-ok $history_probe "nushell history probe command failed"
assert-equal ($history_probe.stdout | str trim) "echo from history" "history picker should replace the commandline with the selected command"
let history_fzf_log = (maybe-lines $"($tmp_home)/fzf.log")
assert-true (($history_fzf_log | any {|line| $line | str contains "-q ec" })) "history picker should seed fzf with the current commandline"

clear-logs $tmp_home
let nvim_probe = (run-probe $tmp_home $rendered_env $rendered_config 'ravy-fzf-nvim' {
    RAVY_TEST_FZF_OUT: $"($tmp_home)/oldfile.txt"
})
assert-probe-ok $nvim_probe "nushell nvim oldfiles probe command failed"
let nvim_headless_log = (maybe-lines $"($tmp_home)/nvim-headless.log")
let nvim_open_log = (maybe-lines $"($tmp_home)/nvim.log")
assert-true (($nvim_headless_log | any {|line| $line | str contains "--headless" })) "nvim oldfiles picker should query nvim headlessly"
assert-true (($nvim_open_log | any {|line| $line == $"-- ($tmp_home)/oldfile.txt" })) "nvim oldfiles picker should open the selected oldfile in nvim"

clear-logs $tmp_home
let rg_probe = (run-probe $tmp_home $rendered_env $rendered_config 'commandline edit "Needle"; ravy-fzf-rg' {
    RAVY_TEST_FZF_OUT: $"($tmp_home)/rg-match.txt"
})
assert-probe-ok $rg_probe "nushell rg probe command failed"
let rg_log = (maybe-lines $"($tmp_home)/rg.log")
let rg_nvim_log = (maybe-lines $"($tmp_home)/nvim.log")
assert-true (($rg_log | any {|line| $line | str contains "-il -- Needle" })) "rg picker should search using the current commandline"
assert-true (($rg_nvim_log | any {|line| $line == $"-- ($tmp_home)/rg-match.txt" })) "rg picker should open the selected search result in nvim"

clear-logs $tmp_home
let empty_files_probe = (run-probe $tmp_home $rendered_env $rendered_config 'ravy-fzf-files' {
    RAVY_TEST_FZF_OUT: ""
})
assert-probe-ok $empty_files_probe "nushell empty files probe command failed"
assert-true ((maybe-lines $"($tmp_home)/nvim.log") | is-empty) "file picker should be a no-op when fzf returns nothing"

let login_probe = (
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
            run-external $nu_bin "-l" "-c" $'
                {
                    login: ($env.__RAVY_LOGIN_INIT? | default null)
                    config_path: $nu.config-path
                    env_path: $nu.env-path
                } | to json -r
            '
        }
    }
    | complete
)

assert-equal $login_probe.exit_code 0 "nushell login probe command failed"
if $login_probe.exit_code != 0 {
    if not (($login_probe.stderr | default "" | str trim) | is-empty) {
        fail $"nushell login probe stderr: ($login_probe.stderr | str trim)"
    }
}

if $login_probe.exit_code == 0 and not (($login_probe.stdout | default "" | str trim) | is-empty) {
    let data = ($login_probe.stdout | from json)
    assert-equal $data.login "1" "login.nu should set the login marker"
    assert-equal $data.config_path $rendered_config "login shell should use the canonical config path"
    assert-equal $data.env_path $rendered_env "login shell should use the canonical env path"
}

let failures = ($env.__RAVY_NU_FAILURES? | default [])
if ($failures | is-empty) {
    print "All config.nu tests passed"
    exit 0
}

for message in $failures {
    print -e $"FAIL ($message)"
}
exit 1
