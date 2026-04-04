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
    rm -f $"($tmp_home)/fd.log" $"($tmp_home)/fzf.log" $"($tmp_home)/fzf.stdin" $"($tmp_home)/rg.log" $"($tmp_home)/nvim.log" $"($tmp_home)/nvim-headless.log"
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
