set -x RAVY_HOME (dirname (status --current-filename))

# paths operations
function prepend_to_path
    for arg in $argv
        fish_add_path -m -p -P -g $arg
    end
end

prepend_to_path "$RAVY_HOME/bin"
prepend_to_path "$HOME/.local/bin"

for brewprefix in /opt/homebrew /usr/local /home/linuxbrew/.linuxbrew "$HOME/.brew" "$HOME/.linuxbrew"
    if test -f "$brewprefix/bin/brew"
        set -gx HOMEBREW_PREFIX "$brewprefix"
        set -gx HOMEBREW_CELLAR "$brewprefix/Cellar"
        set -gx HOMEBREW_REPOSITORY "$brewprefix/Homebrew"
        set -gx HOMEBREW_NO_ANALYTICS 1
        set -q MANPATH; or set MANPATH ''
        set -gx MANPATH "$HOMEBREW_PREFIX/share/man" $MANPATH
        set -q INFOPATH; or set INFOPATH ''
        set -gx INFOPATH "$HOMEBREW_PREFIX/share/info" $INFOPATH

        if test -d "$brewprefix/opt/ruby/bin"
            prepend_to_path "$brewprefix/opt/ruby/bin"
        end

        prepend_to_path "$HOMEBREW_PREFIX/bin" "$HOMEBREW_PREFIX/sbin"

        break
    end
end

if command -v gem &>/dev/null
    prepend_to_path (ruby -e 'puts Gem.user_dir')"/bin"
    prepend_to_path (gem environment gemdir)"/bin"
end

# Following is interactive only.
if not status --is-interactive
    exit
end

# Disable fish_greeting message
set fish_greeting

# starship
if command -v starship &>/dev/null
    set -x STARSHIP_CONFIG $RAVY_HOME/starship.toml
    starship init fish | source
end

# direnv
if command -v direnv &>/dev/null
    direnv hook fish | source
end

# fundle
fundle plugin jethrokuan/z
fundle init

# atuin
if command -v atuin &>/dev/null
    atuin init fish | source 2>/dev/null
end

# ENV
set -x LANG en_US.UTF-8
set -x LANGUAGE $LANG
set -x EDITOR nvim
set -x GIT_EDITOR nvim

if set -q CURSOR_AGENT || set -q CURSOR_TRACE_ID
    # Do not hang on cursor terminal executions
    set -x PAGER cat
    set -x MANPAGER cat
    set -x GIT_PAGER cat
    if command -v cursor
        . (cursor --locate-shell-integration-path fish)
    end
else
    set -x PAGER less
    set -x MANPAGER less
    set -x GIT_PAGER less
end

set -x LESS FRSXMi
set -x LESS_TERMCAP_mb '[01;31m' # begin blinking
set -x LESS_TERMCAP_md '[01;38;5;74m' # begin bold
set -x LESS_TERMCAP_me '[0m' # end mode
set -x LESS_TERMCAP_so '[7;40;33m' # begin standout-mode - info box
set -x LESS_TERMCAP_se '[0m' # end standout-mode
set -x LESS_TERMCAP_us '[04;38;5;178m' # begin underline
set -x LESS_TERMCAP_ue '[0m' # end underline

set -x FZF_DEFAULT_OPTS --bind=ctrl-f:page-down,ctrl-b:page-up --layout=reverse --height=50% --border
set -x FZF_DEFAULT_COMMAND fd

# functions
function imv
    set -l src
    for src in $argv
        if test -e $src
            set -g __imv__ $src
            vared __imv__
            test $src != "$__imv__"
            and mkdir -p (dirname $__imv__)
            and mv $src $__imv__
        else
            echo "$src does not exist"
        end
    end
end

function lines
    if test (count $argv) -gt 0
        echo $argv | xargs -n1
    end
    if not isatty stdin
        cat 1>| xargs -n1
    end
end

# retry command until it succeeds
function retry
    while true
        $argv
        and break
        echo 'Failed, retrying...'
        sleep 2
    end
end

# ping handles url
function ping
    echo $argv | sed -E -e 's#.*://##' -e 's#/.*$##' | xargs ping
end

# cd ..
function d
    cd ..
end

# edit command in path
function ep --wraps="command -v"
    if set -l exe (command -v $argv[1])
        echo $EDITOR $exe
        $EDITOR $exe
    end
end

# history statistics
function history-stat
    history | awk '{print $1}' | sort | uniq -c | sort -n -r | head
end

# update installed pip packages
function pip-update-all
    set -q PIP_COMMAND; or set -l PIP_COMMAND pip3
    $PIP_COMMAND list --outdated --format=columns | tail -n +3 | cut -f1 -d' ' | xargs $PIP_COMMAND install -U
end

# free
function free
    if test (uname) = Darwin
        command top -l 1 -s 0 | grep PhysMem
    else
        command free -h $argv
    end
end

set -x EZA_CONFIG_DIR $RAVY_HOME/eza

# eza wrapper
function ls
    if command -v eza >/dev/null
        command eza --icons --group-directories-first --git --color $argv
    else
        command ls $argv
    end
end

function du --wraps='du' --description 'gdu or du'
    if type -q gdu
        command gdu
    else
        command du
    end
end

# aliases
alias = "command -v"
alias l "ls -lg"
alias la "l -lA"
alias lt "l --tree"
alias lta "lt -A"
alias lat "lt -A"
alias ld "l -l --sort newest"
alias ldr "ld -r"
alias ldt "ld -A"
alias ldtr "ldt -r"
alias ll "ls -lg --no-permissions --no-user --no-time --bytes --git"

alias c cd

alias ta "type -a"
alias df "command df -h"
alias g "command git"
alias t "command tmux"
alias hs history
alias tf "tail -f"
alias rd rmdir
alias rb ruby
alias v nvim
alias vi nvim
alias vim nvim
alias grep "grep --ignore-case --color=auto --exclude-dir={.bzr,.cvs,.git,.hg,.svn}"
alias pyserv "python3 -m http.server"
alias ipy ipython

alias ts tailscale

# cursor-agent
alias ci "cursor-agent --model grok-code-fast-1"
alias cido "ci -p -f --output-format text --"

# ps-color
alias pa ps-color
alias pc "env HIGH_CPU_MEM_ONLY=1 ps-color"

# brew commands
alias bi "brew install --force-bottle"
alias blr "brew list --installed-on-request"
alias bubu "brew update && brew outdated && brew upgrade && brew cleanup"

# apt commands
alias au "sudo apt update && sudo apt full-upgrade && sudo apt autoclean"
alias auau "sudo apt update && sudo apt full-upgrade && sudo apt dist-upgrade && sudo apt autoclean && sudo apt autoremove"

# pacman commands
alias pupu "sudo pacman -Syuu --noconfirm"

# podman commands
alias pd podman
alias pdau "podman auto-update"
alias pdl "podman logs -f --tail 100"
alias pdips='podman ps -a --format "table {{.Names}}\t{{.Networks}}\t{{.Ports}}" | column -t'

# systemctl commands
alias sc "systemctl --user"
alias sce "sc daemon-reload"
alias scs "sc status"
alias scr "sc restart"
alias scst "sc start"
alias scstop "sc stop"
alias scrall "systemctl --user list-unit-files --state=generated --no-legend | awk '{print \$1}' | xargs --no-run-if-empty systemctl --user restart"
alias scd "cd ~/.config/containers/systemd"

function jl --wraps="journalctl --user -xeu"
    if test (count $argv) -eq 0
        echo "Usage: jl <service_name>"
        return 1
    end
    journalctl --user -xeu $argv[1] -f
end

# docker commands
# alias dc to `docker compose`
function dc --wraps="docker compose"
    docker compose (set -q RAVY_DOCKER_COMPOSE_CONFIG && string collect -- "--file" "$RAVY_DOCKER_COMPOSE_CONFIG") $argv
end
alias dp "dc pull"
alias dcl "dc logs -f --tail 100"
alias dcb "dc build"
alias dud "dc build && dc up -d"
alias dpdu "dc pull && dc up -d"
alias dudp dpdu
alias dpri "docker image prune"
alias dprs "docker system prune --all"
alias dli "docker image list"
alias dls "docker system info"
alias drc "docker ps -f status=exited -q | xargs -n1 -I{} docker rm '{}'"
alias dri "docker images | grep '^<none>' | awk '{print \$3}' | xargs -n1 -I{} docker rmi '{}'"
alias dry "docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock moncho/dry"
alias dcips='docker inspect -f \'{{.Name}}-{{range  $k, $v := .NetworkSettings.Networks}}{{$k}}-{{.IPAddress}} {{end}}-{{range $k, $v := .NetworkSettings.Ports}}{{ if not $v }}{{$k}} {{end}}{{end}} -{{range $k, $v := .NetworkSettings.Ports}}{{ if $v }}{{$k}} => {{range . }}{{ .HostIp}}:{{.HostPort}}{{end}}{{end}} {{end}}\' (docker ps -aq) | column -t -s-'

# reset terminal buffer
alias reset 'command reset; stty sane; tput reset; echo -e "\033c"; clear; builtin cd -- $PWD'

function downcase-exts
    find . -type f -exec bash -c 'file="$1"; filename="${file%.*}"; ext="${file##*.}"; ext_lower=$(echo "$ext" | tr "[:upper:]" "[:lower:]"); if [ "$ext" != "$ext_lower" ]; then mv "$file" "$filename.$ext_lower"; fi' _ {} \;
end

# open-remote
test -n "$SSH_CONNECTION"
and alias open open-remote

# ravy commands
alias ravy "cd \$RAVY_HOME"
alias ravycustom "cd \$RAVY_HOME/custom"
alias ravyc ravycustom
alias ravysource "source "(status --current-filename)
alias ravys ravysource

# fish_title
set -x FISH_TITLE

function __fish_title_or_pwd
    if test -n "$FISH_TITLE"
        echo -s $FISH_TITLE
    else
        # Replace $HOME with "~"
        set realhome ~
        set -l tmp (string replace -r '^'"$realhome"'($|/)' '~$1' $PWD)
        echo $tmp
    end
end

function fish_title
    set -l cmd (status current-command)
    test "$cmd" != fish
    and echo -n "$cmd "
    __fish_title_or_pwd
end

# CUSTOM
test -f "$RAVY_HOME/custom/config.fish"; and source "$RAVY_HOME/custom/config.fish"
