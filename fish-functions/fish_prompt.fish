# no greeting message
set fish_greeting ''

set -x PROMPT_PATH

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
    set -l PARSER_ADDED A
    set -l PARSER_UNSTAGED '^.M'
    set -l PARSER_STAGED '^M'
    set -l PARSER_RENAMED R
    set -l PARSER_DELETED D
    set -l PARSER_UNMERGED U
    set -l PARSER_UNTRACKED '\?\?'
    set -l PARSER_AHEAD ahead
    set -l PARSER_BEHIND behind
    set -l INDICATOR_ADDED +
    set -l INDICATOR_UNSTAGED \*
    set -l INDICATOR_STAGED .
    set -l INDICATOR_RENAMED »
    set -l INDICATOR_DELETED -
    set -l INDICATOR_UNMERGED !
    set -l INDICATOR_UNTRACKED \#
    set -l INDICATOR_AHEAD \>
    set -l INDICATOR_BEHIND \<
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
    if test -n "$PROMPT_PATH"
        echo -s $PROMPT_PATH
    else
        # Replace $HOME with "~"
        set realhome ~
        set -l tmp (string replace -r '^'"$realhome"'($|/)' '~$1' $PWD)
        echo $tmp
    end
end

function fish_prompt
    set -l cmd_status $status
    if test $cmd_status -le 0
        set -e cmd_status
    end

    set -l pcustom (type -q __prompt_customize; and __prompt_customize)

    set -l user_color 8787af
    set -l cmd_indicator '❯'
    switch $USER
        case root toor
            set user_color d70000
            set cmd_indicator "$cmd_indicator""!"
    end

    set -l bg_jobs (count (jobs -c))

    # line 1
    # last command duration and status
    if set -q CMD_DURATION
        echo -n -s (set_color 666) (__prompt_cmd_duration $CMD_DURATION) ' ' (set_color d70000) (__prompt_cmd_status $cmd_status)
        set -e CMD_DURATION
    end
    echo

    # line 2
    set_color -b 222
    echo -n '  '
    set -l promptlen 2

    # path
    set -l path_str (__prompt_pwd)
    echo -n -s (test -w $PWD; and set_color 008787; or set_color d70000) $path_str ' '
    set promptlen (math $promptlen + (string length $path_str) + 1)

    # git
    set -l gbranch (__prompt_git_branch)
    if test -n "$gbranch"
        set -l gstatus (__prompt_git_status)
        echo -n -s (set_color 5f8700) $gbranch (set_color d78700) $gstatus ' '
        set promptlen (math $promptlen + (string length $gbranch) + (string length $gstatus) + 1)
    end

    # custom
    if test -n "$pcustom"
        echo -n -s (set_color 5f5f5f) $pcustom (set_color -b 222) ' '
        set promptlen (math $promptlen + (string length $pcustom) + 1)
    end

    # user
    echo -n -s (set_color $user_color) $USER ' '
    set promptlen (math $promptlen + (string length $USER) + 1)

    # jobs
    if test $bg_jobs -gt 0
        echo -n -s (set_color d700af) "%$bg_jobs "
        set promptlen (math $promptlen + (string length "%$bg_jobs") + 1)
    end

    # ssh
    if test -n "$SSH_CLIENT"
        echo -n -s (set_color d75f00) ' '
        set promptlen (math $promptlen + 2) # ' ' is 2 characters wide
    end

    # padding to fill the remaining width
    set -l termwidth (tput cols)
    set -l padding (string repeat -n (math $termwidth - $promptlen) " ")
    set_color -b 222
    echo -s $padding

    # line 3
    # indicator
    echo -n -s (set_color normal) (set_color 666) "$cmd_indicator "
end
