# Modeline & Load {{{
# vim: set foldlevel=0 foldmethod=marker filetype=zsh:

# prevent from loading more than once
[[ -n $RAVY_LOADED ]] && return 0 || RAVY_LOADED=true

# Load zprof if profiling is enabled.
[[ -n $RAVY_PROFILE ]] && zmodload zsh/zprof

# Record time to initialize shell environment.
zmodload zsh/datetime
export _RAVY_PROMPT_TIMER=$EPOCHREALTIME

# benchmark: base 17ms

# load zshenv to make sure paths are set correctly
source "${0:A:h}/zshenv"

# zplug
source "${0:A:h}/zplugrc"

# }}}

# ZLE & FZF {{{

if [[ $- == *i* ]]; then

  # chars treated as a part of a word
  export WORDCHARS='*?_-.[]~=\&:;!#$%^(){}<>+'

  export KEYTIMEOUT=1

  bindkey -e

  # Smart URLs
  autoload -Uz bracketed-paste-url-magic
  zle -N bracketed-paste bracketed-paste-url-magic

  # ^P / ^N: zsh-history-substring-search
  bindkey "^P" history-substring-search-up
  bindkey "^N" history-substring-search-down

  # undo / redo
  bindkey "^_" undo
  bindkey "^R" redo

  # M-h to run-help
  bindkey "\eh" run-help

  # autosuggestion
  bindkey "\ek" autosuggest-clear

  # M-. and M-, to insert word in previous lines
  autoload -Uz copy-earlier-word
  zle -N copy-earlier-word
  bindkey "\e." insert-last-word
  bindkey "\e," copy-earlier-word

  zmodload zsh/complist
  bindkey -M menuselect "^F" forward-word
  bindkey -M menuselect "^B" backward-word
  bindkey -M menuselect "^J" forward-char
  bindkey -M menuselect "^K" backward-char
  bindkey -M menuselect "/" history-incremental-search-forward
  bindkey -M menuselect "^?" undo
  bindkey -M menuselect "^C" undo

  # FZF

  # Enable fzf completion
  if type brew &>/dev/null; then
    source "$(brew --prefix)/opt/fzf/shell/completion.zsh" 2> /dev/null
  fi

  # kill -9 <C-U>
  # ssh <C-U>
  # telnet <C-U>
  # unset <C-U>
  bindkey "^U" fzf-completion
  export FZF_COMPLETION_TRIGGER=""

  _fzf_complete_git() {
    ARGS="$@"
    if [[ $ARGS =~ ' (checkout|co|cherry-pick|cp)' ]]; then
        _fzf_complete "--reverse --multi" "$@" < <(
          git branch -vv # --all
        )
    else
        eval "zle ${fzf_default_completion:-expand-or-complete}"
    fi
  }

  _fzf_complete_git_post() {
    cut -c 3- | awk '{print $1}'
  }

  _fzf_complete_g() { _fzf_complete_git "$@"; }

  # TAB to use zsh default completion and its menu
  bindkey "^I" expand-or-complete

  export FZF_DEFAULT_OPTS="--reverse --height=45% --bind=ctrl-f:page-down,ctrl-b:page-up"
  export FZF_DEFAULT_COMMAND="fd"

  # C-A to append selected files into buffer
  # C-E to edit selected files
  # C-D to change to the folder contains the first file
  # C-O to open selected files

  ravy::zle::fzf::files () {
    local cmd="${FZF_FILES_COMMAND:-fd}"
    local default_action="${FZF_FILES_DEFAULT_ACTION:-q}"
    local prompt_opt="--prompt '${FZF_FILES_PROMPT:-File}> '"
    local fzf_opts="${FZF_FILES_OPTS}"
    local out key file_list file_str zle_clear_cmd="redisplay"
    setopt localoptions pipefail
    out=$(eval "${cmd}" 2>/dev/null \
      | FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS} ${prompt_opt} -m --reverse --expect=ctrl-a,alt-a,ctrl-d,alt-d,ctrl-e,alt-e,ctrl-o,alt-o,ctrl-q,alt-q ${fzf_opts}" fzf)
    key=$(head -1 <<< $out)
    file_list=("${(f)$(tail -n +2 <<< $out)}")
    if [[ -n $file_list ]]; then
      # escape space, unescape break line
      file_str="${$(print ${(q)file_list[*]})/\\\~\//~/}"
      key="${key:-$default_action}"
      if [[ $key =~ [Qq]$ ]]; then
        zle -R "$file_str" "(A)ppend, (E)dit, enter (D)irectory, (O)pen, (Esc):"
        while [[ ! $key =~ [AaDdOoEe]$ ]]; do read -r -k key; done
      fi
      if [[ $key =~ [Aa]$ ]]; then
        LBUFFER="${LBUFFER% }${LBUFFER:+ }$file_str"
      elif [[ $key =~ [Dd]$ ]]; then
        file_str="${file_list[1]/#\~/$HOME}"
        [[ -d $file_str ]] || file_str="${file_str:h}"
        cd "$file_str" || return
        zle_clear_cmd="reset-prompt"
      elif [[ $key =~ [Ee]$ ]]; then
        BUFFER="${EDITOR:-vim} -- $file_str"
        zle accept-line
      elif [[ $key =~ [Oo]$ ]]; then
        BUFFER="open -- $file_str"
        zle accept-line
      fi
    fi
    zle "$zle_clear_cmd"
    typeset -f zle-line-init >/dev/null && zle zle-line-init
    return 0
  }

  # files
  ravy::zle::fzf::files::files() {
    FZF_FILES_COMMAND="fd" FZF_FILES_PROMPT="File" FZF_FILES_DEFAULT_ACTION="e" ravy::zle::fzf::files
  }

  # files, including hidden
  ravy::zle::fzf::files::files::hidden() {
    FZF_FILES_COMMAND="fd -H" FZF_FILES_PROMPT=".File" FZF_FILES_DEFAULT_ACTION="e" ravy::zle::fzf::files
  }

  # directories
  ravy::zle::fzf::files::dirs() {
    FZF_FILES_COMMAND="fd -t d | sed 1d | cut -b3-" FZF_FILES_PROMPT=".Dir" FZF_FILES_DEFAULT_ACTION="d" ravy::zle::fzf::files
  }

  # recent files of vim
  ravy::zle::fzf::files::vim () {
    FZF_FILES_COMMAND="grep '^>' $HOME/.viminfo | cut -b3-" FZF_FILES_PROMPT="File(vim)" FZF_FILES_DEFAULT_ACTION="e" ravy::zle::fzf::files
  }

  # Paste the selected command from history into the command line
  ravy::zle::fzf::history () {
    local selected num
    setopt localoptions noglobsubst pipefail 2> /dev/null
    selected=( $(fc -l 1 \
      | FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} $FZF_DEFAULT_OPTS +s --tac -n2..,.. --tiebreak=index --toggle-sort=ctrl-r --prompt='Hist> ' --query=${(q)LBUFFER} +m --reverse" fzf ) )
    local ret=$?
    if [ "$selected" ]; then
      num=$selected[1]
      if [ "$num" ]; then
        zle vi-fetch-history -n $num
      fi
    fi
    zle redisplay
    typeset -f zle-line-init >/dev/null && zle zle-line-init
    return $ret
  }

  # Restore the background job.
  ravy::zle::fzf::ctrl_z () {
    jobnum=$(jobs -l | fzf -0 -1 --tac | sed 's#\[\(.*\)\].*#\1#')
    zle redisplay
    if [[ -n $jobnum ]]; then
      [[ $#BUFFER > 0 ]] && zle push-input
      BUFFER="fg %$jobnum"
      zle accept-line
    fi
  }
  zle -N ravy::zle::fzf::ctrl_z
  bindkey "^Z" ravy::zle::fzf::ctrl_z

  zle -N ravy::zle::fzf::files::files
  zle -N ravy::zle::fzf::files::files::hidden
  zle -N ravy::zle::fzf::files::dirs
  zle -N ravy::zle::fzf::files::vim
  zle -N ravy::zle::fzf::history

  bindkey "\eo" ravy::zle::fzf::files::files
  bindkey "\eO" ravy::zle::fzf::files::files::hidden
  bindkey "\ed" ravy::zle::fzf::files::dirs
  bindkey "\ev" ravy::zle::fzf::files::vim
  bindkey "\er" ravy::zle::fzf::history
fi

# }}}

# Environment {{{

# General
setopt PROMPT_SUBST           # The prompt string is first subjected to expansion.
setopt PIPE_FAIL              # Piped command fails for precedents.
setopt BRACE_CCL              # Allow brace character class list expansion.
setopt COMBINING_CHARS        # Combine zero-length punctuation characters (accents) with the base character.
setopt INTERACTIVE_COMMENTS   # Enable comments in interactive shell.
setopt RC_QUOTES              # Allow 'Henry''s Garage' instead of 'Henry'\''s Garage'.
unsetopt MAIL_WARNING         # Don't print a warning message if a mail file has been accessed.
unsetopt CORRECT_ALL          # Do not auto correct arguments.
unsetopt CORRECT              # Do not auto correct commands.

# Jobs
setopt LONG_LIST_JOBS         # List jobs in the long format by default.
setopt AUTO_RESUME            # Attempt to resume existing job before creating a new process.
setopt NOTIFY                 # Report status of background jobs immediately.
unsetopt BG_NICE              # Don't run all background jobs at a lower priority.
unsetopt HUP                  # Don't kill jobs on shell exit.
unsetopt CHECK_JOBS           # Don't report on jobs when shell exit.

# Directory
setopt AUTO_CD                # Auto changes to a directory without typing cd.
setopt AUTO_PUSHD             # Push the old directory onto the stack on cd.
setopt PUSHD_IGNORE_DUPS      # Do not store duplicates in the stack.
setopt PUSHD_SILENT           # Do not print the directory stack after pushd or popd.
setopt PUSHD_TO_HOME          # Push to home directory when no argument is given.
setopt CDABLE_VARS            # Change directory to a path stored in a variable.
setopt MULTIOS                # Write to multiple descriptors.
unsetopt AUTO_NAME_DIRS       # Do not auto add variable-stored paths to ~ list.
unsetopt CLOBBER              # Do not overwrite existing files with > and >>, Use >! and >>! to bypass.

# History
setopt BANG_HIST              # Treat the '!' character specially during expansion.
setopt EXTENDED_HISTORY       # Write the history file in the ':start:elapsed;command' format.
setopt SHARE_HISTORY          # Share history between all sessions.
setopt HIST_EXPIRE_DUPS_FIRST # Expire a duplicate event first when trimming history.
setopt HIST_IGNORE_DUPS       # Do not record an event that was just recorded again.
setopt HIST_IGNORE_ALL_DUPS   # Delete an old recorded event if a new event is a duplicate.
setopt HIST_FIND_NO_DUPS      # Do not display a previously found event.
setopt HIST_IGNORE_SPACE      # Do not record an event starting with a space.
setopt HIST_SAVE_NO_DUPS      # Do not write a duplicate event to the history file.
setopt HIST_VERIFY            # Do not execute immediately upon history expansion.
setopt HIST_BEEP              # Beep when accessing non-existent history.
export HISTSIZE=100000        # The maximum number of events to keep in a session.
export SAVEHIST=100000        # The maximum number of events to save in the history file.
HISTFILE="${HOME}/.zhistory"  # The path to the history file.

# lang
export LANG=en_US.UTF-8
export LANGUAGE=$LANG

# editor
export EDITOR=vim
export GIT_EDITOR=vim

# pager: less
export PAGER="less"
export LESS="FRSXMi"
export LESS_TERMCAP_mb=$'\E[01;31m'       # begin blinking
export LESS_TERMCAP_md=$'\E[01;38;5;74m'  # begin bold
export LESS_TERMCAP_me=$'\E[0m'           # end mode
export LESS_TERMCAP_so=$'\E[7;40;33m'     # begin standout-mode - info box
export LESS_TERMCAP_se=$'\E[0m'           # end standout-mode
export LESS_TERMCAP_us=$'\E[04;38;5;178m' # begin underline
export LESS_TERMCAP_ue=$'\E[0m'           # end underline

# }}}

# Util Functions & Aliases {{{

# interactive mv
imv () {
  local src dst
  for src; do
    if [[ -e $src ]]; then
      dst=$src
      vared dst
      [[ $src != "$dst" ]] && mkdir -p $dst:h && mv -n $src $dst
    else
      print -u2 "$src does not exist"
    fi
  done
}

# output into lines
lines () {
  if [[ -p /dev/stdin ]]; then
    xargs -n1
  else
    xargs -n1 <<< "$@"
  fi
}

# bc
= () { bc -l <<< "$@"; }

# ping handles url
ping () { sed -E -e 's#.*://##' -e 's#/.*$##' <<< "$@" | xargs ping; }

# cd up, default 1 level
# usage: $0 <name-of-any-parent-directory>
#        $0 <number-of-folders>
d () {
  local arg i parents parent folder_depth dest
  arg="${1:-1}"
  # example: $PWD == /home/arash/abc ==> $folder_depth == 3
  folder_depth=${#${(ps:/:)${PWD}}#}
  dest="./"

  # First try to find a folder with matching name (could potentially be a number)
  # Get parents (in reverse order)
  for i in {$((folder_depth+1))..2}; do
    parents=($parents "$(print $PWD | cut -d'/' -f$i)")
  done
  parents=($parents "/")
  # Build dest and 'cd' to it
  foreach parent (${parents}); do
    if [[ $arg == $parent ]]; then
      cd $dest
      return 0
    fi
    dest+="../"
  done

  # If the user provided an integer, go up as many times as asked
  dest="./"
  if [[ $arg = <-> ]]; then
    if [[ $arg -gt $folder_depth ]]; then
      print -- "bd: Error: Can not go up $arg times (not enough parent directories)"
      return 1
    fi
    for i in {1..$arg}; do
      dest+="../"
    done
    cd $dest
    return 0
  fi

  # If the above methods fail
  print -- "bd: Error: No parent directory named '$arg'"
  return 1
}

alias dd="d"

# change directory, do not record in history
take () { mkdir -p "$1" && cd -- "$1" || return; }

_d () {
  # Get parents (in reverse order)
  local i folder_depth
  folder_depth=${#${(ps:/:)${PWD}}#}
  for i in {$((folder_depth+1))..2}; do
    reply=($reply "`print $PWD | cut -d'/' -f$i`")
  done
  reply=($reply "/")
}

compctl -V directories -K _d d

# Print the exit status code with its associated signal name if it is not
# zero and preserve the exit status.
nice_exit_code () {
  local exit_status="${1:-$(print -P %?)}" sig_name ref
  [[ -z $exit_status || $exit_status == 0 ]] && return

  typeset -A ref
  ref=(
    # usual exit codes
    -1  FATAL
    1   WARN          # Miscellaneous errors, such as "divide by zero"
    2   BUILTINMISUSE # misuse of shell builtins (pretty rare)
    19  STOP
    20  TSTP
    21  TTIN
    22  TTOU
    126 CCANNOTINVOKE # cannot invoke requested command (ex : source script_with_syntax_error)
    127 CNOTFOUND     # command not found (ex : source script_not_existing)
    129 HUP
    130 INT           # Interrupt
    131 QUIT
    132 ILL
    134 ABRT
    136 FPE
    137 KILL
    139 SEGV
    141 PIPE
    143 TERM
  )

  sig_name=$ref[$exit_status]

  print "${exit_status}:${sig_name:-$exit_status}"
  return $exit_status
}

# change directory to a nearest possible folder
cd () {
  local file="$@"
  while [[ ! -d "$file" ]]; do
    file="${file:h}"
  done
  if [[ "$file" == "." ]]; then
    file="$@"
  fi
  builtin cd -- $file
}

# git completion function for git aliases
_git-l(){ _git-log; }
_git-lg(){ _git-log; }
_git-df(){ _git-diff; }
_git-di(){ _git-diff; }
_git-de(){ _git-diff; }

# change directory to the farest folder containing all changed files
gd () {
  local dpath
  dpath="$(command git dd "${@:-HEAD}")"
  [[ -n $dpath ]] || return
  dpath="$(command git rev-parse --show-toplevel)/$dpath"
  [[ -d $dpath ]] || dpath=$(dirname "$dpath")
  [[ -d $dpath ]] && cd $dpath
}
alias gd1="gd HEAD~ HEAD"
alias gd2="gd HEAD~2 HEAD"
alias gdc="gd --cached"

# example: mmv *.c.orig orig/*.c
autoload -Uz zmv
alias mmv='noglob zmv -W'

# Lists the ten most used commands.
alias history-stat="history 0 | awk '{print \$2}' | sort | uniq -c | sort -n -r | head"

# colorls if available
if type colorls &> /dev/null; then
  alias ls="colorls --gs --sd --color=always --dark"
fi
alias l="ls -l"
alias la="ls -lA"
alias ll="l"

# abbreviations
alias g="command git"
alias t="command tmux"
alias hs="history"
alias tf="tail -f"
alias rd="rmdir"
alias rb="ruby"
alias vi="vim"
alias v="vim"

# python
alias py="python3"
alias py3="python3"
alias ipy="ipython3"
alias ipy3="ipython3"

# http serve current working dir in a given port (8000 in default)
alias pyserv="python3 -m http.server"

pip-update-all () {
  ${PIP_COMMAND:-pip3} list --outdated --format=columns |\
    tail -n +3 |\
    cut -f1 -d' ' |\
    xargs ${PIP_COMMAND:-pip3} install -U
}

# grep with default options
alias grep="grep --ignore-case --color=auto --exclude-dir={.bzr,.cvs,.git,.hg,.svn}"

# ps-color
alias pa="ps-color"
alias pc="HIGH_CPU_MEM_ONLY=1 pa"

# brew commands
alias bc="brew-compose"
alias bi="brew install --force-bottle"
alias bubu="brew update && brew outdated && brew upgrade && brew cleanup"
alias brewleaf=$'brew list | xargs -n1 -I{} sh -c \'if [ -z "$(brew uses {} --installed)" ]; then echo {}; fi\''

# apt commands
alias au="sudo apt update && sudo apt full-upgrade && sudo apt autoclean"
alias auau="sudo apt update && sudo apt full-upgrade && sudo apt dist-upgrade && sudo apt autoclean"

# docker commands
alias dc="docker-compose"
alias dp="docker-compose pull"
alias dud="docker-compose up -d"
alias dpdu="docker-compose pull && docker-compose up -d"
alias dudp="dpdu"
alias drc="docker ps -f status=exited -q | xargs -n1 -I{} docker rm '{}'"
alias dri="docker images | grep '^<none>' | awk '{print \$3}' | xargs -n1 -I{} docker rmi '{}'"
alias dry="docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock moncho/dry"

# reset terminal buffer
alias reset='command reset; stty sane; tput reset; echo -e "\033c"; clear; builtin cd -- $PWD'

# open-remote
[[ -n $SSH_CONNECTION ]] && alias open="open-remote"

# Ravy commands
alias ravy="cd \$RAVY_HOME"
alias ravycustom="cd \$RAVY_HOME/custom"
alias ravyc=ravycustom
alias ravysource="unset RAVY_LOADED; source ${0:A}"
alias ravys=ravysource

# free
if [ $(uname) = Darwin ]; then
  alias free='command top -l 1 -s 0 | grep PhysMem'
else
  alias free='command free -h'
fi

# Pipe command with --help output and ignore rest of the line.
alias -g -- -help="-help | less; true "
alias -g -- --help="--help | less; true "
alias -g -- --helpshort="--helpshort | less; true "
alias -g -- --helpfull="--helpfull | less; true "

# }}}

# Prompt {{{

gitstatus_start ravy

# generate git prompt to _RAVY_PROMPT_GIT_READ
ravy::prompt::git () {
  local st st_parser k v
  gitstatus_query ravy
  if [[ $VCS_STATUS_RESULT == "ok-sync" ]]; then
    st_parser=(
      "VCS_STATUS_COMMITS_AHEAD"  ">"
      "VCS_STATUS_COMMITS_BEHIND" "<"
      "VCS_STATUS_NUM_STAGED"     "."
      "VCS_STATUS_NUM_UNSTAGED"   "*"
      "VCS_STATUS_NUM_CONFLICTED" "!"
      "VCS_STATUS_NUM_UNTRACKED"  "#"
    )
    st=""
    for (( k = 1; k <= $#st_parser; k += 2 )) do
      if ((${(P)st_parser[k]} > 1)); then
        st+="${(P)st_parser[k]}$st_parser[k+1]"
      elif ((${(P)st_parser[k]} > 0)); then
        st+="$st_parser[k+1]"
      fi
    done
    st+="${VCS_STATUS_ACTION:+ ${VCS_STATUS_ACTION}}"
    export _RAVY_PROMPT_GIT_READ="${VCS_STATUS_LOCAL_BRANCH-${VCS_STATUS_COMMIT:0:7}}${VCS_STATUS_TAG:+:${VCS_STATUS_TAG}}"
    export _RAVY_PROMPT_GIT_ST_READ="${st}"
  elif [[ $VCS_STATUS_RESULT == "norepo-sync" ]]; then
    unset _RAVY_PROMPT_GIT_READ _RAVY_PROMPT_GIT_ST_READ
  elif [[ $VCS_STATUS_RESULT == "tout" ]]; then
    export _RAVY_PROMPT_GIT_READ="gitstatus-timeout"
  else
    export _RAVY_PROMPT_GIT_READ="gitstatus-error"
  fi
}

# get human readable representation of time
ravy::prompt::timer_format () {
  local s="$1" repre=''
  if ((s < 10)) then
    printf "%dms" "$((s * 1000))"
  else
    ((s > 86400)) && repre+="$(([#10] s / 86400))d"
    ((s > 3600)) && repre+="$(([#10] s / 3600 % 24))h"
    ((s > 60)) && repre+="$(([#10] s / 60 % 60))m"
    repre+="$(([#10] s % 60))s"
    print "$repre"
  fi
}

# start timer
ravy::prompt::timer_start () {
  _RAVY_PROMPT_TIMER=$EPOCHREALTIME
}

# get elapsed time without stopping timer
ravy::prompt::timer_read () {
  if [[ -n $_RAVY_PROMPT_TIMER ]]; then
    _RAVY_PROMPT_TIMER_READ=$(
      ravy::prompt::timer_format $(($EPOCHREALTIME - _RAVY_PROMPT_TIMER))
    )
  else
    unset _RAVY_PROMPT_TIMER_READ
  fi
}

# stop timer
ravy::prompt::timer_stop () {
  unset _RAVY_PROMPT_TIMER
}

# zsh hooks
autoload -Uz add-zsh-hook
add-zsh-hook preexec ravy::prompt::timer_start
add-zsh-hook precmd ravy::prompt::timer_read
add-zsh-hook precmd ravy::prompt::timer_stop
add-zsh-hook precmd ravy::prompt::git

# PROMPT text

LF=$'\n'
RAVY_PROMPT_LASTCMD_RUNTIME="%F{240}\${_RAVY_PROMPT_TIMER_READ:+\${_RAVY_PROMPT_TIMER_READ} }"
RAVY_PROMPT_LASTCMD_RET="%F{160}\${_RAVY_PROMPT_TIMER_READ:+%(?..\$(nice_exit_code))${LF}}"
RAVY_PROMPT_INDICATOR="%K{234}%E  "
RAVY_PROMPT_PATH="%F{\$([ ! -w \$PWD ] && print '160' || print '30')}%~ "
RAVY_PROMPT_GIT="%F{64}\${_RAVY_PROMPT_GIT_READ:+\${_RAVY_PROMPT_GIT_READ}}%F{172}\${_RAVY_PROMPT_GIT_READ:+\${_RAVY_PROMPT_GIT_ST_READ} }"
RAVY_PROMPT_USER="%F{\$([ \$EUID = 0 ] && print '160' || print '103')}%n "
RAVY_PROMPT_REMOTE="\$([[ -n \$SSH_CLIENT || -n \$SSH_TTY ]] && print '%F{166}易 ')"
RAVY_PROMPT_JOBS="%F{163}%(1j.&%j .)"
RAVY_PROMPT_CUSTOMIZE=""
RAVY_PROMPT_CMD="%F{239}%k%_❯\$([ \$EUID = 0 ] && print '!')%f "

export PROMPT="${RAVY_PROMPT_LASTCMD_RUNTIME}${RAVY_PROMPT_LASTCMD_RET}${RAVY_PROMPT_INDICATOR}\${RAVY_PROMPT_PATH}${RAVY_PROMPT_GIT}${RAVY_PROMPT_USER}${RAVY_PROMPT_REMOTE}${RAVY_PROMPT_JOBS}\$(print -P \$RAVY_PROMPT_CUSTOMIZE)${LF}${RAVY_PROMPT_CMD}"
export PROMPT2="${RAVY_PROMPT_CMD}"
unset RPROMPT RPROMPT2

# }}}

# Terminal title {{{

if [[ ! $TERM =~ ^(dumb|linux|.*bsd.*|eterm.*)$ ]]; then
  ravyname () { RAVY_SESSION_TITLE="$@"; }
  ravyunname () { unset RAVY_SESSION_TITLE; }

  # Set the terminal or terminal multiplexer title.
  ravy::termtitle::settitle () {
    local formatted title
    title=${RAVY_SESSION_TITLE:-$argv}
    zformat -f formatted "%s" "s:$title"

    if [[ -n $TMUX ]] && type tmux &>/dev/null; then
      # Set tmux pane title
      printf "\e]2;%s\e\\" "${(V%)formatted}"
    elif [[ $TERM =~ ^screen ]]; then
      printf "\ek%s\e\\" "${(V%)formatted}"
    elif [[ $TERM =~ ^rxvt-unicode ]]; then
      printf '\33]2;%s\007' ${(V%)formatted}
    elif [[ $TERM =~ ^xterm ]]; then
      printf "\e]0;%s\a" "${(V%)formatted}"
    fi
  }

  # Set the terminal title with current path.
  ravy::termtitle::path () {
    if [[ -n $RAVY_TERMTITLE ]]; then
      ravy::termtitle::settitle "$RAVY_TERMTITLE"
    else
      ravy::termtitle::settitle "%18<...<%~";
    fi
  }

  add-zsh-hook chpwd ravy::termtitle::path   # benchmark: 5ms
  add-zsh-hook precmd ravy::termtitle::path   # benchmark: 5ms
fi

# }}}

# Custom {{{

[[ -f "$RAVY_HOME/custom/zshrc" ]] && source "$RAVY_HOME/custom/zshrc"

# }}}
