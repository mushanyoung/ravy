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

function __fle_fzf_history
    history -z | fzf -q (commandline) \
        -e +m --read0 --print0 --height=45% \
        --prompt="History> " \
        --preview='fish_indent --ansi < {+sf}' \
        --preview-window=right:wrap \
        --tiebreak=index \
        --bind=ctrl-r:toggle-sort,ctrl-f:page-down,ctrl-b:page-up | read -lz result

    commandline -f repaint
    commandline -- $result
end

function __fle_fzf_files
    set -l cmd $FZF_FILES_COMMAND
    test -n "$cmd"; or set cmd fd

    set -l prompt $FZF_FILES_PROMPT
    test -n "$prompt"; or set prompt File

    set -l preview_cmd $FZF_FILES_PREVIEW_COMMAND
    test -n "$preview_cmd"; or set preview_cmd 'ravy-file-preview {}'

    test -n "$FZF_FILES_TAC"; and set -l tac_option --tac

    set -l result ($cmd 2>/dev/null |\
  fzf --height=45% --bind=ctrl-f:page-down,ctrl-b:page-up -m --reverse \
    --ansi \
    --prompt="$prompt> " \
    --preview="$preview_cmd" \
    --preview-window=right:wrap \
    $tac_option \
    --expect=ctrl-a,alt-a,ctrl-d,alt-d,ctrl-e,alt-e,ctrl-v,alt-v,ctrl-o,alt-o,ctrl-q,alt-q)

    set -l key (string trim $result[1])
    set -l file_list $result[2..-1]
    set -l escaped_list (string escape $file_list)
    commandline -f repaint
    if test -n "$file_list"
        test -n "$key"; or set key $FZF_FILES_DEFAULT_ACTION
        test -n "$key"; or set key q
        if string match -rq '[Qq]$' $key
            set key
            while not string match -r '(^|[AaDdEeVvOoQq])$' $key
                read -n1 -P "$escaped_list"\n"(A)ppend, (E)dit, enter (D)irectory, (O)pen, (Q)uit: " key >/dev/null 2>&1
            end
        end
        if string match -rq '^custom:' $key
            set -l sink_cmd (string sub -s 8 $key)
            commandline "$sink_cmd $escaped_list"
            commandline -f execute
        else if string match -rq '[Aa]$' $key
            # Append
            test (commandline -C) -gt 0; and commandline -i ' '
            commandline -i "$escaped_list "
        else if string match -rq '[Dd]$' $key
            # change Directory
            set -l target $file_list[1]
            test -d $target; or set target (dirname $target)
            if test "$target" != .
                commandline "cd '$target'"
                commandline -f execute
            end
        else if string match -rq '[EeVv]$' $key
            # Edit
            set -l editor (set -q EDITOR; and echo $EDITOR; or echo nvim)
            commandline "$editor -- $escaped_list"
            commandline -f execute
        else if string match -rq '[Oo]$' $key
            # Open
            commandline "open -- $escaped_list"
            commandline -f execute
        end
    end
end

function __fle_fzf_files_files
    set -lx FZF_FILES_COMMAND fd
    set -lx FZF_FILES_PROMPT File
    set -lx FZF_FILES_DEFAULT_ACTION e
    __fle_fzf_files
end

function __fle_fzf_files_files_with_hidden
    set -lx FZF_FILES_COMMAND fd -H
    set -lx FZF_FILES_PROMPT ".File"
    set -lx FZF_FILES_DEFAULT_ACTION e
    __fle_fzf_files
end

function __fle_fzf_files_dirs
    set -lx FZF_FILES_COMMAND fd -t d
    set -lx FZF_FILES_PROMPT Dir
    set -lx FZF_FILES_DEFAULT_ACTION d
    __fle_fzf_files
end

function __fle_fzf_files_dirs_with_hidden
    set -lx FZF_FILES_COMMAND fd -H -t d
    set -lx FZF_FILES_PROMPT ".Dir"
    set -lx FZF_FILES_DEFAULT_ACTION d
    __fle_fzf_files
end

function __fle_fzf_files_nvim_source
    nvim --headless +'lua for _,f in ipairs(vim.v.oldfiles) do io.write(f .. "\n") end' +qa
end

function __fle_fzf_files_nvim
    set -lx FZF_FILES_COMMAND __fle_fzf_files_nvim_source
    set -lx FZF_FILES_PROMPT "File(nvim)"
    set -lx FZF_FILES_DEFAULT_ACTION e
    __fle_fzf_files
end

function __fle_fzf_files_rg
    set -lx keyword (string lower (commandline))
    if not test -n "$keyword"
        return
    end
    set -lx FZF_FILES_COMMAND rg -il $keyword
    set -lx FZF_FILES_PROMPT "Search: /$keyword/ "
    set -lx FZF_FILES_DEFAULT_ACTION "custom:nvim +'exe \"norm /$keyword\n\"' --"
    set -lx FZF_FILES_PREVIEW_COMMAND "rg --pretty --context 2 '$keyword' {}"
    __fle_fzf_files
end

function __fle_prepend_last_history_line
    commandline -i $history[1]
end

bind \er __fle_fzf_history
bind \eo __fle_fzf_files_files
bind \eO __fle_fzf_files_files_with_hidden
bind \ed __fle_fzf_files_dirs
bind \eD __fle_fzf_files_dirs_with_hidden
bind \ev __fle_fzf_files_nvim
bind \eg __fle_fzf_files_rg

bind \et __fle_type

bind \cf forward-word
bind \cb backward-word

bind \e. history-token-search-backward
bind \e, history-token-search-forward
bind \e/ __fle_prepend_last_history_line

bind \cz __fle_fg

# sane <c-c>
bind \cc 'commandline ""'


