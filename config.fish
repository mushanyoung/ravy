if not status --is-interactive
    exit
end

# Disable fish_greeting message
set fish_greeting

set -x RAVY_HOME (dirname (status --current-filename))

# paths operations
function prepend_to_path
    for arg in $argv
        fish_add_path -p -P -g $arg
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

        prepend_to_path "$HOMEBREW_PREFIX/bin" "$HOMEBREW_PREFIX/sbin"
        break
    end
end

if command -v gem &>/dev/null
    prepend_to_path (ruby -e 'puts Gem.user_dir')"/bin"
    prepend_to_path (gem environment gemdir)"/bin"
end

# fundle
fundle plugin jethrokuan/z
fundle init

# ENV
set -x LANG en_US.UTF-8
set -x LANGUAGE $LANG
set -x EDITOR vim
set -x GIT_EDITOR vim

set -x PAGER less
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
        test -n "$EDITOR"; or set -l EDITOR vim
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

# colorls
function ls
    if command -v colorls >/dev/null
        command colorls --gs --sd --color=always --dark $argv
    else
        command ls $argv
    end
end

# aliases
alias = "command -v"
alias l "ls -l"
alias la "ls -lA"
alias lt "ls -lt"
alias ltr "ls -ltr"
alias lat "ls -lAt"
alias latr "ls -lAtr"

alias ta "type -a"
alias df "df -h"
alias du "du -h"
alias g "command git"
alias t "command tmux"
alias hs history
alias tf "tail -f"
alias rd rmdir
alias rb ruby
alias vi vim
alias v vim
alias grep "grep --ignore-case --color=auto --exclude-dir={.bzr,.cvs,.git,.hg,.svn}"
alias pyserv "python3 -m http.server"

# ps-color
alias pa ps-color
alias pc "env HIGH_CPU_MEM_ONLY=1 ps-color"

# brew commands
alias bc brew-compose
alias bi "brew install --force-bottle"
alias bubu "brew update && brew outdated && brew upgrade && brew cleanup"
alias brewleaf 'brew list | xargs -n1 -I{} sh -c \'if [ -z "$(brew uses {} --installed)" ]; then echo {}; fi\''

# apt commands
alias au "sudo apt update && sudo apt full-upgrade && sudo apt autoclean"
alias auau "sudo apt update && sudo apt full-upgrade && sudo apt dist-upgrade && sudo apt autoclean && sudo apt autoremove"

# pacman commands
alias pupu "sudo pacman -Syy && sudo pacman -Suy"

# docker commands
# alias dc docker-compose
function dc --wraps="docker-compose"
    docker-compose (set -q RAVY_DOCKER_COMPOSE_CONFIG && echo "--file" "$RAVY_DOCKER_COMPOSE_CONFIG" | string split " ") $argv
end
alias dp "dc pull"
alias dcl "dc logs -f --tail 100"
alias dud "dc up -d"
alias dpdu "dc pull && dc up -d"
alias dudp dpdu
alias dpr "docker image prune"
alias dprs "docker system prune --all"
alias drc "docker ps -f status=exited -q | xargs -n1 -I{} docker rm '{}'"
alias dri "docker images | grep '^<none>' | awk '{print \$3}' | xargs -n1 -I{} docker rmi '{}'"
alias dry "docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock moncho/dry"
alias dcips='docker inspect -f \'{{.Name}}-{{range  $k, $v := .NetworkSettings.Networks}}{{$k}}-{{.IPAddress}} {{end}}-{{range $k, $v := .NetworkSettings.Ports}}{{ if not $v }}{{$k}} {{end}}{{end}} -{{range $k, $v := .NetworkSettings.Ports}}{{ if $v }}{{$k}} => {{range . }}{{ .HostIp}}:{{.HostPort}}{{end}}{{end}} {{end}}\' $(docker ps -aq) | column -t -s-'

# reset terminal buffer
alias reset 'command reset; stty sane; tput reset; echo -e "\033c"; clear; builtin cd -- $PWD'

# open-remote
test -n "$SSH_CONNECTION"
and alias open open-remote

# ravy commands
alias ravy "cd \$RAVY_HOME"
alias ravycustom "cd \$RAVY_HOME/custom"
alias ravyc ravycustom
alias ravysource "source "(status --current-filename)
alias ravys ravysource

# CUSTOM
test -f "$RAVY_HOME/custom/config.fish"; and source "$RAVY_HOME/custom/config.fish"
