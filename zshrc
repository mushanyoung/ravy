# Modeline & Load {{{
# vim: set foldlevel=0 foldmethod=marker filetype=zsh:

# prevent from loading more than once
[[ -n $RAVY_LOADED ]] && return 0
RAVY_LOADED=true

# load zshenv to make sure paths are set correctly
source ${0:A:h}/zshenv

# load lib
source ${0:A:h}/lib.zsh

# record time to initialize shell environment
_rv_prompt_timer_start

# }}}

# Zplug START {{{

if [[ -f ~/.zplug/init.zsh ]]; then
  # zplug env
  unset ZPLUG_SHALLOW
  ZPLUG_CLONE_DEPTH=1

  # load zplug
  source ~/.zplug/init.zsh

  # duplicate to get both binary included by zplug
  zplug 'junegunn/fzf', as:command, use:"bin", hook-build:'./install --bin >/dev/null'
  zplug 'junegunn/fzf', as:command, use:"bin/fzf-tmux"
  zplug 'junegunn/fzf', use:"shell/key-bindings.zsh"

  zplug "supercrabtree/k"
  zplug "djui/alias-tips"
  zplug "bric3/nice-exit-code"
  zplug "micha/resty"
  zplug "joshuarubin/zsh-archive"
  zplug "zsh-users/zsh-completions"
  zplug "Tarrasch/zsh-bd"

  zplug "zsh-users/zsh-syntax-highlighting", nice:17
  zplug "zsh-users/zsh-history-substring-search", nice:18
  zplug "zsh-users/zsh-autosuggestions", nice:19

  # Install plugins if there are plugins that have not been installed
  if ! zplug check --verbose; then
    printf "Install? [y/N]: "
    if read -q; then
      echo; zplug install
    fi
  fi

  # Pre zplug settings

  # alias-tips
  export ZSH_PLUGINS_ALIAS_TIPS_TEXT="Alias: "

  # zsh syntax highlighting
  ZSH_HIGHLIGHT_HIGHLIGHTERS=(main line root)

  typeset -A ZSH_HIGHLIGHT_STYLES
  ZSH_HIGHLIGHT_STYLES=(
  'unknown-token'            'fg=red,bold'
  'reserved-word'            'fg=yellow'
  'builtin'                  'fg=green,bold'
  'function'                 'fg=white,bold'
  'command'                  'fg=green'
  'alias'                    'fg=green'
  'suffix-alias'             'fg=green,underline'
  'hashed-command'           'fg=green'
  'precommand'               'fg=magenta'
  'path'                     'fg=cyan'
  'commandseparator'         'fg=white,bold'
  'globbing'                 'fg=blue'
  'single-hyphen-option'     'fg=yellow'
  'double-hyphen-option'     'fg=yellow'
  'single-quoted-argument'   'fg=yellow,bold'
  'dollar-quoted-argument'   'fg=yellow,bold'
  'double-quoted-argument'   'fg=yellow'
  'back-quoted-argument'     'fg=blue'
  'assign'                   'fg=magenta,bold'
  'redirection'              'fg=white,bold'
  'comment'                  'fg=black,bold'
  'default'                  'none'
  )

fi

# }}}

# Zle {{{

KEYTIMEOUT=1

# use emacs mode for command line
bindkey -e

# ctrl-a and ctrl-e
bindkey '^A' beginning-of-line
bindkey '^E' end-of-line

# undo and redo
bindkey '^_' undo
bindkey '\e-' redo

# zsh-history-substring-search: bind ^P and ^N to it
bindkey '^P' history-substring-search-up
bindkey '^N' history-substring-search-down

# autosuggestion
bindkey '\ek' autosuggest-clear

# Use C-x C-e to edit the current command line in editor
autoload -U edit-command-line
zle -N edit-command-line
bindkey '\C-x\C-e' edit-command-line

# Smart URLs
autoload -Uz url-quote-magic
zle -N self-insert url-quote-magic

# M-. and M-m to insert word in previous lines
autoload -Uz copy-earlier-word
zle -N copy-earlier-word
bindkey '\em' copy-earlier-word
bindkey '\e.' insert-last-word

# chars treated as a part of a word
WORDCHARS=$'\'\\/*?_-.,[]~&;!#$%^(){}<>+:=@'

# C-B / C-F to move, C-W to kill by word
# M-b / M-f to move, M-w to kill by word with bash style
autoload -U select-word-style
autoload -U backward-kill-word-match
autoload -U forward-word-match
autoload -U backward-word-match
zle -N backward-kill-word-match
zle -N forward-word-match
zle -N backward-word-match

forward-word-alter () {
  select-word-style bash
  zle forward-word-match
}
backward-word-alter () {
  select-word-style bash
  zle backward-word-match
}
backward-kill-word-alter () {
  select-word-style bash
  zle backward-kill-word-match
}
zle -N forward-word-alter
zle -N backward-word-alter
zle -N backward-kill-word-alter
bindkey '\ef' forward-word-alter
bindkey '\eb' backward-word-alter
bindkey '\ew' backward-kill-word-alter
bindkey '^F' forward-word
bindkey '^B' backward-word
bindkey '^W' backward-kill-word

# ranger file explorer
ranger-cd () {
  tempfile=$(mktemp)
  ranger --choosedir="$tempfile" "${@:-$(pwd)}" < $TTY
  if [[ -f "$tempfile" && "$(cat -- "$tempfile")" != "$(echo -n `pwd`)" ]]; then
    cd -- "$(cat "$tempfile")"
  fi
  rm -f -- "$tempfile"
  zle redisplay
  zle -M ""
}
zle -N ranger-cd
bindkey '^K' ranger-cd

# Use FZF to modify the current word with tmux words
fzf-tmux-words-widget () {
  if [[ -z "$TMUX_PANE" ]]; then
    return 1
  fi
  local prefix tokens word

  # Extract the last word, or empty string when starting a new word.
  if [[ ! -n $LBUFFER || ${LBUFFER[-1]} == ' ' ]]; then
    word=""
    prefix=$LBUFFER
  else
    tokens=(${(z)LBUFFER})
    word=${tokens[-1]}
    prefix=${LBUFFER:0:-$#word}
  fi

  if word=$( tmuxwords | fzf -q "$word" ); then
    LBUFFER="$prefix$word"
    zle redisplay
  fi
}
zle -N fzf-tmux-words-widget
bindkey '\eF' fzf-tmux-words-widget

# fzf default completion
bindkey '^R' fzf-history-widget
bindkey '^T' fzf-file-widget
bindkey '\et' fzf-cd-widget

# toggle glob for current command line
glob-toggle () {
  [[ -z $BUFFER ]] && zle up-history
  if [[ $BUFFER == noglob\ * ]]; then
    LBUFFER="${LBUFFER#noglob }"
  else
    LBUFFER="noglob $LBUFFER"
  fi
}
zle -N glob-toggle
bindkey '\eg' glob-toggle

# toggle sudo for current command line
sudo-toggle () {
  [[ -z $BUFFER ]] && zle up-history
  if [[ $BUFFER == sudo\ * ]]; then
    LBUFFER="${LBUFFER#sudo }"
  else
    LBUFFER="sudo $LBUFFER"
  fi
}
zle -N sudo-toggle
bindkey '^S' sudo-toggle

# fancy-ctrl-z
fancy-ctrl-z () {
  if [[ $#BUFFER -eq 0 ]]; then
    BUFFER="fg"
    zle accept-line
  else
    zle push-input
    zle clear-screen
  fi
}
zle -N fancy-ctrl-z
bindkey '^Z' fancy-ctrl-z

# menu select and completion
bindkey '^I' expand-or-complete

zmodload zsh/complist
zle -C complete-menu menu-select _generic
_complete_menu () {
  setopt localoptions alwayslastprompt
  zle complete-menu
}
zle -N _complete_menu
bindkey '^J' _complete_menu
bindkey -M menuselect '^F' forward-word
bindkey -M menuselect '^B' backward-word
bindkey -M menuselect '^J' forward-char
bindkey -M menuselect '^K' backward-char
bindkey -M menuselect '/' history-incremental-search-forward
bindkey -M menuselect '^?' undo
bindkey -M menuselect '^C' undo

# }}}

# Zplug END {{{

if [[ -f ~/.zplug/init.zsh && -z $ZPLUG_LOADED ]]; then
  ZPLUG_LOADED=true

  # load plugins managed by zplug
  zplug load --verbose 2>/dev/null

  # Post zplug settings
  # zsh auto suggestions
  ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=(
  'backward-delete-char' 'complete-menu' 'expand-or-complete'
  )
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=240'
fi

# }}}

# Environment {{{

# lang
LANG=en_US.UTF-8
LANGUAGE=$LANG

# General
setopt BRACE_CCL          # Allow brace character class list expansion.
setopt COMBINING_CHARS    # Combine zero-length punctuation characters (accents) with the base character.
setopt RC_QUOTES          # Allow 'Henry''s Garage' instead of 'Henry'\''s Garage'.
unsetopt MAIL_WARNING     # Don't print a warning message if a mail file has been accessed.

# Jobs
setopt LONG_LIST_JOBS     # List jobs in the long format by default.
setopt AUTO_RESUME        # Attempt to resume existing job before creating a new process.
setopt NOTIFY             # Report status of background jobs immediately.
unsetopt BG_NICE          # Don't run all background jobs at a lower priority.
unsetopt HUP              # Don't kill jobs on shell exit.
unsetopt CHECK_JOBS       # Don't report on jobs when shell exit.

# History
HISTFILE=~/.zhistory             # The path to the history file.
HISTSIZE=10000                   # The maximum number of events to save in the internal history.
SAVEHIST=10000                   # The maximum number of events to save in the history file.

setopt BANG_HIST                 # Treat the '!' character specially during expansion.
setopt EXTENDED_HISTORY          # Write the history file in the ':start:elapsed;command' format.
setopt INC_APPEND_HISTORY        # Write to the history file immediately, not when the shell exits.
setopt SHARE_HISTORY             # Share history between all sessions.
setopt HIST_EXPIRE_DUPS_FIRST    # Expire a duplicate event first when trimming history.
setopt HIST_IGNORE_DUPS          # Do not record an event that was just recorded again.
setopt HIST_IGNORE_ALL_DUPS      # Delete an old recorded event if a new event is a duplicate.
setopt HIST_IGNORE_SPACE         # executed commands with leading space do not go into history
setopt HIST_FIND_NO_DUPS         # Do not display a previously found event.
setopt HIST_IGNORE_SPACE         # Do not record an event starting with a space.
setopt HIST_SAVE_NO_DUPS         # Do not write a duplicate event to the history file.
setopt HIST_VERIFY               # Do not execute immediately upon history expansion.
setopt HIST_BEEP                 # Beep when accessing non-existent history.

# disable auto correcting
unsetopt CORRECT_ALL
unsetopt CORRECT

# Colors
CLICOLOR=xterm-256color
LSCOLORS=

# enable 256color for xterm if connects to Display
if [[ -n $DISPLAY && $TERM == "xterm" ]]; then
  export TERM=xterm-256color
fi

# pager
PAGER="less"
LESS="FRSXMi"

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
  eval $(dircolors -b $RAVY/LS_COLORS)
elif hash gdircolors &>/dev/null; then
  # coreutils from brew
  eval $(gdircolors -b $RAVY/LS_COLORS)
fi

# load zsh modules
autoload -Uz zmv add-zsh-hook

# }}}

# FZF {{{

FZF_DEFAULT_COMMAND='ag -g ""'
FZF_CTRL_T_COMMAND='ag -g ""'
FZF_DEFAULT_OPTS='--select-1 --exit-0'
FZF_COMPLETION_TRIGGER='**'

alias fzf='fzf-tmux'

# Open the selected file
#   - CTRL-O to open with `open` command,
#   - CTRL-E or Enter key to open with the $EDITOR
#   - Bypass fuzzy finder if there's only one match (--select-1)
#   - Exit if there's no match (--exit-0)
fo () {
  local out file key cmd
  out=$(fzf --query="$1" --exit-0 --expect=ctrl-o,ctrl-e)
  key=$(head -1 <<< "$out")
  file=$(head -2 <<< "$out" | tail -1)
  if [[ "$key" == 'ctrl-o' ]]; then
    cmd='open'
  else
    cmd=${EDITOR:-vim}
  fi
  if [[ -n "$file" ]]; then
    echo $file
    $cmd "$file"
  fi
}

# open recent files of vim
fv () {
  local files
  files=$(grep '^>' ~/.viminfo | cut -c3- |
  while read line; do
    [[ -f "${line/\~/$HOME}" ]] && echo "$line"
  done | fzf -d -m -1 -q "$*") && vim -- ${files//\~/$HOME}
}

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
zstyle ':completion::complete:*' use-cache on
zstyle ':completion::complete:*' cache-path "${HOME}/.zcompcache"

# Case-insensitive (all), partial-word, and then substring completion.
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
unsetopt CASE_GLOB

# Group matches and describe.
zstyle ':completion:*:*:*:*:*' menu select
zstyle ':completion:*:matches' group 'yes'
zstyle ':completion:*:options' description 'yes'
zstyle ':completion:*:options' auto-description '%d'
zstyle ':completion:*:corrections' format ' %F{green}-- %d (errors: %e) --%f'
zstyle ':completion:*:descriptions' format ' %F{yellow}-- %d --%f'
zstyle ':completion:*:messages' format ' %F{purple} -- %d --%f'
zstyle ':completion:*:warnings' format ' %F{red}-- no matches found --%f'
zstyle ':completion:*:default' list-prompt '%S%M matches%s'
zstyle ':completion:*' format ' %F{yellow}-- %d --%f'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' verbose yes

# Fuzzy match mistyped completions.
zstyle ':completion:*' completer _complete _match _approximate
zstyle ':completion:*:match:*' original only
zstyle ':completion:*:approximate:*' max-errors 1 numeric

# Increase the number of errors based on the length of the typed word.
zstyle -e ':completion:*:approximate:*' max-errors 'reply=($((($#PREFIX+$#SUFFIX)/3))numeric)'

# Don't complete unavailable commands.
zstyle ':completion:*:functions' ignored-patterns '(_*|pre(cmd|exec))'

# Array completion element sorting.
zstyle ':completion:*:*:-subscript-:*' tag-order indexes parameters

# Directories
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:*:cd:*' tag-order local-directories directory-stack path-directories
zstyle ':completion:*:*:cd:*:directory-stack' menu yes select
zstyle ':completion:*:-tilde-:*' group-order 'named-directories' 'path-directories' 'users' 'expand'
zstyle ':completion:*' squeeze-slashes true

# History
zstyle ':completion:*:history-words' stop yes
zstyle ':completion:*:history-words' remove-all-dups yes
zstyle ':completion:*:history-words' list false
zstyle ':completion:*:history-words' menu yes

# Don't complete uninteresting users...
zstyle ':completion:*:*:*:users' ignored-patterns \
  adm amanda apache avahi beaglidx bin cacti canna clamav daemon \
  dbus distcache dovecot fax ftp games gdm gkrellmd gopher \
  hacluster haldaemon halt hsqldb ident junkbust ldap lp mail \
  mailman mailnull mldonkey mysql nagios \
  named netdump news nfsnobody nobody nscd ntp nut nx openvpn \
  operator pcap postfix postgres privoxy pulse pvm quagga radvd \
  rpc rpcuser rpm shutdown squid sshd sync uucp vcsa xfs '_*'

# ... unless we really want to.
zstyle '*' single-ignored show

# Ignore multiple entries.
zstyle ':completion:*:(rm|kill|diff):*' ignore-line other
zstyle ':completion:*:rm:*' file-patterns '*:all-files'

# Kill
zstyle ':completion:*:*:*:*:processes' command 'ps -u $LOGNAME -o pid,user,command -w'
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=01;36=0=01'
zstyle ':completion:*:*:kill:*' menu yes select
zstyle ':completion:*:*:kill:*' force-list always
zstyle ':completion:*:*:kill:*' insert-ids single

# Man
zstyle ':completion:*:manuals' separate-sections true
zstyle ':completion:*:manuals.(^1*)' insert-sections true

# }}}

# Util Functions & Aliases {{{

# Change dir to target folder or the parent folder of target file
cdd () {
  local file=$1
  if [[ -e $file ]]; then
    if [[ -f $file ]]; then
      cd -- ${file:h}
    else
      cd -- $file
    fi
  else
    false
  fi
}

# ping handles url
ping () {
  command ping $(echo $* | sed -E -e 's#https?://##' -e 's#/.*$##')
}

# interactive mv
imv () {
  local src dst
  for src; do
    [[ -e $src ]] || { print -u2 "$src does not exist"; continue }
    dst=$src
    vared dst
    [[ $src != $dst ]] && mkdir -p $dst:h && mv -n $src $dst
  done
}

# kill processes of current user containing a specific keyword
kill_keyword () {
  ps x | grep "$1" | awk '{print $1}' | xargs kill -9
}

# wrapper of zsh-bd, cd up 1 level by default
d () {
  if (($#<1)); then
    cd ..
  else
    bd $*
  fi
}
compctl -V directories -K _bd d

# list files, do not record in history
alias l=' ls-color'
alias ls=' ls'
alias ll=' ls -lFh'
alias la=' l -A'

# change directory, do not record in history
alias d=' d'
alias cd=' cd'
alias fl=' cd -'
alias ..=' cd ..'
alias pu=' pushd'
alias po=' popd'
alias dd=' d'

# abbreviations
alias g='git'
alias t='tmux'
alias sw='subl -n -w'
alias hs='history'
alias tf='tail -f'
alias rd='rmdir'
alias rb='ruby'

# python abbreviations
alias py='python2'
alias py2='python2'
alias py3='python3'
alias ipy='ipython2'
alias ipy2='ipython2'
alias ipy3='ipython3'
alias pip='pip2'
alias pip2u=$'pip2 list --outdated | awk \'!/Could not|ignored/ { print $1}\' | xargs pip2 install -U'
alias pip3u=$'pip3 list --outdated | awk \'!/Could not|ignored/ { print $1}\' | xargs pip3 install -U'

# http serve current working dir in a given port (8000 in default)
alias serve='python -m SimpleHTTPServer'

# print abosolute path for given file
alias realpath="perl -MCwd -e 'print Cwd::abs_path(shift), \"\\n\"'"

# Lists the ten most used commands.
alias history-stat="history 0 | awk '{print \$2}' | sort | uniq -c | sort -n -r | head"

# grep with default options
alias grep='grep --ignore-case --color=auto --exclude-dir={.bzr,.cvs,.git,.hg,.svn}'

# ps-color
alias pa='ps-color'
alias pc='HIGH_CPU_MEM_ONLY=1 pa'

# brew commands
alias bubo='brew update && brew outdated'
alias bubc='brew upgrade && brew cleanup'
alias bubu='bubo && bubc'

# Ravy commands
alias ravy="cd $RAVY"
alias ravycustom="cd $RAVY_CUSTOM"
alias ravyedit="$EDITOR ${0:A}"
alias ravysource="unset RAVY_LOADED; source ${0:A}"

# Open command through cbmonitor
open_remote () {
  echo 'open:['"$1"']' | clip
}

# }}}

# Prompt {{{

# Terminal title
if [[ "$TERM" != (dumb|linux|*bsd*|eterm*) ]]; then
  add-zsh-hook preexec _rv_termtitle_command
  add-zsh-hook precmd _rv_termtitle_path
fi

# Shell prompt
setopt PROMPT_SUBST

function {

local LA="" PD=" "

RV_PROMPT_LAST_CMD_STATUS=%F{240}\${_rv_prompt_timer_result:+\$_rv_prompt_timer_result$PD}%(?..%F{160}\$(nice_exit_code))
RV_PROMPT_SYMBOL=%K{234}%E%F{234}%K{28}${LA}\ %F{28}%K{234}$LA$PD
RV_PROMPT_USER=${SSH_CONNECTION:+%F\{93\}%n$PD}
RV_PROMPT_PATH=%F{6}%~$PD
RV_PROMPT_GIT=%F{64}\${_rv_prompt_git_result:+\$_rv_prompt_git_result$PD}
RV_PROMPT_X=%F{166}\${DISPLAY:+X$PD}
RV_PROMPT_JOBS=%F{163}%(1j.\&%j.$PD)
RV_PROMPT_CUSTOMIZE=""
RV_PROMPT_CMD="%F{240}%k❯%f "
RV_RPROMPT2_CMD="%F{240}❮%^"

}

# render status for last command
_rv_prompt_last_command_status () {
  print -P "${RV_PROMPT_LAST_CMD_STATUS}"
}

PROMPT=\${RV_PROMPT_SYMBOL}\${RV_PROMPT_USER}\${RV_PROMPT_PATH}${RV_PROMPT_GIT}${RV_PROMPT_X}\${RV_PROMPT_JOBS}\${RV_PROMPT_CUSTOMIZE}$'\n'\${RV_PROMPT_CMD}
unset RPROMPT
PROMPT2=\${RV_PROMPT_CMD}
RPROMPT2=\${RV_RPROMPT2_CMD}

add-zsh-hook preexec _rv_prompt_timer_start
add-zsh-hook precmd _rv_prompt_timer_stop
add-zsh-hook precmd _rv_prompt_git
add-zsh-hook precmd _rv_prompt_last_command_status

# }}}

# Background Singleton Process {{{

# Run given command only if there is not one running.
singleton-command () {
  if ! pgrep -f "(^| |/)$(basename "$1")( |\$)" > /dev/null; then
    exec $*
  fi
}

# Run singleton-command in background.
singleton-command-background () {
  (singleton-command "$1" &) &> /dev/null
}

# clipboard monitor
if [[ $(uname) == Darwin ]]; then
  singleton-command-background cbmonitor
fi

# }}}

# Custom {{{

[[ -f $RAVY_CUSTOM/zshrc ]] && source $RAVY_CUSTOM/zshrc

# }}}
