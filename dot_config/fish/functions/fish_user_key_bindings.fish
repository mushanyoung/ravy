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

function __fle_history_source
    if command -sq atuin
        if command -sq perl
            ATUIN_LOG=error atuin history list --cmd-only --print0 -r false 2>/dev/null | perl -0ne 'print unless $seen{$_}++'
            if test "$pipestatus[1]" -eq 0
                return 0
            end
        else
            ATUIN_LOG=error atuin history list --cmd-only --print0 -r false 2>/dev/null
            and return 0
        end
    end

    history -z
end

function __fle_fzf_history
    __fle_history_source | fzf -q (commandline) \
        -e +m --read0 --print0 --height=45% \
        --prompt="History> " \
        --preview='fish_indent --ansi < {+sf}' \
        --preview-window=right:wrap \
        --tiebreak=index \
        --bind=ctrl-r:toggle-sort,ctrl-f:page-down,ctrl-b:page-up | read -lz result

    commandline -f repaint
    commandline -- $result
end

function __fle_atuin_contains_candidates --argument-names query
    begin
        if command -sq perl
            set -lx __FLE_ATUIN_CONTAINS_QUERY "$query"
            ATUIN_LOG=error atuin history list --cmd-only --print0 -r false 2>/dev/null | \
                perl -0ne 'BEGIN { $q = lc($ENV{"__FLE_ATUIN_CONTAINS_QUERY"} // "") } next if $seen{$_}++; print if index(lc($_), $q) >= 0'
        else
            ATUIN_LOG=error atuin search \
                --cmd-only \
                --print0 \
                --search-mode full-text \
                --filter-mode global \
                --limit 200 \
                -- "$query" 2>/dev/null
        end
    end | string split0
end

function __fle_atuin_contains_reset
    set -e __fle_atuin_contains_query
    set -e __fle_atuin_contains_results
    set -g __fle_atuin_contains_index 0
end

function __fle_atuin_contains_should_reuse --argument-names buffer
    set -q __fle_atuin_contains_query
    or return 1

    if test "$buffer" = "$__fle_atuin_contains_query"
        return 0
    end

    contains -- "$buffer" $__fle_atuin_contains_results
end

function __fle_atuin_contains_load --argument-names query
    set -g __fle_atuin_contains_query "$query"
    set -g __fle_atuin_contains_results (__fle_atuin_contains_candidates "$query")
    set -g __fle_atuin_contains_index 0
end

function __fle_atuin_contains_search --argument-names direction
    if commandline --search-mode
        if test "$direction" = backward
            commandline -f history-search-backward
        else
            commandline -f history-search-forward
        end
        return
    end

    if commandline --paging-mode
        if test "$direction" = backward
            commandline -f up-line
        else
            commandline -f down-line
        end
        return
    end

    set -l lineno (commandline --line)
    if test "$direction" = backward
        if test "$lineno" -ne 1
            commandline -f up-line
            return
        end
    else
        set -l line_count (count (commandline))
        if test "$lineno" -ne "$line_count"
            commandline -f down-line
            return
        end
    end

    if not command -sq atuin
        if test "$direction" = backward
            up-or-search
        else
            down-or-search
        end
        return
    end

    set -l buffer (commandline -b)
    if not __fle_atuin_contains_should_reuse "$buffer"
        __fle_atuin_contains_load "$buffer"
    end

    set -l count (count $__fle_atuin_contains_results)
    if test "$count" -eq 0
        commandline -f repaint
        return
    end

    if test "$__fle_atuin_contains_index" -eq 0
        set -g __fle_atuin_contains_index 1
    else if test "$direction" = backward
        set -g __fle_atuin_contains_index (math $__fle_atuin_contains_index + 1)
        if test "$__fle_atuin_contains_index" -gt "$count"
            set -g __fle_atuin_contains_index 1
        end
    else
        set -g __fle_atuin_contains_index (math $__fle_atuin_contains_index - 1)
        if test "$__fle_atuin_contains_index" -lt 1
            set -g __fle_atuin_contains_index "$count"
        end
    end

    commandline -r "$__fle_atuin_contains_results[$__fle_atuin_contains_index]"
    commandline -f repaint
end

function __fle_atuin_contains_search_backward
    __fle_atuin_contains_search backward
end

function __fle_atuin_contains_search_forward
    __fle_atuin_contains_search forward
end

function __fle_fzf_files
    set -l cmd $FZF_FILES_COMMAND
    test -n "$cmd"; or set cmd fd

    set -l prompt $FZF_FILES_PROMPT
    test -n "$prompt"; or set prompt File

    set -l preview_cmd $FZF_FILES_PREVIEW_COMMAND
    test -n "$preview_cmd"; or set preview_cmd 'fzf-file-preview {}'

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

if functions -q _atuin_search
    bind \cr _atuin_search
    if bind -M insert >/dev/null 2>&1
        bind -M insert \cr _atuin_search
    end
end

if functions -q _atuin_bind_up
    bind up _atuin_bind_up 2>/dev/null
    or bind -k up _atuin_bind_up
    bind \eOA _atuin_bind_up
    bind \e\[A _atuin_bind_up
    if bind -M insert >/dev/null 2>&1
        bind -M insert up _atuin_bind_up 2>/dev/null
        or bind -M insert -k up _atuin_bind_up
        bind -M insert \eOA _atuin_bind_up
        bind -M insert \e\[A _atuin_bind_up
    end
end

bind \er __fle_fzf_history
bind \eo __fle_fzf_files_files
bind \eO __fle_fzf_files_files_with_hidden
bind \ed __fle_fzf_files_dirs
bind \eD __fle_fzf_files_dirs_with_hidden
bind \ev __fle_fzf_files_nvim
bind \eg __fle_fzf_files_rg

bind \et __fle_type

bind \cp __fle_atuin_contains_search_backward
bind \cn __fle_atuin_contains_search_forward
if bind -M insert >/dev/null 2>&1
    bind -M insert \cp __fle_atuin_contains_search_backward
    bind -M insert \cn __fle_atuin_contains_search_forward
end

bind \cf forward-word
bind \cb backward-word

bind \e. history-token-search-backward
bind \e, history-token-search-forward
bind \e/ __fle_prepend_last_history_line

bind \cz __fle_fg

# sane <c-c>
bind \cc 'commandline ""'
