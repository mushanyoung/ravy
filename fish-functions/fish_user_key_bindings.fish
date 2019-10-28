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

bind \ez __fle_fg
