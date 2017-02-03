# Modeline & Load {{{
# vim: set foldlevel=0 foldmethod=marker filetype=zsh:

# prevent from loading more than once
[[ -n $RAVY_LOADED ]] && return 0 || RAVY_LOADED=true

# load zshenv to make sure paths are set correctly
source "${0:A:h}/zshenv"

# Load zprof if profiling enabled.
[[ "$RAVY_PROFILE" == true ]] && zmodload zsh/zprof

# Record time to initialize shell environment.
_RAVY_PROMPT_TIMER=$(perl -MTime::HiRes -e 'printf("%.0f\n",Time::HiRes::time()*1000)')

# }}}

# ZLE & FZF {{{

if [[ $- == *i* ]]; then

  # chars treated as a part of a word
  export WORDCHARS=$'\'\\/|*?_-.,[]~&;!#$%^(){}<>+:=@'

  export KEYTIMEOUT=1

  # use emacs mode for command line
  bindkey -e

  # ctrl-a and ctrl-e
  bindkey "^A" beginning-of-line
  bindkey "^E" end-of-line

  # undo and redo
  bindkey "^_" undo
  bindkey "\e-" redo

  # zsh-history-substring-search: bind ^P and ^N to it
  bindkey "^P" history-substring-search-up
  bindkey "^N" history-substring-search-down

  # autosuggestion
  bindkey "\ek" autosuggest-clear

  # Use C-x C-e to edit the current command line in editor
  autoload -U edit-command-line
  zle -N edit-command-line
  bindkey "\C-x\C-e" edit-command-line

  # Smart URLs
  autoload -Uz url-quote-magic
  zle -N self-insert url-quote-magic

  # M-. and M-m to insert word in previous lines
  autoload -Uz copy-earlier-word
  zle -N copy-earlier-word
  bindkey "\em" copy-earlier-word
  bindkey "\e." insert-last-word

  # C-B / C-F to move, C-W to kill by word
  # M-b / M-f to move, M-w to kill by word with bash style
  autoload -U select-word-style
  autoload -U backward-kill-word-match
  autoload -U forward-word-match
  autoload -U backward-word-match
  zle -N backward-kill-word-match
  zle -N forward-word-match
  zle -N backward-word-match

  _forward-word-alter () {
    select-word-style bash
    zle forward-word-match
  }
  _backward-word-alter () {
    select-word-style bash
    zle backward-word-match
  }
  _backward-kill-word-alter () {
    select-word-style bash
    zle backward-kill-word-match
  }
  zle -N _forward-word-alter
  zle -N _backward-word-alter
  zle -N _backward-kill-word-alter
  bindkey "\ef" _forward-word-alter
  bindkey "\eb" _backward-word-alter
  bindkey "\ew" _backward-kill-word-alter
  bindkey "^F" forward-word
  bindkey "^B" backward-word
  bindkey "^W" backward-kill-word

  # ranger file explorer
  _ranger-cd () {
    tempfile=$(mktemp)
    ranger --choosedir="$tempfile" "${@:-$(pwd)}" < "$TTY"
    if [[ -f "$tempfile" && "$(cat -- "$tempfile")" != "$(pwd)" ]]; then
      cd -- "$(cat "$tempfile")" || return
    fi
    rm -f -- "$tempfile"
    zle redisplay
    zle -M ""
  }
  zle -N _ranger-cd
  bindkey "^K" _ranger-cd

  # toggle glob for current command line
  _glob-toggle () {
    [[ -z $BUFFER ]] && zle up-history
    if [[ $BUFFER =~ ^noglob ]]; then
      LBUFFER="${LBUFFER#noglob }"
    else
      LBUFFER="noglob $LBUFFER"
    fi
  }
  zle -N _glob-toggle
  bindkey "\eg" _glob-toggle

  # toggle sudo for current command line
  _sudo-toggle () {
    [[ -z $BUFFER ]] && zle up-history
    if [[ $BUFFER =~ ^sudo ]]; then
      LBUFFER="${LBUFFER#sudo }"
    else
      LBUFFER="sudo $LBUFFER"
    fi
  }
  zle -N _sudo-toggle
  bindkey "^S" _sudo-toggle

  # fancy-ctrl-z
  _fancy-ctrl-z () {
    if [[ $#BUFFER -eq 0 ]]; then
      BUFFER="fg"
      zle accept-line
    else
      zle push-input
      zle clear-screen
    fi
  }
  zle -N _fancy-ctrl-z
  bindkey "^Z" _fancy-ctrl-z

  # menu select and completion
  bindkey "^I" expand-or-complete

  zmodload zsh/complist
  zle -C complete-menu menu-select _generic
  _complete-menu () {
    setopt localoptions alwayslastprompt
    zle complete-menu
  }
  zle -N _complete-menu
  bindkey "^J" _complete-menu
  bindkey -M menuselect "^F" forward-word
  bindkey -M menuselect "^B" backward-word
  bindkey -M menuselect "^J" forward-char
  bindkey -M menuselect "^K" backward-char
  bindkey -M menuselect "/" history-incremental-search-forward
  bindkey -M menuselect "^?" undo
  bindkey -M menuselect "^C" undo

  # FZF

  export FZF_DEFAULT_OPTS="--height=50% --min-height=9 --bind=ctrl-f:page-down,ctrl-b:page-up"
  export FZF_DEFAULT_COMMAND="ag -g ''"

  # C-A to append selected files into buffer
  # C-E to edit selected files
  # C-D to change to the folder contains the first file
  # C-O to open selected files
  _fzf-files () {
    local key files file clear_cmd="redisplay"
    sh -c "${FZF_FILES_CMD:-ag -a --hidden -g ''} | fzf -m --exit-0 --expect=ctrl-a,ctrl-d,ctrl-e,ctrl-o ${FZF_FILES_OPT}" | {
      read -r key
      files=("${(f)$(cat)}")
    }
    if [[ $files ]]; then
      if [[ ! $key =~ [AaDdOoEe]$ ]]; then
        zle redisplay
        zle -R "$files" "(A)ppend, (E)dit, change (D)irectory, (O)pen:"
      fi
      while [[ ! $key =~ [AaDdOoEe]$ ]]; do read -r -k key; done
      if [[ $key =~ [Aa]$ ]]; then
        LBUFFER="${LBUFFER% }${LBUFFER:+ }$files"
      elif [[ $key =~ [Dd]$ ]]; then
        file="${files[1]/#\~/$HOME}"
        while [[ ! -d $file ]]; do file="${file:h}"; done
        cd -- "$file" || return
        clear_cmd="reset-prompt"
      elif [[ $key =~ [Ee]$ ]]; then
        BUFFER="${EDITOR:-vim} $files"
        zle accept-line
      elif [[ $key =~ [Oo]$ ]]; then
        BUFFER="open $files"
        zle accept-line
      fi
    fi
    zle "$clear_cmd"
  }

  # directories
  _fzf-directories() {
    FZF_FILES_CMD="find . -type d | sed 1d | cut -b3-" _fzf-files
  }

  # recent files of vim
  _fzf-vim-files () {
    FZF_FILES_CMD="grep '^>' ~/.viminfo | cut -b3-" _fzf-files
  }

  # open session matched by query, create a new one if there is no match
  _fzf-vim-sessions () {
    local session
    session=$(cd ~/.vim/sessions && find . | cut -b3- | sed -e "1d" -e 's/\.vim$//' | fzf --exit-0)
    if [[ -n $session ]]; then
      cd -- ${$(grep '^cd' ~/.vim/sessions/"$session".vim | head -1 | cut -d" " -f2-)/#\~/$HOME} || return
      BUFFER="vim '+OpenSession $session'"
      zle reset-prompt
      zle accept-line
    fi
  }

  # CTRL-R - Paste the selected command from history into the command line
  _fzf-history () {
    local selected num
    setopt localoptions noglobsubst pipefail 2> /dev/null
    selected=( $(fc -l 1 |
    FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} $FZF_DEFAULT_OPTS +s --tac -n2..,.. --tiebreak=index --toggle-sort=ctrl-r $FZF_CTRL_R_OPTS --query=${(q)LBUFFER} +m" fzf ) )
    local ret=$?
    if [ -n "$selected" ]; then
      num=$selected[1]
      if [ -n "$num" ]; then
        zle vi-fetch-history -n $num
      fi
    fi
    zle redisplay
    typeset -f zle-line-init >/dev/null && zle zle-line-init
    return $ret
  }

  zle -N _fzf-files
  zle -N _fzf-directories
  zle -N _fzf-vim-files
  zle -N _fzf-vim-sessions
  zle -N _fzf-history

  bindkey "\eo" _fzf-files
  bindkey "^O" _fzf-directories
  bindkey "\ev" _fzf-vim-files
  bindkey "\es" _fzf-vim-sessions
  bindkey "^R" _fzf-history
fi

# }}}

# Zplug {{{

ZPLUG_HOME=${ZPLUG_HOME:-~/.zplug}

if [[ -f "$ZPLUG_HOME/init.zsh" && -z $ZPLUG_LOADED ]]; then
  ZPLUG_LOADED=true

  # load zplug
  source "$ZPLUG_HOME/init.zsh"

  # zplug env
  zstyle :zplug:tag depth 1

  # plugins
  zplug "supercrabtree/k"
  zplug "bric3/nice-exit-code"
  zplug "micha/resty"
  zplug "joshuarubin/zsh-archive"
  zplug "zsh-users/zsh-completions"
  zplug "Tarrasch/zsh-bd"

  zplug "zsh-users/zsh-syntax-highlighting", defer:2
  zplug "zsh-users/zsh-history-substring-search", defer:2
  zplug "zsh-users/zsh-autosuggestions", defer:3

  # Install plugins if there are plugins that have not been installed
  if ! zplug check --verbose; then
    printf "Install? [y/N]: "
    if read -r -q; then
      echo; zplug install
    fi
  fi

  # load plugins
  zplug load

  # zsh syntax highlighting
  export ZSH_HIGHLIGHT_HIGHLIGHTERS=(main line root)
  export ZSH_HIGHLIGHT_STYLES=(
  "unknown-token"            "fg=red,bold"
  "reserved-word"            "fg=yellow"
  "builtin"                  "fg=green,bold"
  "function"                 "fg=white,bold"
  "command"                  "fg=green"
  "alias"                    "fg=green"
  "suffix-alias"             "fg=green,underline"
  "hashed-command"           "fg=green"
  "precommand"               "fg=magenta"
  "path"                     "fg=cyan"
  "commandseparator"         "fg=white,bold"
  "globbing"                 "fg=blue"
  "single-hyphen-option"     "fg=yellow"
  "double-hyphen-option"     "fg=yellow"
  "single-quoted-argument"   "fg=yellow,bold"
  "dollar-quoted-argument"   "fg=yellow,bold"
  "double-quoted-argument"   "fg=yellow"
  "back-quoted-argument"     "fg=blue"
  "assign"                   "fg=magenta,bold"
  "redirection"              "fg=white,bold"
  "comment"                  "fg=black,bold"
  "default"                  "none"
  )

  # zsh auto suggestions
  export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=240"
  ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=(
  "backward-delete-char" "complete-menu" "expand-or-complete"
  )
fi

# }}}

# Environment {{{

# lang
export LANG=en_US.UTF-8
export LANGUAGE=$LANG

# General
setopt PIPE_FAIL              # Piped command fails for precedents.
setopt BRACE_CCL              # Allow brace character class list expansion.
setopt COMBINING_CHARS        # Combine zero-length punctuation characters (accents) with the base character.
setopt RC_QUOTES              # Allow 'Henry''s Garage' instead of 'Henry'\''s Garage'.
unsetopt MAIL_WARNING         # Do not print a warning message if a mail file has been accessed.

# Jobs
setopt LONG_LIST_JOBS         # List jobs in the long format by default.
setopt AUTO_RESUME            # Attempt to resume existing job before creating a new process.
setopt NOTIFY                 # Report status of background jobs immediately.
unsetopt BG_NICE              # Do not run all background jobs at a lower priority.
unsetopt HUP                  # Do not kill jobs on shell exit.
unsetopt CHECK_JOBS           # Do not report on jobs when shell exit.

# History
export HISTFILE=~/.zhistory   # The path to the history file.
export HISTSIZE=100000        # The maximum number of events to be kept in a session.
export SAVEHIST=100000        # The maximum number of events to save in the history file.

setopt BANG_HIST              # Treat the '!' character specially during expansion.
setopt EXTENDED_HISTORY       # Write the history file in the ':start:elapsed;command' format.
setopt INC_APPEND_HISTORY     # Write to the history file immediately, not when the shell exits.
setopt SHARE_HISTORY          # Share history between all sessions.
setopt HIST_EXPIRE_DUPS_FIRST # Expire a duplicate event first when trimming history.
setopt HIST_IGNORE_DUPS       # Do not record an event that was just recorded again.
setopt HIST_IGNORE_ALL_DUPS   # Delete an old recorded event if a new event is a duplicate.
setopt HIST_FIND_NO_DUPS      # Do not display a previously found event.
setopt HIST_SAVE_NO_DUPS      # Do not write a duplicate event to the history file.
setopt HIST_IGNORE_SPACE      # Do not record an event starting with a space.
setopt HIST_VERIFY            # Do not execute immediately upon history expansion.
setopt HIST_BEEP              # Beep when accessing non-existent history.

# Auto correcting
unsetopt CORRECT_ALL          # Do not auto correct arguments.
unsetopt CORRECT              # Do not auto correct commands.

# Colors
export CLICOLOR=xterm-256color
export LSCOLORS=

# enable 256color for xterm if connects to Display
if [[ -n $DISPLAY && $TERM == "xterm" ]]; then
  export TERM=xterm-256color
fi

# pager
export PAGER="less"
export LESS="FRSXMi"

# Termcap
export LESS_TERMCAP_mb=$'\E[01;31m'       # begin blinking
export LESS_TERMCAP_md=$'\E[01;38;5;74m'  # begin bold
export LESS_TERMCAP_me=$'\E[0m'           # end mode
export LESS_TERMCAP_so=$'\E[7;40;33m'     # begin standout-mode - info box
export LESS_TERMCAP_se=$'\E[0m'           # end standout-mode
export LESS_TERMCAP_us=$'\E[04;38;5;146m' # begin underline
export LESS_TERMCAP_ue=$'\E[0m'           # end underline

# always add a colon before MANPATH so that man would search by executables
if [[ $MANPATH != :* ]]; then
  MANPATH=":$MANPATH"
fi

# editor
alias vi=vim
alias v=vim
export EDITOR=vim
export GIT_EDITOR=vim

# ls color evaluations
if hash dircolors &>/dev/null; then
  eval "$(dircolors -b "$RAVY/LS_COLORS")"
elif hash gdircolors &>/dev/null; then
  # coreutils from brew
  eval "$(gdircolors -b "$RAVY/LS_COLORS")"
fi

# load zsh modules
autoload -Uz zmv add-zsh-hook

# }}}

# Completions {{{

# Options
setopt COMPLETE_IN_WORD    # Complete from both ends of a word.
setopt ALWAYS_TO_END       # Move cursor to the end of a completed word.
setopt PATH_DIRS           # Perform path search even on command names with slashes.
setopt AUTO_MENU           # Show completion menu on a successive tab press.
setopt AUTO_LIST           # Automatically list choices on ambiguous completion.
setopt AUTO_PARAM_SLASH    # If completed parameter is a directory, add a trailing slash.
unsetopt MENU_COMPLETE     # Do not autoselect the first completion entry.
unsetopt FLOW_CONTROL      # Disable start/stop characters in shell editor.

# Styles

# Use caching to make completion for commands such as dpkg and apt usable.
zstyle ":completion::complete:*" use-cache on
zstyle ":completion::complete:*" cache-path "${HOME}/.zcompcache"

# Case-insensitive (all), partial-word, and then substring completion.
zstyle ":completion:*" matcher-list "m:{a-zA-Z}={A-Za-z}" "r:|[._-]=* r:|=*" "l:|=* r:|=*"
unsetopt CASE_GLOB

# Group matches and describe.
zstyle ":completion:*:*:*:*:*" menu select
zstyle ":completion:*:matches" group "yes"
zstyle ":completion:*:options" description "yes"
zstyle ":completion:*:options" auto-description '%d'
zstyle ":completion:*:corrections" format ' %F{green}-- %d (errors: %e) --%f'
zstyle ":completion:*:descriptions" format ' %F{yellow}-- %d --%f'
zstyle ":completion:*:messages" format ' %F{purple} -- %d --%f'
zstyle ":completion:*:warnings" format ' %F{red}-- no matches found --%f'
zstyle ":completion:*:default" list-prompt '%S%M matches%s'
zstyle ":completion:*" format ' %F{yellow}-- %d --%f'
zstyle ":completion:*" group-name ''
zstyle ":completion:*" verbose yes

# Fuzzy match mistyped completions.
zstyle ":completion:*" completer _complete _match _approximate
zstyle ":completion:*:match:*" original only
zstyle ":completion:*:approximate:*" max-errors 1 numeric

# Increase the number of errors based on the length of the typed word.
zstyle -e ":completion:*:approximate:*" max-errors "reply=(\$(((\$#PREFIX+\$#SUFFIX)/3))numeric)"

# Don"t complete unavailable commands.
zstyle ":completion:*:functions" ignored-patterns "(_*|pre(cmd|exec))"

# Array completion element sorting.
zstyle ":completion:*:*:-subscript-:*" tag-order indexes parameters

# Directories
zstyle ":completion:*:default" list-colors "${(s.:.)LS_COLORS}"
zstyle ":completion:*:*:cd:*" tag-order local-directories directory-stack path-directories
zstyle ":completion:*:*:cd:*:directory-stack" menu yes select
zstyle ":completion:*:-tilde-:*" group-order "named-directories" "path-directories" "users" "expand"
zstyle ":completion:*" squeeze-slashes true

# History
zstyle ":completion:*:history-words" stop yes
zstyle ":completion:*:history-words" remove-all-dups yes
zstyle ":completion:*:history-words" list false
zstyle ":completion:*:history-words" menu yes

# Do not complete uninteresting users...
zstyle ":completion:*:*:*:users" ignored-patterns \
  adm amanda apache avahi beaglidx bin cacti canna clamav daemon \
  dbus distcache dovecot fax ftp games gdm gkrellmd gopher \
  hacluster haldaemon halt hsqldb ident junkbust ldap lp mail \
  mailman mailnull mldonkey mysql nagios \
  named netdump news nfsnobody nobody nscd ntp nut nx openvpn \
  operator pcap postfix postgres privoxy pulse pvm quagga radvd \
  rpc rpcuser rpm shutdown squid sshd sync uucp vcsa xfs "_*"

# ... unless we really want to.
zstyle "*" single-ignored show

# Ignore multiple entries.
zstyle ":completion:*:(rm|kill|diff):*" ignore-line other
zstyle ":completion:*:rm:*" file-patterns "*:all-files"

# Kill
zstyle ":completion:*:*:*:*:processes" command "ps -u \$LOGNAME -o pid,user,command -w"
zstyle ":completion:*:*:kill:*:processes" list-colors "=(#b) #([0-9]#) ([0-9a-z-]#)*=01;36=0=01"
zstyle ":completion:*:*:kill:*" menu yes select
zstyle ":completion:*:*:kill:*" force-list always
zstyle ":completion:*:*:kill:*" insert-ids single

# Man
zstyle ":completion:*:manuals" separate-sections true
zstyle ":completion:*:manuals.(^1*)" insert-sections true

# }}}

# Util Functions & Aliases {{{

# ping handles url
ping () { sed -E -e 's#.*://##' -e 's#/.*$##' <<< "$@" | xargs ping; }

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

# kill processes of current user containing a specific keyword
kgrep () { pgrep "$1" | xargs kill -9; }

# wrapper of zsh-bd, cd up 1 level by default
d () { bd "${@:-1}"; }
compctl -V directories -K _bd d

# Codi: launch an interactive repl scratchpad within vim
# Usage: codi [filetype] [filename]
codi() {
  local syntax="${1:-python}"
  shift
  vim -c \
    "let g:startify_disable_at_vimenter = 1 |\
    set bt=nofile ls=0 noru nonu nornu |\
    hi ColorColumn ctermbg=NONE |\
    hi VertSplit ctermbg=NONE |\
    hi NonText ctermfg=0 |\
    Codi $syntax" "$@"
}

# git completion function for git aliases
_git-co(){ _git-checkout; }
_git-l(){ _git-log; }
_git-lg(){ _git-log; }
_git-df(){ _git-diff; }
_git-di(){ _git-diff; }
_git-de(){ _git-diff; }

# list files, do not record in history
alias l="ls-color"
alias la="ls-color -A"
alias ll="ls -lFh"

# change directory, do not record in history
alias pu="pushd"
alias po="popd"
alias dd="d"
take () { mkdir -p "$1" && cd -- "$1" || return; }

# abbreviations
alias g="git"
alias t="tmux"
alias sw="subl -n -w"
alias hs="history"
alias tf="tail -f"
alias rd="rmdir"
alias rb="ruby"

# python abbreviations
alias py="python2"
alias py2="python2"
alias py3="python3"
alias ipy="ipython2"
alias ipy2="ipython2"
alias ipy3="ipython3"
alias pip="pip2"
pip2-update-all () {
  pip2 list --outdated | awk "!/Could not|ignored/ { print \$1}" | xargs pip2 install -U
}
pip3-update-all () {
  pip3 list --outdated | awk "!/Could not|ignored/ { print \$1}" | xargs pip3 install -U
}

# http serve current working dir in a given port (8000 in default)
alias serve="python -m SimpleHTTPServer"

# print abosolute path for given file
alias realpath="perl -MCwd -e 'print Cwd::abs_path(shift), \"\\n\"'"

# Lists the ten most used commands.
history-stat () {
  history 0 | awk "{print \$2}" | sort | uniq -c | sort -n -r | head
}

# grep with default options
alias grep="grep --ignore-case --color=auto --exclude-dir={.bzr,.cvs,.git,.hg,.svn}"

# ps-color
alias pa="ps-color"
alias pc="HIGH_CPU_MEM_ONLY=1 pa"

# brew commands
alias bubo="brew update && brew outdated"
alias bubc="brew upgrade && brew cleanup"
alias bubu="bubo && bubc"
alias bi="brew install --force-bottle"

# Ravy commands
alias ravy="cd \$RAVY"
alias ravycustom="cd \$RAVY_CUSTOM"
alias ravysource="unset RAVY_LOADED; source ${0:A}"

# Rsync commands
if hash rsync 2>/dev/null; then
  _rsync_cmd="rsync --verbose --progress --human-readable --compress --archive --hard-links --one-file-system"

  if grep -q "xattrs" <(rsync --help 2>&1); then
    _rsync_cmd="${_rsync_cmd} --acls --xattrs"
  fi

  if [[ $OSTYPE =~ ^darwin ]] && grep -q "file-flags" <(rsync --help 2>&1); then
    _rsync_cmd="${_rsync_cmd} --crtimes --fileflags --protect-decmpfs --force-change"
  fi

  alias rsync-copy="${_rsync_cmd}"
  alias rsync-move="${_rsync_cmd} --remove-source-files"
  alias rsync-update="${_rsync_cmd} --update"
  alias rsync-synchronize="${_rsync_cmd} --update --delete"

  unset _rsync_cmd
fi

# Open command through cbmonitor
open_remote () { clip <<< "open:[$1]"; }

# }}}

# Prompt {{{

# current millseconds
_ravy_prompt_now_ms () {
  perl -MTime::HiRes -e 'printf("%.0f\n",Time::HiRes::time()*1000)'
}

# get human readable representation of time
_ravy_prompt_pretty_time () {
  local ms="$1" s repre
  if ((ms < 10000)) then
    repre=${ms}ms
  else
    s=$((ms / 1000))
    ((s > 3600)) && repre+=$((s / 3600))h
    ((s > 60)) && repre+=$((s / 60 % 60))m
    repre+=$((s % 60))s
  fi
  echo $repre
}

# start timer
_ravy_prompt_timer_start () {
  [[ $_RAVY_PROMPT_TIMER ]] || _RAVY_PROMPT_TIMER=$(_ravy_prompt_now_ms)
}

# get elapsed time without stopping timer
_ravy_prompt_timer_get () {
  [[ $_RAVY_PROMPT_TIMER ]] && _ravy_prompt_pretty_time $(($(_ravy_prompt_now_ms) - _RAVY_PROMPT_TIMER))
}

# get elapsed time and stop timer
_ravy_prompt_timer_stop () {
  export _RAVY_PROMPT_TIMER_READ
  _RAVY_PROMPT_TIMER_READ=$(_ravy_prompt_timer_get)
  unset _RAVY_PROMPT_TIMER
}

# generate git prompt to _RAVY_PROMPT_GIT_READ
_ravy_prompt_git () {
  local ref k git_st st_str st_count
  # exit if current directory is not a git repo
  if ref=$(command git symbolic-ref --short HEAD 2>/dev/null || command git rev-parse --short HEAD 2>/dev/null); then
    git_st=$(command git status --ignore-submodules=dirty -unormal --porcelain -b 2>/dev/null)
    st_parser=(
    "^## .*ahead"         "${RAVY_PROMPT_GIT_AHEAD->}"
    "^## .*behind"        "${RAVY_PROMPT_GIT_BEHIND-<}"
    "^## .*diverged"      "${RAVY_PROMPT_GIT_DIVERGED-x}"
    "^A. "                "${RAVY_PROMPT_GIT_ADDED-+}"
    "^R. "                "${RAVY_PROMPT_GIT_RENAMED-~}"
    "^C. "                "${RAVY_PROMPT_GIT_COPIED-c}"
    "^.D |^D. "           "${RAVY_PROMPT_GIT_DELETED--}"
    "^M. "                "${RAVY_PROMPT_GIT_MODIFIED-.}"
    "^.M "                "${RAVY_PROMPT_GIT_TREE_CHANGED-*}"
    "^U. |^.U |^AA |^DD " "${RAVY_PROMPT_GIT_UNMERGED-^}"
    "^\?\? "              "${RAVY_PROMPT_GIT_UNTRACKED-#}"
    )
    for (( k = 1; k <= $#st_parser; k += 2 )) do
      if st_count=$(grep -E -c "${st_parser[k]}" <<< "$git_st" 2>/dev/null); then
        st_str+="${st_parser[k+1]}"
        (( st_count > 1 )) && st_str+=$st_count
      fi
    done
    export _RAVY_PROMPT_GIT_READ="${ref}"
    export _RAVY_PROMPT_GIT_ST_READ="${st_str}"
  else
    unset _RAVY_PROMPT_GIT_READ _RAVY_PROMPT_GIT_ST_READ
  fi
}

setopt PROMPT_SUBST

_la=""

export RAVY_PROMPT_LAST_CMD_STATUS="%F{240}\${_RAVY_PROMPT_TIMER_READ} %(?..%F{160}\$(nice_exit_code))"
export RAVY_PROMPT_SYMBOL="%K{234}%E%F{234}%K{28}$_la %F{28}%K{234}$_la "
export RAVY_PROMPT_USER=${SSH_CONNECTION:+%F\{93\}%n }
export RAVY_PROMPT_PATH="%F{6}%~ "
export RAVY_PROMPT_GIT="%F{64}\${_RAVY_PROMPT_GIT_READ}%F{178}\${_RAVY_PROMPT_GIT_READ:+\$_RAVY_PROMPT_GIT_ST_READ }"
export RAVY_PROMPT_X="%F{166}\${DISPLAY:+X }"
export RAVY_PROMPT_JOBS="%F{163}%(1j.&%j. )"
export RAVY_PROMPT_CUSTOMIZE=""
export RAVY_PROMPT_CMD="%F{240}%k❯%f "
export RAVY_RPROMPT2_CMD="%F{240}❮%^"

unset _la _pd

# render status for last command
_ravy_prompt_last_command_status () {
  print -P "${RAVY_PROMPT_LAST_CMD_STATUS}"
}

export PROMPT="\${RAVY_PROMPT_SYMBOL}\${RAVY_PROMPT_USER}\${RAVY_PROMPT_PATH}${RAVY_PROMPT_GIT}${RAVY_PROMPT_X}\${RAVY_PROMPT_JOBS}\${RAVY_PROMPT_CUSTOMIZE}"$'\n'"\${RAVY_PROMPT_CMD}"
unset RPROMPT
export PROMPT2="\${RAVY_PROMPT_CMD}"
export RPROMPT2="\${RAVY_RPROMPT2_CMD}"

add-zsh-hook preexec _ravy_prompt_timer_start
add-zsh-hook precmd _ravy_prompt_timer_stop
add-zsh-hook precmd _ravy_prompt_git
add-zsh-hook precmd _ravy_prompt_last_command_status

# }}}

# Terminal title {{{

# Set the terminal or terminal multiplexer title.
_ravy_termtitle () {
  local formatted
  zformat -f formatted "%s" "s:$argv"

  # print table title
  printf "\e]1;%s\a" "${(V%)formatted}"

  # print window title
  if [[ $TERM =~ ^screen ]]; then
    printf "\ek%s\e\\" "${(V%)formatted}"
  else
    printf "\e]2;%s\a" "${(V%)formatted}"
  fi
}

# Set the terminal title with current command.
_ravy_termtitle_command () {
  emulate -L zsh
  setopt EXTENDED_GLOB

  # Get the command name that is under job control.
  if [[ "${2[(w)1]}" == (fg|%*)(\;|) ]]; then
    # Get the job name, and, if missing, set it to the default %+.
    local job_name="${${2[(wr)%*(\;|)]}:-%+}"

    # Make a local copy for use in the subshell.
    local -A jobtexts_from_parent_shell
    jobtexts_from_parent_shell=(${(kv)jobtexts})

    jobs "$job_name" 2>/dev/null > >(
      read -r index discarded
      # The index is already surrounded by brackets: [0].
      _ravy_termtitle_command "${(e):-\$jobtexts_from_parent_shell$index}"
    )
  else
    # Set the command name, or in the case of sudo or ssh, the next command.
    local cmd="${${2[(wr)^(*=*|sudo|ssh|-*)]}:t}"
    local truncated_cmd="!${cmd/(#m)?(#c16,)/${MATCH[1,14]}..}"
    unset MATCH

    _ravy_termtitle "$truncated_cmd"
  fi
}

# Set the terminal title with current path.
_ravy_termtitle_path () {
  emulate -L zsh
  setopt EXTENDED_GLOB

  local abbreviated_path="${PWD/#$HOME/~}"
  local truncated_path="${abbreviated_path/(#m)?(#c16,)/..${MATCH[-14,-1]}}"
  unset MATCH

  _ravy_termtitle "$truncated_path"
}

if [[ ! $TERM =~ ^(dumb|linux|.*bsd.*|eterm.*)$ ]]; then
  add-zsh-hook preexec _ravy_termtitle_command
  add-zsh-hook precmd _ravy_termtitle_path
fi

# }}}

# Background Singleton Process {{{

# Run given command only if there is not one running.
singleton-command () { pgrep -f "(^| |/)$#( |\$)" > /dev/null || exec "$@"; }

# Run singleton-command in background.
singleton-command-background () { (singleton-command "$@" &) &>/dev/null; }

# clipboard monitor
[[ $OSTYPE =~ ^darwin ]] && singleton-command-background cbmonitor

# }}}

# Custom {{{

[[ -f $RAVY_CUSTOM/zshrc ]] && source "$RAVY_CUSTOM/zshrc"

# }}}
