# no greeting message
set fish_greeting ''

function __prompt_cmd_duration
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
function __prompt_cmd_status
  set -l st $argv[1]
  test -z $st; or test $st -le 0; and return

  set -l codes 1 2 19 20 21 22 126 127 129 130 131 132 134 136 137 139 141 143
  set -l names WARN BUILTINMISUSE STOP TSTP TTIN TTOU CCANNOTINVOKE CNOTFOUND HUP INT QUIT ILL ABRT FPE KILL SEGV PIPE TERM

  echo -n $st
  if set -l index (contains -i $st $codes)
    echo :$names[$index]
  end
end

function __prompt_git_branch
  command git rev-parse --abbrev-ref HEAD 2>/dev/null
end

function __prompt_git_status
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

function __prompt_pwd
    # Replace $HOME with "~"
    set realhome ~
    set -l tmp (string replace -r '^'"$realhome"'($|/)' '~$1' $PWD)
    echo $tmp
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
    echo -n -s (set_color 666) (__prompt_cmd_duration $CMD_DURATION)  ' ' (set_color red) (__prompt_cmd_status $cmd_status)
    set -e CMD_DURATION
  end
  echo

  # line 2
  # path
  echo -n -s (set_color -b 222) '  ' (test -w $PWD; and set_color blue; or set_color red) (__prompt_pwd) ' '

  # git
  set -l gbranch (__prompt_git_branch)
  if test -n "$gbranch"
    echo -n -s (set_color green) $gbranch (set_color yellow) (__prompt_git_status) ' '
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
