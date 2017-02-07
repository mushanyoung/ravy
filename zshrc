# Modeline & Load {{{
# vim: set foldlevel=0 foldmethod=marker filetype=zsh:

# prevent from loading more than once
[[ $RAVY_LOADED ]] && return 0 || RAVY_LOADED=true

# load zshenv to make sure paths are set correctly
source "${0:A:h}/zshenv"

# Load zprof if profiling is enabled.
[[ $RAVY_PROFILE ]] && zmodload zsh/zprof

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

  ravy::zle::forward_word_bash () {
    select-word-style bash
    zle forward-word-match
  }
  ravy::zle::backward_word_bash () {
    select-word-style bash
    zle backward-word-match
  }
  ravy::zle::backward_kill_word_bash () {
    select-word-style bash
    zle backward-kill-word-match
  }
  zle -N ravy::zle::forward_word_bash
  zle -N ravy::zle::backward_word_bash
  zle -N ravy::zle::backward_kill_word_bash
  bindkey "\ef" ravy::zle::forward_word_bash
  bindkey "\eb" ravy::zle::backward_word_bash
  bindkey "\ew" ravy::zle::backward_kill_word_bash
  bindkey "^F" forward-word
  bindkey "^B" backward-word
  bindkey "^W" backward-kill-word

  # ranger file explorer
  ravy::zle::ranger_cd () {
    tempfile=$(mktemp)
    ranger --choosedir="$tempfile" "${@:-$(pwd)}" < "$TTY"
    if [[ -f "$tempfile" && "$(cat -- "$tempfile")" != "$(pwd)" ]]; then
      cd -- "$(cat "$tempfile")" || return
    fi
    rm -f -- "$tempfile"
    zle redisplay
    zle -M ""
  }
  zle -N ravy::zle::ranger_cd
  bindkey "^K" ravy::zle::ranger_cd

  # toggle glob for current command line
  ravy::zle::glob_toggle () {
    [[ $BUFFER ]] || zle up-history
    [[ $BUFFER =~ ^noglob ]] && LBUFFER="${LBUFFER#noglob }" || LBUFFER="noglob $LBUFFER"
  }
  zle -N ravy::zle::glob_toggle
  bindkey "^R" ravy::zle::glob_toggle

  # toggle sudo for current command line
  ravy::zle::sudo_toggle () {
    [[ $BUFFER ]] || zle up-history
    [[ $BUFFER =~ ^sudo ]] && LBUFFER="${LBUFFER#sudo }" || LBUFFER="sudo $LBUFFER"
  }
  zle -N ravy::zle::sudo_toggle
  bindkey "^S" ravy::zle::sudo_toggle

  # fancy_ctrl_z
  ravy::zle::fancy_ctrl_z () {
    if [[ $#BUFFER -eq 0 ]]; then
      BUFFER="fg"
      zle accept-line
    else
      zle push-input
      zle clear-screen
    fi
  }
  zle -N ravy::zle::fancy_ctrl_z
  bindkey "^Z" ravy::zle::fancy_ctrl_z

  # menu select and completion
  bindkey "^I" expand-or-complete

  zmodload zsh/complist
  zle -C complete-menu menu-select _generic
  ravy::zle::complete_menu () {
    setopt localoptions alwayslastprompt
    zle complete-menu
  }
  zle -N ravy::zle::complete_menu
  bindkey "^T" ravy::zle::complete_menu
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

  ravy::zle::fzf::files () {
    local out key file_list file_str zle_clear_cmd="redisplay"
    setopt localoptions pipefail
    out=$(eval "${FZF_FILES_COMMAND:-ag -a -g ''}" 2>/dev/null \
      | FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS} -m --reverse --exit-0 --expect=ctrl-a,ctrl-d,ctrl-e,ctrl-o ${FZF_FILES_OPT}" fzf)
    key=$(head -1 <<< $out)
    file_list=("${(f)$(tail -n +2 <<< $out)}")
    if [[ $file_list ]]; then
      # escape space, unescape break line
      file_str="${$(echo ${(q)file_list[*]})/\\\~\//~/}"
      if [[ ! $key =~ [AaDdOoEe]$ ]]; then
        zle -R "$file_str" "(A)ppend, (E)dit, change (D)irectory, (O)pen, (Esc):"
      fi
      while [[ ! $key =~ [AaDdOoEe]$ ]]; do read -r -k key; done
      if [[ $key =~ [Aa]$ ]]; then
        LBUFFER="${LBUFFER% }${LBUFFER:+ }$file_str"
      elif [[ $key =~ [Dd]$ ]]; then
        file_str="${file_list[1]/#\~/$HOME}"
        [[ -d $file_str ]] || file_str="${file_str:h}"
        cd -- "$file_str" || return
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

  # hidden files
  ravy::zle::fzf::files::hidden() {
    FZF_FILES_COMMAND="ag -a --hidden -g ''" ravy::zle::fzf::files
  }

  # directories
  ravy::zle::fzf::files::directories() {
    FZF_FILES_COMMAND="find . -type d -not -path '*/\.*' | sed 1d | cut -b3-" ravy::zle::fzf::files
  }

  # hidden directories
  ravy::zle::fzf::files::directories::hidden() {
    FZF_FILES_COMMAND="find . -type d | sed 1d | cut -b3-" ravy::zle::fzf::files
  }

  # recent files of vim
  ravy::zle::fzf::files::vim () {
    FZF_FILES_COMMAND="grep '^>' ~/.viminfo | cut -b3-" ravy::zle::fzf::files
  }

  # open session matched by query, create a new one if there is no match
  ravy::zle::fzf::vim_sessions () {
    local session
    session=$(cd ~/.vim/sessions && find . \
      | cut -b3- | sed -e "1d" -e 's/\.vim$//' | fzf --exit-0 --reverse)
    if [[ $session ]]; then
      cd -- ${$(grep '^cd' ~/.vim/sessions/"$session".vim \
        | head -1 \
        | cut -d" " -f2-)/#\~/$HOME}
      BUFFER="vim '+OpenSession $session'"
      zle reset-prompt
      zle accept-line
    fi
  }

  # CTRL-R - Paste the selected command from history into the command line
  ravy::zle::fzf::history () {
    local selected num
    setopt localoptions noglobsubst pipefail 2> /dev/null
    selected=( $(fc -l 1 \
      | FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} $FZF_DEFAULT_OPTS +s --tac -n2..,.. --tiebreak=index --toggle-sort=ctrl-r $FZF_CTRL_R_OPTS --query=${(q)LBUFFER} +m --reverse" fzf ) )
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

  zle -N ravy::zle::fzf::files
  zle -N ravy::zle::fzf::files::hidden
  zle -N ravy::zle::fzf::files::directories
  zle -N ravy::zle::fzf::files::directories::hidden
  zle -N ravy::zle::fzf::files::vim
  zle -N ravy::zle::fzf::vim_sessions
  zle -N ravy::zle::fzf::history

  bindkey "\eo" ravy::zle::fzf::files
  bindkey "\eO" ravy::zle::fzf::files::hidden
  bindkey "\ed" ravy::zle::fzf::files::directories
  bindkey "\eD" ravy::zle::fzf::files::directories::hidden
  bindkey "\ev" ravy::zle::fzf::files::vim
  bindkey "\es" ravy::zle::fzf::vim_sessions
  bindkey "\er" ravy::zle::fzf::history
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

  # load plugins
  zplug load

  # zsh syntax highlighting
  ZSH_HIGHLIGHT_HIGHLIGHTERS=(main line root)
  ZSH_HIGHLIGHT_STYLES=(
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
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=240"
  ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=(
  "backward-delete-char" "complete-menu" "expand-or-complete"
  )
fi

# }}}

# Environment {{{

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

# lang
export LANG=en_US.UTF-8
export LANGUAGE=$LANG

# Colors
export CLICOLOR=xterm-256color
export LSCOLORS=

# enable 256color for xterm if connects to Display
[[ $DISPLAY && $TERM == "xterm" ]] && export TERM=xterm-256color

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
[[ $MANPATH != :* ]] && MANPATH=":$MANPATH"

# editor
export EDITOR=vim
export GIT_EDITOR=vim
alias vi=vim
alias v=vim

# ls color evaluations
hash dircolors &>/dev/null && dircolor_cmd=dircolors
hash gdircolors &>/dev/null && dircolor_cmd=gdircolors
[[ $dircolor_cmd ]] && eval "$($dircolor_cmd -b "$RAVY_HOME/LS_COLORS")"

# }}}

# Completions {{{

# Options
setopt COMPLETE_IN_WORD    # Complete from both ends of a word.
setopt ALWAYS_TO_END       # Move cursor to the end of a completed word.
setopt PATH_DIRS           # Do path search even on command names with slashes.
setopt AUTO_MENU           # Show completion menu on a successive tab press.
setopt AUTO_LIST           # Automatically list choices on ambiguous completion.
setopt AUTO_PARAM_SLASH    # Add trailing slash for completed directory.
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
kgrep () { pgrep -f "$1" | xargs kill -9; }

# wrapper of zsh-bd, cd up 1 level by default
d () { bd "${@:-1}"; }
compctl -V directories -K _bd d

# Codi: launch an interactive repl scratchpad within vim
# Usage: codi [filetype] [filename]
codi() {
  local syntax="${1:-python}"
  shift
  vim -c "let g:startify_disable_at_vimenter = 1 |\
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
  pip2 list --outdated | awk "!/Could not|ignored/ {print \$1}" | xargs pip2 install -U
}
pip3-update-all () {
  pip3 list --outdated | awk "!/Could not|ignored/ {print \$1}" | xargs pip3 install -U
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
alias ravy="cd \$RAVY_HOME"
alias ravycustom="cd \$RAVY_CUSTOM_HOME"
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
ravy::prompt::timer_now () {
  perl -MTime::HiRes -e 'printf("%.0f\n",Time::HiRes::time()*1000)'
}

# get human readable representation of time
ravy::prompt::timer_format () {
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
ravy::prompt::timer_start () {
  [[ $_RAVY_PROMPT_TIMER ]] || _RAVY_PROMPT_TIMER=$(ravy::prompt::timer_now)
}

# get elapsed time without stopping timer
ravy::prompt::timer_get () {
  [[ $_RAVY_PROMPT_TIMER ]] && ravy::prompt::timer_format $(($(ravy::prompt::timer_now) - _RAVY_PROMPT_TIMER))
}

# get elapsed time and stop timer
ravy::prompt::timer_stop () {
  _RAVY_PROMPT_TIMER_READ=$(ravy::prompt::timer_get)
  unset _RAVY_PROMPT_TIMER
}

# generate git prompt to _RAVY_PROMPT_GIT_READ
ravy::prompt::git () {
  local ref k git_st st_str st_count
  # exit if current directory is not a git repo
  if ref=$(command git symbolic-ref --short HEAD 2>/dev/null \
        || command git rev-parse --short HEAD 2>/dev/null); then
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

RAVY_PROMPT_CMD_RET="%F{240}\${_RAVY_PROMPT_TIMER_READ:+\$_RAVY_PROMPT_TIMER_READ }%(?..%F{160}\$(nice_exit_code))"
RAVY_PROMPT_SYMBOL="%K{234}%E%F{234}%K{28}$_la %F{28}%K{234}$_la "
RAVY_PROMPT_USER=${SSH_CONNECTION:+%F\{93\}%n }
RAVY_PROMPT_PATH="%F{6}%~ "
RAVY_PROMPT_GIT="%F{64}\${_RAVY_PROMPT_GIT_READ}%F{178}\${_RAVY_PROMPT_GIT_READ:+\$_RAVY_PROMPT_GIT_ST_READ }"
RAVY_PROMPT_X="%F{166}\${DISPLAY:+X }"
RAVY_PROMPT_JOBS="%F{163}%(1j.&%j. )"
RAVY_PROMPT_CUSTOMIZE=""
RAVY_PROMPT_CMD="%F{240}%k%_❯%f "

unset _la _pd

# render status for last command
ravy::prompt::command_ret () {
  print -P "${RAVY_PROMPT_CMD_RET}"
}

export PROMPT="\${RAVY_PROMPT_SYMBOL}\${RAVY_PROMPT_USER}\${RAVY_PROMPT_PATH}${RAVY_PROMPT_GIT}${RAVY_PROMPT_X}\${RAVY_PROMPT_JOBS}\${RAVY_PROMPT_CUSTOMIZE}"$'\n'"\${RAVY_PROMPT_CMD}"
export PROMPT2="\${RAVY_PROMPT_CMD}"
unset RPROMPT RPROMPT2

autoload -Uz zmv add-zsh-hook

add-zsh-hook preexec ravy::prompt::timer_start
add-zsh-hook precmd ravy::prompt::timer_stop
add-zsh-hook precmd ravy::prompt::git
add-zsh-hook precmd ravy::prompt::command_ret

# }}}

# Terminal title {{{

if [[ ! $TERM =~ ^(dumb|linux|.*bsd.*|eterm.*)$ ]]; then

  # Set the terminal or terminal multiplexer title.
  ravy::termtitle::settitle () {
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
  ravy::termtitle::command () {
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
        ravy::termtitle::command "${(e):-\$jobtexts_from_parent_shell$index}"
      )
    else
      # Set the command name, or in the case of sudo or ssh, the next command.
      local cmd="${${2[(wr)^(*=*|sudo|ssh|-*)]}:t}"
      local truncated_cmd="!${cmd/(#m)?(#c16,)/${MATCH[1,14]}..}"
      unset MATCH

      ravy::termtitle::settitle "$truncated_cmd"
    fi
  }

  # Set the terminal title with current path.
  ravy::termtitle::path () {
    emulate -L zsh
    setopt EXTENDED_GLOB

    local abbreviated_path="${PWD/#$HOME/~}"
    local truncated_path="${abbreviated_path/(#m)?(#c16,)/..${MATCH[-14,-1]}}"
    unset MATCH

    ravy::termtitle::settitle "$truncated_path"
  }

  add-zsh-hook preexec ravy::termtitle::command
  add-zsh-hook precmd ravy::termtitle::path
fi

# }}}

# Background Singleton Process {{{

# Run given command only if there is not one running.
singleton-command () { pgrep -f "(^| |/)$@( |\$)" > /dev/null || eval "$@"; }

# Run singleton-command in background.
singleton-command-background () { (singleton-command "$@" &) &>/dev/null; }

# clipboard monitor
[[ $OSTYPE =~ ^darwin ]] && singleton-command-background cbmonitor

# }}}

# Custom {{{

[[ -f $RAVY_CUSTOM_HOME/zshrc ]] && source "$RAVY_CUSTOM_HOME/zshrc"

# }}}
