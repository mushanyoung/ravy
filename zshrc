# Modeline & Load {{{
# vim: set foldlevel=0 foldmethod=marker filetype=zsh:

# prevent from loading more than once
[[ -n $RAVY_LOADED ]] && return 0
RAVY_LOADED=true

# }}}

# Zplug {{{

if [[ -f ~/.zplug/zplug && -z $ZPLUG_NAME ]]; then
  source ~/.zplug/zplug

  # custom completion must set before zplug load
  if [[ -d $RAVY_CUSTOM/zsh-functions ]]; then
    fpath+=$RAVY_CUSTOM/zsh-functions
  fi

  # duplicate to get both binary included by zplug
  zplug 'junegunn/fzf', as:command, of:"bin/fzf", \
    do:'./install --bin --no-update-rc >/dev/null'
  zplug 'junegunn/fzf', as:command, of:"bin/fzf-tmux"

  zplug "supercrabtree/k"
  zplug "djui/alias-tips"
  zplug "unixorn/git-extra-commands"
  zplug "bric3/nice-exit-code"
  zplug "micha/resty"
  zplug "joshuarubin/zsh-archive"
  zplug "zsh-users/zsh-completions"

  zplug "zsh-users/zsh-syntax-highlighting", at:0.4.0, nice:17
  zplug "zsh-users/zsh-history-substring-search", nice:18
  zplug "zsh-users/zsh-autosuggestions", nice:19

  # Install plugins if there are plugins that have not been installed
  if ! zplug check --verbose; then
    printf "Install? [y/N]: "
    if read -q; then
        echo; zplug install
    fi
  fi

  # Then, source plugins and add commands to $PATH
  zplug load --verbose

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

  # zsh auto suggestions
  ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=(
    'backward-delete-char' 'complete-menu' 'fzf-completion'
  )
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=240'

  # alias-tips
  export ZSH_PLUGINS_ALIAS_TIPS_TEXT="Alias: "
fi

# FZF managed by zplug
if [[ -d ~/.zplug/repos/junegunn/fzf ]]; then
  # Auto-completion
  source ~/.zplug/repos/junegunn/fzf/shell/completion.zsh 2> /dev/null

  # Key bindings
  source ~/.zplug/repos/junegunn/fzf/shell/key-bindings.zsh

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
  fo() {
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

  # fuzzy open with editor from anywhere
  fog() {
    local files opt
    files=(${(f)"$(locate -i -0 ${@:-/} | grep -z -vE '~$' | fzf --read0 -0 -1 -m)"})
    if [[ -n $files ]]; then
      print -l $files[1]
      ${EDITOR:-vim} $files
    fi
  }

  # open recent files of vim
  fv() {
    local files
    files=$(grep '^>' ~/.viminfo | cut -c3- |
    while read line; do
      [[ -f "${line/\~/$HOME}" ]] && echo "$line"
    done | fzf -d -m -1 -q "$*") && vim -- ${files//\~/$HOME}
  }

  # fd - cd to selected directory
  fd() {
    local dir
    dir=$(find ${1:-*} -path '*/\.*' -prune \
      -o -type d -print 2> /dev/null | fzf +m) &&
      cd "$dir"
  }

  # fda - including hidden directories
  fda() {
    local dir
    dir=$(find ${1:-.} -type d 2> /dev/null | fzf +m) && cd "$dir"
  }

  # fdg - fuzzy cd from anywhere
  fdg () {
    local file opt
    file="$(locate -i -0 ${@:-/} | grep -z -vE '~$' | fzf --read0 -0 -1)"
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

fi

# }}}

# Environment {{{

# lang
LANG=en_US.UTF-8
LANGUAGE=$LANG

# Colors
CLICOLOR="xterm-256color"
LSCOLORS=

# General
setopt BRACE_CCL          # Allow brace character class list expansion.
setopt COMBINING_CHARS    # Combine zero-length punctuation characters (accents)
                          # with the base character.
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
if hash dircolors 2>/dev/null; then
  eval $(dircolors -b $RAVY/LS_COLORS)
elif hash gdircolors 2>/dev/null; then
  # coreutils from brew
  eval $(gdircolors -b $RAVY/LS_COLORS)
fi

# chars treated as a part of a word
WORDCHARS='*?_-.[]~&;!#$%^(){}<>/\+:=@'

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

# Environmental Variables
zstyle ':completion::*:(-command-|export):*' fake-parameters ${${${_comps[(I)-value-*]#*,}%%,*}:#-*-}

# Populate hostname completion.
zstyle -e ':completion:*:hosts' hosts 'reply=(
  ${=${=${=${${(f)"$(cat {/etc/ssh_,~/.ssh/known_}hosts(|2)(N) 2>/dev/null)"}%%[#| ]*}//\]:[0-9]*/ }//,/ }//\[/ }
  ${=${(f)"$(cat /etc/hosts(|)(N) <<(ypcat hosts 2>/dev/null))"}%%\#*}
  ${=${${${${(@M)${(f)"$(cat ~/.ssh/config 2>/dev/null)"}:#Host *}#Host }:#*\**}:#*\?*}}
)'

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

# SSH/SCP/RSYNC
zstyle ':completion:*:(scp|rsync):*' tag-order 'hosts:-host:host hosts:-domain:domain hosts:-ipaddr:ip\ address *'
zstyle ':completion:*:(scp|rsync):*' group-order users files all-files hosts-domain hosts-host hosts-ipaddr
zstyle ':completion:*:ssh:*' tag-order 'hosts:-host:host hosts:-domain:domain hosts:-ipaddr:ip\ address *'
zstyle ':completion:*:ssh:*' group-order users hosts-domain hosts-host users hosts-ipaddr
zstyle ':completion:*:(ssh|scp|rsync):*:hosts-host' ignored-patterns '*(.|:)*' loopback ip6-loopback localhost ip6-localhost broadcasthost
zstyle ':completion:*:(ssh|scp|rsync):*:hosts-domain' ignored-patterns '<->.<->.<->.<->' '^[-[:alnum:]]##(.[-[:alnum:]]##)##' '*@*'
zstyle ':completion:*:(ssh|scp|rsync):*:hosts-ipaddr' ignored-patterns '^(<->.<->.<->.<->|(|::)([[:xdigit:].]##:(#c,2))##(|%*))' '127.0.0.<->' '255.255.255.255' '::1' 'fe80::*'

# }}}

# Terminal Title {{{

if [[ "$TERM" != (dumb|linux|*bsd*|eterm*) ]]; then

  # Sets the terminal or terminal multiplexer title.
  function _rv_termtitle_set {
    local title_format{,ted}
    title_format="%s"
    zformat -f title_formatted "$title_format" "s:$argv"

    if [[ "$TERM" == screen* ]]; then
      title_format="\ek%s\e\\"
    else
      title_format="\e]2;%s\a"
    fi

    printf "$title_format" "${(V%)title_formatted}"
  }

  # Sets the terminal title with a given command.
  function _rv_termtitle_set_command {
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
      read index discarded
      # The index is already surrounded by brackets: [1].
      _rv_termtitle_set_command "${(e):-\$jobtexts_from_parent_shell$index}"
      )
    else
      # Set the command name, or in the case of sudo or ssh, the next command.
      local cmd="${${2[(wr)^(*=*|sudo|ssh|-*)]}:t}"
      local truncated_cmd="!${cmd/(#m)?(#c16,)/${MATCH[1,14]}..}"
      unset MATCH

      _rv_termtitle_set "$truncated_cmd"
    fi
  }

  # Sets the terminal title with a given path.
  function _rv_termtitle_set_path {
    emulate -L zsh
    setopt EXTENDED_GLOB

    local abbreviated_path="${PWD/#$HOME/~}"
    local truncated_path="${abbreviated_path/(#m)?(#c16,)/..${MATCH[-14,-1]}}"
    unset MATCH

    _rv_termtitle_set "$truncated_path"
  }

  # auto set terminal title
  add-zsh-hook preexec _rv_termtitle_set_command
  add-zsh-hook precmd _rv_termtitle_set_path
fi

# }}}

# Util Functions & Aliases {{{

# Change dir up x level
cdup () {
  local level=${1:-1}
  local tarpwd=$PWD
  while [[ level -gt '0' ]]; do
    level=$((level - 1))
    tarpwd=$(dirname $tarpwd)
  done
  cd $tarpwd
}

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
imv() {
  local src dst
  for src; do
    [[ -e $src ]] || { print -u2 "$src does not exist"; continue }
    dst=$src
    vared dst
    [[ $src != $dst ]] && mkdir -p $dst:h && mv -n $src $dst
  done
}

# list files, do not record in history
alias l=' ls-color'
alias ls=' ls'
alias ll=' ls -lFh'
alias la=' l -A'

# change directory, do not record in history
alias d=' cdup'
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

# ps-color
alias pa='ps-color'
alias pc='HIGH_CPU_MEM_ONLY=1 pa'

# grep with options
alias grep='grep --ignore-case --color=auto --exclude-dir={.bzr,.cvs,.git,.hg,.svn}'

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
alias open_remote
open_remote () {
  echo 'open:['"$1"']' | clip
}

# }}}

# Zle {{{

# use emacs mode for command line
bindkey -e

# zsh-history-substring-search: bind ^P and ^N to it
bindkey '^P' history-substring-search-up
bindkey '^N' history-substring-search-down

# C-B / C-F to move by word, C-W to kill
bindkey '^F' forward-word
bindkey '^B' backward-word
bindkey '^W' backward-kill-word

# Smart URLs
autoload -Uz url-quote-magic
zle -N self-insert url-quote-magic

# ranger file explorer
ranger-cd() {
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

# M-B / M-F to move by word with only chars, M-W to kill
forward-word-only-chars () {
  local WORDCHARS=
  zle forward-word
}
zle -N forward-word-only-chars
bindkey '\ef' forward-word-only-chars
backward-word-only-chars () {
  local WORDCHARS=
  zle backward-word
}
zle -N backward-word-only-chars
bindkey '\eb' backward-word-only-chars
backward-kill-word-only-chars () {
  local WORDCHARS=
  zle backward-kill-word
}
zle -N backward-kill-word-only-chars
bindkey '\ew' backward-kill-word-only-chars

# undo and redo
bindkey '^_' undo
bindkey '\e-' redo

# M-. and M-m to insert word in previous lines
autoload -Uz copy-earlier-word
zle -N copy-earlier-word
bindkey '\em' copy-earlier-word
bindkey '\e.' insert-last-word

# ctrl-a and ctrl-e
bindkey '^A' beginning-of-line
bindkey '^E' end-of-line

# fzf default completion
bindkey '^I' fzf-completion
bindkey '^R' fzf-history-widget
bindkey '^T' fzf-file-widget
bindkey '\ec' fzf-cd-widget

# Use FZF to modify the current word with git files
fzf-git-files-widget() {
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

  # Complete the word with FZF, feed Git tracked or new files as input.
  word=$( git rev-parse 2> /dev/null &&
    (( git ls-files && git ls-files --other --exclude-standard) |
  fzf -q "$word" ));
  if [[ -n $word ]]; then
    LBUFFER="$prefix$word"
    zle redisplay
  fi
}
zle -N fzf-git-files-widget
bindkey '\eg' fzf-git-files-widget

# Use FZF to modify the current word with tmux words
fzf-tmux-words-widget() {
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

  word=$( tmuxwords | fzf -q "$1" );
  if [[ -n $word ]]; then
    LBUFFER="$prefix$word"
    zle redisplay
  fi
}
zle -N fzf-tmux-words-widget
bindkey '\et' fzf-tmux-words-widget

# toggle sudo for current command line
sudo-command-line() {
  [[ -z $BUFFER ]] && zle up-history
  if [[ $BUFFER == sudo\ * ]]; then
    LBUFFER="${LBUFFER#sudo }"
  else
    LBUFFER="sudo $LBUFFER"
  fi
}
zle -N sudo-command-line
bindkey '^S' sudo-command-line

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

# autosuggestion
bindkey '\ek' autosuggest-clear

# menu select for completion
zmodload zsh/complist
zle -C complete-menu menu-select _generic
_complete_menu() {
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

KEYTIMEOUT=1

# }}}

# Prompt {{{

setopt PROMPT_SUBST

LA=""
RA=""
PD=" "
NEWLINE=$'\n'

# git prompt option
RV_PROMPT_GIT_DIRTY="%F{100}"
RV_PROMPT_GIT_CLEAN="%F{71}"
RV_PROMPT_GIT_UNTRACKED="%%"
RV_PROMPT_GIT_AHEAD=">"
RV_PROMPT_GIT_BEHIND="<"
RV_PROMPT_GIT_DIVERGED="X"
RV_PROMPT_GIT_ADDED="+"
RV_PROMPT_GIT_MODIFIED="*"
RV_PROMPT_GIT_DELETED="D"
RV_PROMPT_GIT_RENAMED="~"
RV_PROMPT_GIT_UNMERGED="^"

# generate git prompt to _rv_prompt_git_str
_rv_prompt_git () {
  _rv_prompt_git_str=

  # exit if current directory is not a git repo
  local ref k status_str_map status_str color git_status
  ref=$(command git symbolic-ref HEAD 2> /dev/null) || ref=$(command git rev-parse --short HEAD 2>/dev/null) || return
  git_status=$(command git status --ignore-submodules=dirty -unormal --porcelain -b 2>/dev/null)

  typeset -A status_str_map
  status_str_map=(
  '^\?\? '         $RV_PROMPT_GIT_UNTRACKED
  '^M. |^A. '      $RV_PROMPT_GIT_ADDED
  '^.M |^.T '      $RV_PROMPT_GIT_MODIFIED
  '^R. '           $RV_PROMPT_GIT_RENAMED
  '^.D |^D. '      $RV_PROMPT_GIT_DELETED
  '^UU '           $RV_PROMPT_GIT_UNMERGED
  '^## .*ahead'    $RV_PROMPT_GIT_AHEAD
  '^## .*behind'   $RV_PROMPT_GIT_BEHIND
  '^## .*diverged' $RV_PROMPT_GIT_DIVERGED
  )
  for k in ${(@k)status_str_map}; do
    if $(echo "$git_status" | grep -E "$k" &> /dev/null); then
      status_str+=$status_str_map[$k]
    fi
  done

  if [[ -n "${status_str#>}" ]]; then
    color="$RV_PROMPT_GIT_DIRTY"
  else
    color="$RV_PROMPT_GIT_CLEAN"
  fi

  _rv_prompt_git_str="$color${ref#refs/heads/}${status_str:+ $status_str}"
}

# current millseconds
_rv_prompt_timer_now_ms () {
  perl -MTime::HiRes -e 'printf("%.0f\n",Time::HiRes::time()*1000)'
}

# get human readable representation of time
_rv_prompt_pretty_time () {
  local ms s repre hour minute second
  ms=$1
  if [[ ms -lt 10000 ]]; then
    repre=${ms}ms
  else
    s=$((ms / 1000))
    hour=$((s / 3600))
    minute=$((s / 60 % 60))
    second=$((s % 60))
    if [[ hour -gt 0 ]]; then repre+=${hour}h fi
    if [[ minute -gt 0 ]]; then repre+=${minute}m fi
    repre+=${second}s
  fi
  echo $repre
}

# start timer
_rv_prompt_timer_cmd_start () {
  if [[ ! -n $_rv_cmd_timer ]]; then
    _rv_cmd_timer=$(_rv_prompt_timer_now_ms)
  fi
}

# stop timer and get elapsed time
_rv_prompt_timer_cmd_stop () {
  if [[ -n $_rv_cmd_timer ]]; then
    local ms=$(($(_rv_prompt_timer_now_ms) - $_rv_cmd_timer))
    _rv_cmd_timer_elapsed=$(_rv_prompt_pretty_time $ms)
    unset _rv_cmd_timer
  else
    unset _rv_cmd_timer_elapsed
  fi
}

# render prompt string
_rv_prompt_precmd_render () {
  print -P "${RV_PROMPT_LASTSTATUS}"
}

RV_PROMPT_LASTSTATUS=%F{240}\${_rv_cmd_timer_elapsed}%(?.. %F{160}\$(nice_exit_code))
RV_PROMPT_SYMBOL=%K{234}%E%F{234}%K{28}${LA}\ \ \ %F{28}%K{234}$LA$PD
RV_PROMPT_PATH=%F{6}%~$PD
RV_PROMPT_GIT=\${_rv_prompt_git_str:+\$_rv_prompt_git_str$PD}
RV_PROMPT_X=%F{166}\${DISPLAY:+X$PD}
RV_PROMPT_JOBS=%F{163}%(1j.\&%j.$PD)
RV_PROMPT_CUSTOMIZE=""
RV_PROMPT_CMD="%F{240}%k❯%f "

if [[ -n $SSH_TTY || -n $SSH_CONNECTION ]]; then
  RV_PROMPT_USER=%F{93}%n$PD
else
  unset RV_PROMPT_USER
fi

 PROMPT=\${RV_PROMPT_SYMBOL}\${RV_PROMPT_USER}\${RV_PROMPT_PATH}${RV_PROMPT_GIT}${RV_PROMPT_X}\${RV_PROMPT_JOBS}\${RV_PROMPT_CUSTOMIZE}\${NEWLINE}\${RV_PROMPT_CMD}
RPROMPT=

add-zsh-hook preexec _rv_prompt_timer_cmd_start
add-zsh-hook precmd _rv_prompt_timer_cmd_stop
add-zsh-hook precmd _rv_prompt_git
add-zsh-hook precmd _rv_prompt_precmd_render

# }}}

# Custom {{{

[[ -f $RAVY_CUSTOM/zshrc ]] && source $RAVY_CUSTOM/zshrc

# }}}
