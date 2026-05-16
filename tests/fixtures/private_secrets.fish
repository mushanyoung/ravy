set -l config_home "$XDG_CONFIG_HOME"
test -n "$config_home"; or set config_home "$HOME/.config"
set -l secrets_tsv "$config_home/ravy/secrets.tsv"

if test -f "$secrets_tsv"
    while read --line line
        set line (string replace -r '\r$' '' -- "$line")
        set -l trimmed (string trim -- "$line")

        if test -z "$trimmed"
            continue
        end

        string match -qr '^#' -- "$trimmed"
        and continue

        set -l entry (string split -m 1 \t -- "$line")
        if test (count $entry) -lt 2
            continue
        end

        set -l key (string trim -- "$entry[1]")
        set -l value (string replace -r '^[ \t]+' '' -- "$entry[2]")
        if string match -qr '^~(/|$)' -- "$value"
            set value "$HOME"(string sub -s 2 -- "$value")
        end

        switch "$key"
            case '' '#*'
                continue
        end
        set -gx $key "$value"
    end < "$secrets_tsv"
end
