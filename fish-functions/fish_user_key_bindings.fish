function __fle_fg
  if command -sq fzf
    set -l jobnum (jobs | fzf -0 -1 --tac | sed 's#	.*##')
    if test -n "$jobnum"; and test $jobnum -gt 0
      commandline "fg %$jobnum"
      commandline -f execute
    end
  else
    if jobs -q
      commandline fg
      commandline -f execute
    end
  end
end

function __fle_type
  set -l cmd (commandline)
  if test -n "$cmd"
    commandline "type -a $cmd"
    commandline -f execute
  end
end

bind \et __fle_type
bind \ez __fle_fg
