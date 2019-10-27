set -x RAVY_HOME (dirname (status --current-filename))

# paths operations
function prepend_to_path
  for arg in $argv
    test -d $arg
    and set PATH $arg $PATH
  end
end
function append_to_path
  for arg in $argv
    test -d $arg
    and set PATH $PATH $arg
  end
end

prepend_to_path "$RAVY_HOME/bin"

for brewprefix in "/home/linuxbrew/.linuxbrew" "/usr/local" "$HOME/.brew" "$HOME/.linuxbrew"
  if test -f "$brewprefix/bin/brew"
    eval ($brewprefix/bin/brew shellenv)
    if test -f "$brewprefix/opt/ruby/bin/ruby"
      prepend_to_path "$brewprefix/opt/ruby/bin"
      set -l gems_bin "$brewprefix"/lib/ruby/gems/*/bin 2>/dev/null
      set -q gems_bin
      and prepend_to_path $gems_bin
    end
    break
  end
end

# ENV
set -x LANG en_US.UTF-8
set -x LANGUAGE $LANG
set -x EDITOR vim
set -x GIT_EDITOR vim

set -x PAGER "less"
set -x LESS "FRSXMi"
set -x LESS_TERMCAP_mb '[01;31m'       # begin blinking
set -x LESS_TERMCAP_md '[01;38;5;74m'  # begin bold
set -x LESS_TERMCAP_me '[0m'           # end mode
set -x LESS_TERMCAP_so '[7;40;33m'     # begin standout-mode - info box
set -x LESS_TERMCAP_se '[0m'           # end standout-mode
set -x LESS_TERMCAP_us '[04;38;5;178m' # begin underline
set -x LESS_TERMCAP_ue '[0m'           # end underline

# functions
function lines
  if test (count $argv) -gt 0
    echo $argv | xargs -n1
  else
    xargs -n1
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

# change directory to a nearest possible folder
function cd
  set -l file $argv
  while ! test -d $file && test -n $file
    set file (dirname $file)
  end
  test "$file" = .
  and set file $argv
  builtin cd -- $file
end

# history statistics
function history-stat
  history | awk '{print $1}' | sort | uniq -c | sort -n -r | head
end

# update installed pip packages
function pip-update-all
  set -q PIP_COMMAND; or set -l PIP_COMMAND pip3
  $PIP_COMMAND list --outdated --format=columns |\
    tail -n +3 |\
    cut -f1 -d' ' |\
    xargs $PIP_COMMAND install -U
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
if command -v colorls >/dev/null
  function ls
    colorls --gs --sd --color=always --dark $argv
  end
end

# aliases
alias l "ls -l"
alias la "ls -lA"
alias g "command git"
alias t "command tmux"
alias hs "history"
alias tf "tail -f"
alias rd "rmdir"
alias rb "ruby"
alias vi "vim"
alias v "vim"
alias grep "grep --ignore-case --color=auto --exclude-dir={.bzr,.cvs,.git,.hg,.svn}"
alias pyserv "python3 -m http.server"

# ps-color
alias pa "ps-color"
alias pc "HIGH_CPU_MEM_ONLY=1 pa"

# brew commands
alias bc "brew-compose"
alias bi "brew install --force-bottle"
alias bubu "brew update && brew outdated && brew upgrade && brew cleanup"
alias brewleaf 'brew list | xargs -n1 -I{} sh -c \'if [ -z "$(brew uses {} --installed)" ]; then echo {}; fi\''

# apt commands
alias au "sudo apt update && sudo apt full-upgrade && sudo apt autoclean"
alias auau "sudo apt update && sudo apt full-upgrade && sudo apt dist-upgrade && sudo apt autoclean"

# docker commands
alias dc "docker-compose"
alias dp "docker-compose pull"
alias dud "docker-compose up -d"
alias dpdu "docker-compose pull && docker-compose up -d"
alias dudp "dpdu"
alias drc "docker ps -f status=exited -q | xargs -n1 -I{} docker rm '{}'"
alias dri "docker images | grep '^<none>' | awk '{print \$3}' | xargs -n1 -I{} docker rmi '{}'"
alias dry "docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock moncho/dry"

# reset terminal buffer
alias reset 'command reset; stty sane; tput reset; echo -e "\033c"; clear; builtin cd -- $PWD'

# open-remote
test -n $SSH_CONNECTION
and alias open "open-remote"

# ravy commands
alias ravy "cd \$RAVY_HOME"
alias ravycustom "cd \$RAVY_HOME/custom"
alias ravyc ravycustom
alias ravysource "source "(status --current-filename)
alias ravys ravysource

# PROMPT
function cmd_duration_format
  set -l ms $argv[1]
  if test $ms -lt 10000
    echo -s $ms ms
  else
    set -l s (math -s0 $ms / 1000)
    test $s -gt 86400; and set -l repre "$repre"(math -s0 $s / 86400)d
    test $s -gt 3600; and set -l repre "$repre"(math -s0 $s / 3600)h
    test $s -gt 60; and set -l repre "$repre"(math -s0 $s / 60 % 60)m
    set -l repre "$repre"(math -s0 $s % 60)s
    echo $repre
  end
end

# print the exit status code with its associated signal name if it is not zero
function nice_exit_code
  set -l st $argv[1]
  test -z $st; or test $st -le 0; and return

  set -l keys 1 2 19 20 21 22 126 127 129 130 131 132 134 136 137 139 141 143
  set -l values WARN BUILTINMISUSE STOP TSTP TTIN TTOU CCANNOTINVOKE CNOTFOUND HUP INT QUIT ILL ABRT FPE KILL SEGV PIPE TERM

  echo -n $st
  if set -l index (contains -i $st $keys)
    echo :$values[$index]
  end
end

# clear greeting message
set fish_greeting

function git_branch
  command git rev-parse --abbrev-ref HEAD 2>/dev/null
end

function git_status
  set -l PARSER_ADDED     A
  set -l PARSER_UNSTAGED  '^.M'
  set -l PARSER_STAGED    '^M'
  set -l PARSER_RENAMED   R
  set -l PARSER_DELETED   D
  set -l PARSER_UNMERGED  U
  set -l PARSER_UNTRACKED '\?\?'
  set -l PARSER_AHEAD     ahead
  set -l PARSER_BEHIND    behind
  set -l INDICATOR_ADDED      +
  set -l INDICATOR_UNSTAGED   \*
  set -l INDICATOR_STAGED     .
  set -l INDICATOR_RENAMED    »
  set -l INDICATOR_DELETED    -
  set -l INDICATOR_UNMERGED   !
  set -l INDICATOR_UNTRACKED  \#
  set -l INDICATOR_AHEAD      \>
  set -l INDICATOR_BEHIND     \<
  set -l PARSER_INDEX_TRIMMED ADDED UNSTAGED STAGED RENAMED DELETED UNMERGED UNTRACKED
  set -l PARSER_INDEX AHEAD BEHIND

  set -l git_status
  set -l is_ahead
  set -l is_behind

  set -l index (command git status --porcelain 2>/dev/null -b)
  set -l trimmed_index (string split \n $index | string sub --start 1 --length 2)

  for suffix in $PARSER_INDEX_TRIMMED
    set -l suffixed_parser "PARSER_$suffix"
    set -l suffixed_indicator "INDICATOR_$suffix"
    set -l parser "$$suffixed_parser"
    set -l indicator "$$suffixed_indicator"
    set -l matched_count (count (string match -r $parser $trimmed_index))
    test $matched_count -gt 1
    and set git_status "$git_status$matched_count"
    test $matched_count -gt 0
    and set git_status "$git_status$indicator"
  end

  for suffix in $PARSER_INDEX
    set -l suffixed_parser "PARSER_$suffix"
    set -l suffixed_indicator "INDICATOR_$suffix"
    set -l parser "$$suffixed_parser"
    set -l indicator "$$suffixed_indicator"
    set -l matched_count (count (string match -r $parser $index))
    test $matched_count -gt 1
    and set git_status "$git_status$matched_count"
    test $matched_count -gt 0
    and set git_status "$git_status$indicator"
  end

  echo $git_status
end

function fish_prompt
  set -l cmd_status $status
  if test $cmd_status -le 0
    set -e cmd_status
  end

  set -l user_color magenta
  set -l cmd_indicator '❯'
  switch $USER
    case root toor
      set user_color red
      set cmd_indicator "$cmd_indicator""!"
  end

  set -l bg_jobs (count (jobs -c))

  # line 1
  # last command duration and status
  if set -q CMD_DURATION
    echo -n -s (set_color 666) (cmd_duration_format $CMD_DURATION)  ' ' (set_color red) (nice_exit_code $cmd_status)
    set -e CMD_DURATION
    echo
  end

  # line 2
  # path
  echo -n -s (set_color -b 222) '  ' (test -w $PWD; and set_color blue; or set_color red) (prompt_pwd) ' '

  # git
  set -l gbranch (git_branch)
  if test -n "$gbranch"
    echo -n -s (set_color green) $gbranch (set_color yellow) (git_status) ' '
  end

  # user
  echo -n -s (set_color $user_color) $USER ' '

  # ssh
  test -n "$SSH_CLIENT"; and echo -n -s (set_color red) '易 '

  # jobs
  test $bg_jobs -gt 0; and echo -n -s (set_color yellow) "%$bg_jobs "
  echo

  # line 3
  # indicator
  echo -n -s (set_color normal) (set_color 666) "$cmd_indicator "
end

# CUSTOM
test -f "$RAVY_HOME/custom/config.fish"; and source "$RAVY_HOME/custom/config.fish"

