# Modeline & Load {{{
# vim: set foldlevel=0 foldmethod=marker filetype=zsh:

# prevent from loading more than once
[[ -n $RAVY_LOADED ]] && return 0 || RAVY_LOADED=true

# load zshenv to make sure paths are set correctly
source "${0:A:h}/zshenv"

# Load zprof if profiling is enabled.
[[ -n $RAVY_PROFILE ]] && zmodload zsh/zprof

# Record time to initialize shell environment.
zmodload zsh/datetime
export _RAVY_PROMPT_TIMER=$EPOCHREALTIME

# benchmark: base 17ms
# }}}

# zplug {{{

ZPLUG_HOME=${ZPLUG_HOME:-${HOME}/.zplug}

if [[ -f "$ZPLUG_HOME/init.zsh" ]]; then
  source "$ZPLUG_HOME/init.zsh"

  # zplug env
  zstyle :zplug:tag depth 1

  # plugins
  zplug "modules/environment", from:prezto, as:plugin
  zplug "modules/completion", from:prezto, as:plugin
  zplug "modules/archive", from:prezto, as:plugin

  zplug "romkatv/gitstatus", as:plugin
  zplug "marzocchi/zsh-notify", as:plugin
  zplug "chrissicool/zsh-256color", as:plugin
  zplug "supercrabtree/k", as:plugin
  zplug "hlissner/zsh-autopair", as:plugin
  zplug "zsh-users/zsh-completions", as:plugin
  zplug "ymattw/cdiff", as:command, use:cdiff
  zplug "skaji/remote-pbcopy-iterm2", as:command, use:pbcopy

  zplug "zsh-users/zsh-syntax-highlighting", defer:1, as:plugin
  zplug "zsh-users/zsh-history-substring-search", defer:2, as:plugin
  zplug "zsh-users/zsh-autosuggestions", defer:3, as:plugin  # benchmark: 17ms

  if [[ -n $RAVY_PROFILE ]]; then
    zplug "romkatv/zsh-prompt-benchmark", as:plugin
    zplug "agkozak/zhooks", as:plugin
  fi

  # load plugins
  if ! zplug check --verbose; then
    printf "Install? [y/N]: "
    if read -q; then
        echo; zplug install
    fi
  fi

  zplug load

  # zsh syntax highlighting
  ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)
  ZSH_HIGHLIGHT_STYLES=(
  "precommand"                    "fg=magenta"
  "command"                       "fg=231"
  "hashed-command"                "fg=231"
  "builtin"                       "fg=28"
  "function"                      "fg=46"
  "alias"                         "fg=85"
  "reserved-word"                 "fg=214"
  "unknown-token"                 "fg=196"
  "suffix-alias"                  "fg=85,underline"
  "path_prefix"                   "fg=23"
  "path"                          "fg=30"
  "commandseparator"              "fg=blue"
  "redirection"                   "fg=blue"
  "globbing"                      "fg=blue"
  "history-expansion"             "fg=yellow"
  "single-hyphen-option"          "fg=yellow"
  "double-hyphen-option"          "fg=yellow"
  "single-quoted-argument"        "fg=yellow"
  "dollar-quoted-argument"        "fg=yellow"
  "double-quoted-argument"        "fg=yellow"
  "back-quoted-argument"          "fg=yellow"
  "dollar-double-quoted-argument" "fg=magenta"
  "back-double-quoted-argument"   "fg=magenta"
  "back-dollar-quoted-argument"   "fg=magenta"
  "assign"                        "fg=magenta"
  "comment"                       "fg=black"
  "cursor-matchingbracket"        "fg=black,bg=blue"
  "default"                       "none"
  )

  # zsh auto suggestions
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=240"
  ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=(
  "backward-delete-char" "complete-menu" "expand-or-complete"
  )

  # Terminal notifier
  zstyle ':notify:*' success-title "Succeeded in #{time_elapsed}s"
  zstyle ':notify:*' error-title "Failed in #{time_elapsed}s"
fi

# }}}

# ZLE & FZF {{{

if [[ $- == *i* ]]; then

  # chars treated as a part of a word
  export WORDCHARS=""

  export KEYTIMEOUT=1

  bindkey -e

  # Smart URLs
  autoload -Uz url-quote-magic
  zle -N self-insert url-quote-magic

  # ^P / ^N: zsh-history-substring-search
  bindkey "^P" history-substring-search-up
  bindkey "^N" history-substring-search-down

  # M-h to run-help
  bindkey "\eh" run-help

  # autosuggestion
  bindkey "\ek" autosuggest-clear

  # M-. and M-, to insert word in previous lines
  autoload -Uz copy-earlier-word
  zle -N copy-earlier-word
  bindkey "\e." insert-last-word
  bindkey "\e," copy-earlier-word

  # completion and its menu
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
    local cmd="${FZF_FILES_COMMAND:-ag -a -g ''}"
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
      file_str="${$(echo ${(q)file_list[*]})/\\\~\//~/}"
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

  # hidden files
  ravy::zle::fzf::files::files() {
    FZF_FILES_COMMAND="ag -a -g ''" FZF_FILES_PROMPT="File" FZF_FILES_DEFAULT_ACTION="e" ravy::zle::fzf::files
  }

  # hidden files
  ravy::zle::fzf::files::files::hidden() {
    FZF_FILES_COMMAND="ag -a --hidden -g ''" FZF_FILES_PROMPT=".File" FZF_FILES_DEFAULT_ACTION="e" ravy::zle::fzf::files
  }

  # directories
  ravy::zle::fzf::files::dirs() {
    FZF_FILES_COMMAND="find . -type d -not -path '*/\.*' | sed 1d | cut -b3-" FZF_FILES_PROMPT="Dir" FZF_FILES_DEFAULT_ACTION="d" ravy::zle::fzf::files
  }

  # hidden directories
  ravy::zle::fzf::files::dirs::hidden() {
    FZF_FILES_COMMAND="find . -type d | sed 1d | cut -b3-" FZF_FILES_PROMPT=".Dir" FZF_FILES_DEFAULT_ACTION="d" ravy::zle::fzf::files
  }

  # recent files of vim
  ravy::zle::fzf::files::vim () {
    FZF_FILES_COMMAND="grep '^>' ~/.viminfo | cut -b3-" FZF_FILES_PROMPT="File(vim)" FZF_FILES_DEFAULT_ACTION="e" ravy::zle::fzf::files
  }

  ravy::zle::fzf::files::vim::last () {
    FZF_FILES_COMMAND="grep '^>' ~/.viminfo | cut -b3- | head -1" FZF_FILES_OPTS="--select-1" FZF_FILES_DEFAULT_ACTION="e" ravy::zle::fzf::files
  }

  # open session matched by query, create a new one if there is no match
  ravy::zle::fzf::vim_sessions () {
    local session
    session=$(cd ~/.vim/sessions && find . \
      | cut -b3- | sed -e "1d" -e 's/\.vim$//' | fzf --prompt='Session> ' --reverse)
    if [[ -n $session ]]; then
      cd -- ${$(grep '^cd' ~/.vim/sessions/"$session".vim \
        | head -1 \
        | cut -d" " -f2-)/#\~/$HOME}
      BUFFER="vim '+OpenSession $session'"
      zle reset-prompt
      zle accept-line
    else
      zle redisplay
    fi
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
  zle -N ravy::zle::fzf::files::dirs::hidden
  zle -N ravy::zle::fzf::files::vim
  zle -N ravy::zle::fzf::files::vim::last
  zle -N ravy::zle::fzf::vim_sessions
  zle -N ravy::zle::fzf::history

  bindkey "\eo" ravy::zle::fzf::files::files
  bindkey "\eO" ravy::zle::fzf::files::files::hidden
  bindkey "\ed" ravy::zle::fzf::files::dirs
  bindkey "\eD" ravy::zle::fzf::files::dirs::hidden
  bindkey "\ev" ravy::zle::fzf::files::vim
  bindkey "\eV" ravy::zle::fzf::files::vim::last
  bindkey "\es" ravy::zle::fzf::vim_sessions
  bindkey "\er" ravy::zle::fzf::history
fi

# }}}

# Environment {{{

# General
setopt PIPE_FAIL              # Piped command fails for precedents.
setopt BRACE_CCL              # Allow brace character class list expansion.

# Auto correcting
unsetopt CORRECT_ALL          # Do not auto correct arguments.
unsetopt CORRECT              # Do not auto correct commands.

# Directory
setopt AUTO_CD              # Auto changes to a directory without typing cd.
setopt AUTO_PUSHD           # Push the old directory onto the stack on cd.
setopt PUSHD_IGNORE_DUPS    # Do not store duplicates in the stack.
setopt PUSHD_SILENT         # Do not print the directory stack after pushd or popd.
setopt PUSHD_TO_HOME        # Push to home directory when no argument is given.
setopt CDABLE_VARS          # Change directory to a path stored in a variable.
setopt AUTO_NAME_DIRS       # Auto add variable-stored paths to ~ list.
setopt MULTIOS              # Write to multiple descriptors.
unsetopt CLOBBER            # Do not overwrite existing files with > and >>.
                            # Use >! and >>! to bypass.
# History
HISTSIZE=10000                   # The maximum number of events to save in the internal history.
SAVEHIST=10000                   # The maximum number of events to save in the history file.
HISTFILE="${HOME}/.zhistory"  # The path to the history file.

setopt BANG_HIST                 # Treat the '!' character specially during expansion.
setopt EXTENDED_HISTORY          # Write the history file in the ':start:elapsed;command' format.
setopt SHARE_HISTORY             # Share history between all sessions.
setopt HIST_EXPIRE_DUPS_FIRST    # Expire a duplicate event first when trimming history.
setopt HIST_IGNORE_DUPS          # Do not record an event that was just recorded again.
setopt HIST_IGNORE_ALL_DUPS      # Delete an old recorded event if a new event is a duplicate.
setopt HIST_FIND_NO_DUPS         # Do not display a previously found event.
setopt HIST_IGNORE_SPACE         # Do not record an event starting with a space.
setopt HIST_SAVE_NO_DUPS         # Do not write a duplicate event to the history file.
setopt HIST_VERIFY               # Do not execute immediately upon history expansion.
setopt HIST_BEEP                 # Beep when accessing non-existent history.

#
# Aliases
#

# Lists the ten most used commands.
alias history-stat="history 0 | awk '{print \$2}' | sort | uniq -c | sort -n -r | head"

export HISTSIZE=100000        # The maximum number of events to be kept in a session.
export SAVEHIST=100000        # The maximum number of events to save in the history file.

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
export LESS_TERMCAP_us=$'\E[04;38;5;146m' # begin underline
export LESS_TERMCAP_ue=$'\E[0m'           # end underline

# MANPATH should always have a leading colon to search with executables
[[ ! $MANPATH =~ ^: ]] && MANPATH=":$MANPATH"

# ls color evaluations
hash dircolors &>/dev/null && dircolor_cmd=dircolors
hash gdircolors &>/dev/null && dircolor_cmd=gdircolors
[[ -n $dircolor_cmd ]] && eval "$($dircolor_cmd -b "$RAVY_HOME/LS_COLORS")"
unset dircolor_cmd

# }}}

# Util Functions & Aliases {{{

# zmv
autoload -Uz zmv

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
    parents=($parents "$(echo $PWD | cut -d'/' -f$i)")
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

_d () {
  # Get parents (in reverse order)
  local i folder_depth
  folder_depth=${#${(ps:/:)${PWD}}#}
  for i in {$((folder_depth+1))..2}; do
    reply=($reply "`echo $PWD | cut -d'/' -f$i`")
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

  echo "${exit_status}:${sig_name:-$exit_status}"
  return $exit_status
}

# git completion function for git aliases
_git-co(){ _git-checkout; }
_git-l(){ _git-log; }
_git-lg(){ _git-log; }
_git-df(){ _git-diff; }
_git-di(){ _git-diff; }
_git-de(){ _git-diff; }

# Pipe command with --help output and ignore rest of the line.
alias -g -- -help="-help | less; true "
alias -g -- --help="--help | less; true "
alias -g -- --helpshort="--helpshort | less; true "
alias -g -- --helpfull="--helpfull | less; true "

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

# vim
alias vi=vim
alias v=vim

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
alias g="command git"
alias t="command tmux"
alias hs="history"
alias tf="tail -f"
alias rd="rmdir"
alias rb="ruby"

# python
alias py="python"
alias py3="python3"
alias ipy="ipython"
alias ipy3="ipython3"

if hash python2 2>/dev/null; then
  alias py="python2"
  alias py2="python2"
fi
if hash ipython2 2>/dev/null; then
  alias ipy="ipython2"
  alias ipy2="ipython2"
fi
if hash pip2 2>/dev/null; then
  alias pip="pip2"
fi

pip-update-all () {
  pip list --outdated --format=columns | tail -n +3 | cut -f1 -d' ' | xargs pip install -U
}
pip2-update-all () {
  pip2 list --outdated --format=columns | tail -n +3 | cut -f1 -d' ' | xargs pip install -U
}
pip3-update-all () {
  pip3 list --outdated --format=columns | tail -n +3 | cut -f1 -d' ' | xargs pip install -U
}

# http serve current working dir in a given port (8000 in default)
alias serve="python -m SimpleHTTPServer"

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

# open-remote
[[ -n $SSH_CONNECTION ]] && alias open="open-remote"

# Ravy commands
alias ravy="cd \$RAVY_HOME"
alias ravycustom="cd \$RAVY_CUSTOM_HOME"
alias ravysource="unset RAVY_LOADED; source ${0:A}"

# Rsync commands
if hash rsync 2>/dev/null; then
  _rsync_cmd="rsync --verbose --progress --human-readable --archive --hard-links --one-file-system"

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

# }}}

# Prompt {{{

# generate git prompt to _RAVY_PROMPT_GIT_READ
# ravy::prompt::git () {
#   local ref k git_st st_str st_count
#   # test if current directory is not a git repo
#   if ref=$(command git symbolic-ref --short HEAD 2>/dev/null \
#         || command git rev-parse --short HEAD 2>/dev/null); then
#     git_st=$(command git status --ignore-submodules=dirty -unormal --porcelain -b 2>/dev/null)
#     st_parser=(
#     "^## .*ahead"         "${RAVY_PROMPT_GIT_AHEAD->}"
#     "^## .*behind"        "${RAVY_PROMPT_GIT_BEHIND-<}"
#     "^## .*diverged"      "${RAVY_PROMPT_GIT_DIVERGED-x}"
#     "^A. "                "${RAVY_PROMPT_GIT_ADDED-+}"
#     "^R. "                "${RAVY_PROMPT_GIT_RENAMED-~}"
#     "^C. "                "${RAVY_PROMPT_GIT_COPIED-c}"
#     "^.D |^D. "           "${RAVY_PROMPT_GIT_DELETED--}"
#     "^M. "                "${RAVY_PROMPT_GIT_MODIFIED-.}"
#     "^.M "                "${RAVY_PROMPT_GIT_TREE_CHANGED-*}"
#     "^U. |^.U |^AA |^DD " "${RAVY_PROMPT_GIT_UNMERGED-^}"
#     "^\?\? "              "${RAVY_PROMPT_GIT_UNTRACKED-#}"
#     )
#     for (( k = 1; k <= $#st_parser; k += 2 )) do
#       if st_count=$(grep -E -c "${st_parser[k]}" <<< "$git_st" 2>/dev/null); then
#         st_str+="${st_parser[k+1]}"
#         if (( st_count > 2 )); then
#           st_str+=$st_count
#         elif (( st_count == 2 )); then
#           st_str+="${st_parser[k+1]}"
#         fi
#       fi
#     done
#     export _RAVY_PROMPT_GIT_READ="${ref}"
#     export _RAVY_PROMPT_GIT_ST_READ="${st_str}"
#   else
#     unset _RAVY_PROMPT_GIT_READ _RAVY_PROMPT_GIT_ST_READ
#   fi
# }

gitstatus_start ravy

# generate git prompt to _RAVY_PROMPT_GIT_READ
ravy::prompt::git () {
  local st st_parser k v
  gitstatus_query ravy
  if [[ $VCS_STATUS_RESULT == "ok-sync" ]]; then
    st_parser=(
      "VCS_STATUS_COMMITS_AHEAD"  ">"
      "VCS_STATUS_COMMITS_BEHIND" "<"
      "VCS_STATUS_HAS_STAGED"     "."
      "VCS_STATUS_HAS_UNSTAGED"   "*"
      "VCS_STATUS_HAS_UNTRACKED"  "#"
    )
    st="${VCS_STATUS_ACTION:+ ${VCS_STATUS_ACTION}}"
    for (( k = 1; k <= $#st_parser; k += 2 )) do
      ((${(P)st_parser[k]} > 0)) && st+="$st_parser[k+1]"
    done
    if [[ -n ${VCS_STATUS_LOCAL_BRANCH} ]]; then
      export _RAVY_PROMPT_GIT_READ="${VCS_STATUS_LOCAL_BRANCH}"
    else
      export _RAVY_PROMPT_GIT_READ="${VCS_STATUS_COMMIT:0:7}"
    fi
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
    ((s > 86400)) && repre+=$(([#10] s / 86400))d
    ((s > 3600)) && repre+=$(([#10] s / 3600 % 24))h
    ((s > 60)) && repre+=$(([#10] s / 60 % 60))m
    repre+=$(printf '%.1fs' $((s % 60)))
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
    _RAVY_PROMPT_TIMER_READ=$(ravy::prompt::timer_format $(($EPOCHREALTIME - _RAVY_PROMPT_TIMER)))
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

setopt PROMPT_SUBST

LF=$'\n'
RAVY_PROMPT_LASTCMD_RUNTIME="%F{240}\${_RAVY_PROMPT_TIMER_READ:+\${_RAVY_PROMPT_TIMER_READ} }"
RAVY_PROMPT_LASTCMD_RET="%F{160}\${_RAVY_PROMPT_TIMER_READ:+%(?..\$(nice_exit_code))${LF}}"
RAVY_PROMPT_INDICATOR="%K{234}%E  "
RAVY_PROMPT_PATH="%F{30}%~ "
RAVY_PROMPT_GIT="%F{64}\${_RAVY_PROMPT_GIT_READ:+\${_RAVY_PROMPT_GIT_READ}}%F{172}\${_RAVY_PROMPT_GIT_READ:+\${_RAVY_PROMPT_GIT_ST_READ} }"
RAVY_PROMPT_USER="%F{103}%n "
RAVY_PROMPT_X="%F{166}\${DISPLAY:+X }"
RAVY_PROMPT_JOBS="%F{163}%(1j.&%j .) "
RAVY_PROMPT_CUSTOMIZE=""
RAVY_PROMPT_CMD="%F{239}%k%_❯%f "

export PROMPT="${RAVY_PROMPT_LASTCMD_RUNTIME}${RAVY_PROMPT_LASTCMD_RET}${RAVY_PROMPT_INDICATOR}${RAVY_PROMPT_PATH}${RAVY_PROMPT_GIT}${RAVY_PROMPT_USER}${RAVY_PROMPT_X}${RAVY_PROMPT_JOBS}\${RAVY_PROMPT_CUSTOMIZE}${LF}${RAVY_PROMPT_CMD}"
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

    if [[ $TERM =~ ^screen || -n $TMUX ]]; then
      printf "\ek%s\e\\" "${(V%)formatted}"
    elif [[ $TERM =~ ^rxvt-unicode ]]; then
      printf '\33]2;%s\007' ${(V%)formatted}
    elif [[ $TERM =~ ^xterm ]]; then
      printf "\e]0;%s\a" "${(V%)formatted}"
    fi
  }

  # Set the terminal title with current command.
  ravy::termtitle::command () {
    local -a cmd

    # Re-parse the command line
    cmd=(${(z)${1//\\/\\\\\\\\}})

    case $cmd[1] in
      fg) cmd=(${(z)jobtexts[${(Q)cmd[2]:-%+}]}) ;;
      %*) cmd=(${(z)jobtexts[${(Q)cmd[1]:-%+}]}) ;;
    esac

    ravy::termtitle::settitle "!$cmd[1]"
  }

  # Set the terminal title with current path.
  ravy::termtitle::path () { ravy::termtitle::settitle "%18<...<%~"; }

  ravy::termtitle::iterm_tab_color () {
    printf "\033]6;1;bg;red;brightness;$1\a"
    printf "\033]6;1;bg;green;brightness;$2\a"
    printf "\033]6;1;bg;blue;brightness;$3\a"
  }

  ravy::termtitle::iterm_tab_color_keyword () {
    local value=($(python -c "import random; random.seed('$1');
for _ in range(3): print((random.randint(0,255)+255)/2)"))
    ravy::termtitle::iterm_tab_color "${value[@]}"
  }

  ravy::termtitle::iterm_tab_color_path () {
    ravy::termtitle::iterm_tab_color_keyword $PWD
  }

  ravy::termtitle::iterm_tab_color_path

  add-zsh-hook chpwd ravy::termtitle::iterm_tab_color_path
  add-zsh-hook chpwd ravy::termtitle::path   # benchmark: 5ms
  add-zsh-hook preexec ravy::termtitle::command
fi

# }}}

# Custom {{{

[[ -f $RAVY_CUSTOM_HOME/zshrc ]] && source "$RAVY_CUSTOM_HOME/zshrc"

# }}}
