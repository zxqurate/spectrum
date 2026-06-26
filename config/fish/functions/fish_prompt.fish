function __qs_hex -a color
    string replace -a '#' '' -- $color
end

function fish_prompt --description 'Minimal two-line prompt'
    set -l colors "$HOME/.local/state/quickshell/generated/fish_prompt_colors.fish"
    if test -f $colors
        source $colors
    end

    set -l accent (set_color (__qs_hex $__qs_prompt_accent 2>/dev/null); or echo 82D5C7)
    set -l muted (set_color (__qs_hex $__qs_prompt_muted 2>/dev/null); or echo 899390)
    set -l fg (set_color (__qs_hex $__qs_prompt_fg 2>/dev/null); or echo DDE4E1)
    set -l err (set_color (__qs_hex $__qs_prompt_err 2>/dev/null); or echo FFB4AB)
    set -l path_bg (set_color --background=(__qs_hex $__qs_prompt_path_bg 2>/dev/null); or set_color --background=1A2422)
    set -l time_bg (set_color --background=(__qs_hex $__qs_prompt_time_bg 2>/dev/null); or set_color --background=243530)
    set -l reset (set_color normal)

    set -l pwd (prompt_pwd)

    echo -ns "  "$path_bg$accent"▎"$fg" "$pwd" "$reset

    if test "$CMD_DURATION" -gt 80
        set -l secs (math -s1 "$CMD_DURATION / 1000")
        echo -ns $time_bg$muted" "$secs"s "$reset
    end

    echo

    set -l marker $accent
    if test $status -ne 0
        set marker $err
    end
    echo -ns "  "$marker"› "$reset
end
