# generate git prompt to _rv_prompt_git_result
_rv_prompt_git () {
  _rv_prompt_git_result=

  # exit if current directory is not a git repo
  local ref k status_str_map status_str color git_status
  ref=$(command git symbolic-ref HEAD 2> /dev/null || command git rev-parse --short HEAD 2>/dev/null) || return
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

  _rv_prompt_git_result="$color${ref#refs/heads/}${status_str:+ $status_str}"
}

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

# current millseconds
_rv_time_now_ms () {
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
_rv_prompt_timer_start () {
  if [[ ! -n $_rv_prompt_timer ]]; then
    _rv_prompt_timer=$(_rv_time_now_ms)
  fi
}

# stop timer and get elapsed time
_rv_prompt_timer_stop () {
  if [[ -n $_rv_prompt_timer ]]; then
    local ms=$(($(_rv_time_now_ms) - $_rv_prompt_timer))
    _rv_prompt_timer_result=$(_rv_prompt_pretty_time $ms)
    unset _rv_prompt_timer
  else
    unset _rv_prompt_timer_result
  fi
}

# Set the terminal or terminal multiplexer title.
_rv_termtitle () {
  local window_title_format tab_title_format formatted
  zformat -f formatted "%s" "s:$argv"

  if [[ "$TERM" == screen* ]]; then
    window_title_format="\ek%s\e\\"
  else
    window_title_format="\e]2;%s\a"
  fi
  tab_title_format="\e]1;%s\a"

  printf "$tab_title_format" "${(V%)formatted}"
  printf "$window_title_format" "${(V%)formatted}"
}

# Set the terminal title with current command.
_rv_termtitle_command () {
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
    _rv_termtitle_command "${(e):-\$jobtexts_from_parent_shell$index}"
    )
  else
    # Set the command name, or in the case of sudo or ssh, the next command.
    local cmd="${${2[(wr)^(*=*|sudo|ssh|-*)]}:t}"
    local truncated_cmd="!${cmd/(#m)?(#c16,)/${MATCH[1,14]}..}"
    unset MATCH

    _rv_termtitle "$truncated_cmd"
  fi
}

# Set the terminal title with current path.
_rv_termtitle_path () {
  emulate -L zsh
  setopt EXTENDED_GLOB

  local abbreviated_path="${PWD/#$HOME/~}"
  local truncated_path="${abbreviated_path/(#m)?(#c16,)/..${MATCH[-14,-1]}}"
  unset MATCH

  _rv_termtitle "$truncated_path"
}

