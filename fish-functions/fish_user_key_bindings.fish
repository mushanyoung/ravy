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

function __fle_fzf_files
  set -l cmd $FZF_FILES_COMMAND
  test -n "$cmd"; or set cmd fd
  set -l prompt $FZF_FILES_PROMPT
  test -n "$prompt"; or set prompt File
  set -l prompt_opt "--prompt=$prompt> "
  set -l out ($cmd 2>/dev/null \
    | fzf $FZF_DEFAULT_OPTS $prompt_opt --height=45% --bind=ctrl-f:page-down,ctrl-b:page-up -m --reverse --expect=ctrl-a,alt-a,ctrl-d,alt-d,ctrl-e,alt-e,ctrl-v,alt-v,ctrl-o,alt-o,ctrl-q,alt-q)
  set -l key (string trim $out[1])
  set -l file_list $out[2..-1]
  set -l escaped_list (string escape $file_list)
  if test -n "$file_list"
    test -n "$key"; or set key $FZF_FILES_DEFAULT_ACTION
    test -n "$key"; or set key "q"
    if string match -rq '[Qq]$' $key
      set key
      while not string match -r '(^|[AaDdEeVvOoQq])$' $key
        read -n1 -P "$escaped_list"\n"(A)ppend, (E)dit, enter (D)irectory, (O)pen, (Q)uit: " key >/dev/null 2>&1
      end
      commandline -f repaint
    end
    if string match -rq '[Aa]$' $key
      test (commandline -C) -gt 0; and commandline -i ' '
      commandline -i "$escaped_list "
    else if string match -rq '[Dd]$' $key
      set -l target $file_list[1]
      test -d $target; or set target (dirname $target)
      if test "$target" != .
        commandline "cd '$target'"
        commandline -f execute
      end
    else if string match -rq '[EeVv]$' $key
      set -l editor (set -q EDITOR; and echo $EDITOR; or echo vim)
      commandline "$editor -- $escaped_list"
      commandline -f execute
    else if string match -rq '[Oo]$' $key
      commandline "open -- $escaped_list"
      commandline -f execute
    end
  else
    commandline -f repaint
  end
end

function __fle_fzf_files_files
  set -lx FZF_FILES_COMMAND fd
  set -lx FZF_FILES_PROMPT "File"
  set -lx FZF_FILES_DEFAULT_ACTION "e"
  __fle_fzf_files
end

function __fle_fzf_files_files_with_hidden
  set -lx FZF_FILES_COMMAND fd -H
  set -lx FZF_FILES_PROMPT ".File"
  set -lx FZF_FILES_DEFAULT_ACTION "e"
  __fle_fzf_files
end

function __fle_fzf_files_dirs
  set -lx FZF_FILES_COMMAND fd -H -t d
  set -lx FZF_FILES_PROMPT ".Dir"
  set -lx FZF_FILES_DEFAULT_ACTION "d"
  __fle_fzf_files
end

function __fle_fzf_files_vim_source
  grep '^>' $HOME/.viminfo | cut -b3-
end

function __fle_fzf_files_vim
  set -lx FZF_FILES_COMMAND __fle_fzf_files_vim_source
  set -lx FZF_FILES_PROMPT "File(vim)"
  set -lx FZF_FILES_DEFAULT_ACTION "e"
  __fle_fzf_files
end

bind \eo __fle_fzf_files_files
bind \eO __fle_fzf_files_files_with_hidden
bind \ed __fle_fzf_files_dirs
bind \ev __fle_fzf_files_vim

bind \et __fle_type
bind \ez __fle_fg

bind \e. history-token-search-backward
bind \e, history-token-search-forward
