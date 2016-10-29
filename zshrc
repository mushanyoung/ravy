# Modeline & Load {{{
# vim: set foldlevel=0 foldmethod=marker filetype=zsh:

if [[ "$RAVY_PROFILE" == true ]]; then
  # http://zsh.sourceforge.net/Doc/Release/Prompt-Expansion.html
  PS4=$'%D{%M%S%.} %N:%i> '
  exec 3>&2 2>${0:A:h}/profile.$$
  setopt xtrace prompt_subst
else
  # prevent from loading more than once
  [[ -n $RAVY_LOADED ]] && return 0
  RAVY_LOADED=true
fi

# load zshenv to make sure paths are set correctly
source ${0:A:h}/zshenv

# load lib
source ${0:A:h}/lib.zsh

# record time to initialize shell environment
_ravy_prompt_timer_start

# }}}

# Zplug START {{{

if [[ -f ~/.zplug/init.zsh ]]; then
  # zplug env
  zstyle :zplug:tag depth 1

  # load zplug
  source ~/.zplug/init.zsh

  # duplicate to get both binary included by zplug
  zplug 'junegunn/fzf', as:command, use:"bin", hook-build:'./install --bin >/dev/null'
  zplug 'junegunn/fzf', as:command, use:"bin/fzf-tmux"

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

if [[ $- == *i* ]]; then

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

  # FZF

  export FZF_DEFAULT_OPTS='--bind=ctrl-f:page-down,ctrl-b:page-up'
  export FZF_DEFAULT_COMMAND='ag -g ""'

  if hash fzf-tmux 2>/dev/null; then
    export FZF_CMD='command fzf-tmux -d40%'
  else
    export FZF_CMD='command fzf'
  fi

  alias fzf='$(__fzfcmd)'

  __fzfcmd() {
    echo $FZF_CMD
  }

  # Paste the selected file path(s) into the command line
  fzf-file-widget() {
    local files=$(ag -g "" | $(__fzfcmd) -m | while read item; do echo -n "${(q)item} "; done)
    LBUFFER="${LBUFFER}$files"
    zle redisplay
  }

  # Cd into the selected directory
  fzf-cd-widget() {
    cd "${$(find . -type d | sed 1d | cut -b3- | $(__fzfcmd) +m):-.}"
    zle reset-prompt
  }

  # Open the selected file by default editor, CTRL-O to open with `open` command
  fzf-open-file-widget () {
    local out file key cmd
    out=$(ag -g "" | $(__fzfcmd) --exit-0 --expect=ctrl-o)
    key=$(head -1 <<< "$out")
    file=$(head -2 <<< "$out" | tail -1)
    zle redisplay
    if [[ -n "$file" ]]; then
      [[ "$key" == 'ctrl-o' ]] && cmd="open $file" || cmd="${EDITOR:-vim} $file"
      BUFFER="$cmd"
      zle accept-line
    fi
  }

  # open recent files of vim
  fzf-open-vim-file-widget () {
    local file
    file=$(grep '^>' ~/.viminfo | cut -c3- |
    while read line; do
      [[ -f "${line/\~/$HOME}" ]] && echo "$line"
    done |
    $(__fzfcmd) -d +m -1 -q "$*")
    zle redisplay
    if [[ -n $file ]]; then
      BUFFER="vim $file"
      zle accept-line
    fi
  }

  # open session matched by query, create a new one if there isn't a match
  fzf-open-vim-session-widget () {
    local session=$(ls ~/.vim/sessions | sed 's/\.vim//' | $(__fzfcmd) --exit-0)
    zle redisplay
    if [[ -n $session ]]; then
      cd ${$(cat ~/.vim/sessions/$session.vim | grep '^cd' | head -1 | cut -d' ' -f2-)/#\~/$HOME}
      BUFFER="vim '+OpenSession $session'"
      zle accept-line
    fi
  }

  # CTRL-R - Paste the selected command from history into the command line
  fzf-history-widget() {
    local selected num
    setopt localoptions noglobsubst
    selected=( $(fc -l 1 | $(__fzfcmd) +s --tac +m -n2..,.. --tiebreak=index --toggle-sort=ctrl-r ${=FZF_CTRL_R_OPTS} -q "${LBUFFER//$/\\$}") )
    if [ -n "$selected" ]; then
      num=$selected[1]
      if [ -n "$num" ]; then
        zle vi-fetch-history -n $num
      fi
    fi
    zle redisplay
  }

  zle -N fzf-file-widget
  bindkey '^T' fzf-file-widget
  zle -N fzf-cd-widget
  bindkey '\et' fzf-cd-widget
  zle -N fzf-open-file-widget
  bindkey '\eo' fzf-open-file-widget
  zle -N fzf-open-vim-file-widget
  bindkey '\ev' fzf-open-vim-file-widget
  zle -N fzf-open-vim-session-widget
  bindkey '\es' fzf-open-vim-session-widget
  zle -N fzf-history-widget
  bindkey '^R' fzf-history-widget

fi

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
HISTSIZE=100000                  # The maximum number of events to be kept in a session.
SAVEHIST=100000                  # The maximum number of events to save in the history file.

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
  command ping $(sed -E -e 's#https?://##' -e 's#/.*$##' <<< $*)
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

# launch an interactive repl scratchpad within vim
codi() {
  local syntax="${1:-python}"
  [[ $# > 0 ]] && shift
  vim -c \
    "let g:startify_disable_at_vimenter = 1 |\
    set bt=nofile ls=0 noru nonu nornu |\
    hi ColorColumn ctermbg=NONE |\
    hi VertSplit ctermbg=NONE |\
    hi NonText ctermfg=0 |\
    Codi $syntax" "$@"
}

# git completion function for git aliases
_git-co(){ _git-checkout }
_git-l(){ _git-log }
_git-lg(){ _git-log }
_git-df(){ _git-diff }
_git-di(){ _git-diff }
_git-de(){ _git-diff }

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

# Rsync commands
if hash rsync 2>/dev/null; then
  _rsync_cmd='rsync --verbose --progress --human-readable --compress --archive --hard-links --one-file-system'

  if grep -q 'xattrs' <(rsync --help 2>&1); then
    _rsync_cmd="${_rsync_cmd} --acls --xattrs"
  fi

  if [[ "$OSTYPE" == darwin* ]] && grep -q 'file-flags' <(rsync --help 2>&1); then
    _rsync_cmd="${_rsync_cmd} --crtimes --fileflags --protect-decmpfs --force-change"
  fi

  alias rsync-copy="${_rsync_cmd}"
  alias rsync-move="${_rsync_cmd} --remove-source-files"
  alias rsync-update="${_rsync_cmd} --update"
  alias rsync-synchronize="${_rsync_cmd} --update --delete"

  unset _rsync_cmd
fi

# Open command through cbmonitor
open_remote () {
  clip <<< 'open:['"$1"']'
}

# }}}

# Prompt {{{

# Terminal title
if [[ "$TERM" != (dumb|linux|*bsd*|eterm*) ]]; then
  add-zsh-hook preexec _ravy_termtitle_command
  add-zsh-hook precmd _ravy_termtitle_path
fi

# Shell prompt
setopt PROMPT_SUBST

function {

local LA="" PD=" "

RAVY_PROMPT_LAST_CMD_STATUS=%F{240}\${_ravy_prompt_timer_result:+\$_ravy_prompt_timer_result$PD}%(?..%F{160}\$(nice_exit_code))
RAVY_PROMPT_SYMBOL=%K{234}%E%F{234}%K{28}${LA}\ %F{28}%K{234}$LA$PD
RAVY_PROMPT_USER=${SSH_CONNECTION:+%F\{93\}%n$PD}
RAVY_PROMPT_PATH=%F{6}%~$PD
RAVY_PROMPT_GIT=%F{64}\${_ravy_prompt_git_result:+\$_ravy_prompt_git_result$PD}
RAVY_PROMPT_X=%F{166}\${DISPLAY:+X$PD}
RAVY_PROMPT_JOBS=%F{163}%(1j.\&%j.$PD)
RAVY_PROMPT_CUSTOMIZE=""
RAVY_PROMPT_CMD="%F{240}%k❯%f "
RAVY_RPROMPT2_CMD="%F{240}❮%^"

}

# render status for last command
_ravy_prompt_last_command_status () {
  print -P "${RAVY_PROMPT_LAST_CMD_STATUS}"
}

PROMPT=\${RAVY_PROMPT_SYMBOL}\${RAVY_PROMPT_USER}\${RAVY_PROMPT_PATH}${RAVY_PROMPT_GIT}${RAVY_PROMPT_X}\${RAVY_PROMPT_JOBS}\${RAVY_PROMPT_CUSTOMIZE}$'\n'\${RAVY_PROMPT_CMD}
unset RPROMPT
PROMPT2=\${RAVY_PROMPT_CMD}
RPROMPT2=\${RAVY_RPROMPT2_CMD}

add-zsh-hook preexec _ravy_prompt_timer_start
add-zsh-hook precmd _ravy_prompt_timer_stop
add-zsh-hook precmd _ravy_prompt_git
add-zsh-hook precmd _ravy_prompt_last_command_status

# }}}

# Background Singleton Process {{{

# Run given command only if there is not one running.
singleton-command () {
  if ! pgrep -f "(^| |/)$*( |\$)" > /dev/null; then
    exec $*
  fi
}

# Run singleton-command in background.
singleton-command-background () {
  (singleton-command $* &) &> /dev/null
}

# clipboard monitor
if [[ $(uname) == Darwin ]]; then
  singleton-command-background cbmonitor
fi

# }}}

# Custom {{{

[[ -f $RAVY_CUSTOM/zshrc ]] && source $RAVY_CUSTOM/zshrc

# }}}

if [[ "$RAVY_PROFILE" == true ]]; then
  unsetopt xtrace
  exec 2>&3 3>&-
fi
