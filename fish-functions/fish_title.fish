set -x FISH_TITLE

function __fish_title_or_pwd
    if test -n "$FISH_TITLE"
        echo -s $FISH_TITLE
    else
        # Replace $HOME with "~"
        set realhome ~
        set -l tmp (string replace -r '^'"$realhome"'($|/)' '~$1' $PWD)
        echo $tmp
    end
end

function fish_title
    set -l cmd (status current-command)
    test "$cmd" != fish
    and echo -n "$cmd "
    __fish_title_or_pwd
end
