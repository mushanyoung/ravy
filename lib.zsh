
# generate git prompt to _ravy_prompt_git_result
_ravy_prompt_git () {
  local ref k git_st st_str st_count

  # exit if current directory is not a git repo
  if ! ref=$(command git symbolic-ref --short HEAD 2>/dev/null || command git rev-parse --short HEAD 2>/dev/null); then
    _ravy_prompt_git_result=
    return
  fi

  git_st=$(command git status --ignore-submodules=dirty -unormal --porcelain -b 2>/dev/null)

  st_parser=(
  '^## .*ahead'         "${RAVY_PROMPT_GIT_AHEAD->}"
  '^## .*behind'        "${RAVY_PROMPT_GIT_BEHIND-<}"
  '^## .*diverged'      "${RAVY_PROMPT_GIT_DIVERGED-x}"
  '^A. '                "${RAVY_PROMPT_GIT_ADDED-+}"
  '^R. '                "${RAVY_PROMPT_GIT_RENAMED-~}"
  '^C. '                "${RAVY_PROMPT_GIT_COPIED-c}"
  '^.D |^D. '           "${RAVY_PROMPT_GIT_DELETED--}"
  '^M. '                "${RAVY_PROMPT_GIT_MODIFIED-.}"
  '^.M '                "${RAVY_PROMPT_GIT_TREE_CHANGED-*}"
  '^U. |^.U |^AA |^DD ' "${RAVY_PROMPT_GIT_UNMERGED-^}"
  '^\?\? '              "${RAVY_PROMPT_GIT_UNTRACKED-#}"
  )

  for (( k = 1; k <= $#st_parser; k += 2 )) do
    if st_count=$(grep -E -c "$st_parser[k]" <<< "$git_st" 2>/dev/null); then
      st_str+="$st_parser[k+1]"
      if (( st_count > 1 )) then
        st_str+=$st_count
      fi
    fi
  done

  _ravy_prompt_git_result="${ref}${st_str:+ $st_str}"
}

# current millseconds
_ravy_time_now_ms () {
  perl -MTime::HiRes -e 'printf("%.0f\n",Time::HiRes::time()*1000)'
}

# get human readable representation of time
_ravy_prompt_pretty_time () {
  local ms s repre=''
  ms=$1
  if ((ms < 10000)) then
    repre=${ms}ms
  else
    s=$((ms / 1000))
    if ((s > 3600)) then repre+=$((s / 3600))h; fi
    if ((s > 60)) then repre+=$((s / 60 % 60))m; fi
    repre+=$((s % 60))s
  fi
  echo $repre
}

# start timer
_ravy_prompt_timer_start () {
  if [[ ! -n $_ravy_prompt_timer ]]; then
    _ravy_prompt_timer=$(_ravy_time_now_ms)
  fi
}

# get elapsed time without stopping timer
_ravy_prompt_timer_get () {
  if [[ -n $_ravy_prompt_timer ]]; then
    local ms=$(($(_ravy_time_now_ms) - _ravy_prompt_timer))
    _ravy_prompt_pretty_time $ms
  fi
}

# get elapsed time and stop timer
_ravy_prompt_timer_stop () {
  if [[ -n $_ravy_prompt_timer ]]; then
    local ms=$(($(_ravy_time_now_ms) - _ravy_prompt_timer))
    _ravy_prompt_timer_result=$(_ravy_prompt_pretty_time $ms)
    unset _ravy_prompt_timer
  else
    unset _ravy_prompt_timer_result
  fi
}

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

