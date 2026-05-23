function fish_prompt --description 'Write out the prompt'
    set -l last_status $status
    set -l normal (set_color normal)
    set -l prompt_status ""
    set -q fish_prompt_pwd_dir_length
    or set -lx fish_prompt_pwd_dir_length 0

    # Применить немедленно во всех запущенных fish
    if status is-interactive
        source ~/.config/fish/functions/fish_prompt.fish
    end

    set -l suffix '󱞪'
    if functions -q fish_is_root_user; and fish_is_root_user
        set suffix '#'
    end

    if test $last_status -ne 0
        set prompt_status (set_color '{{colors.error.default.hex}}')"[$last_status]"$normal" "
    end

    set -l ssh_indicator ""
    if set -q SSH_TTY
        set ssh_indicator (set_color '{{colors.error.default.hex}}')"💀 "$normal
    end

    # Git info
    set -l git_info ""
    if git rev-parse --is-inside-work-tree &>/dev/null
        set -l branch (git symbolic-ref --short HEAD 2>/dev/null; or git rev-parse --short HEAD 2>/dev/null)
        set -l git_flags ""

        if not git diff --quiet 2>/dev/null
            set git_flags "$git_flags!"
        end
        if not git diff --cached --quiet 2>/dev/null
            set git_flags "$git_flags+"
        end
        if test -n "$(git ls-files --others --exclude-standard 2>/dev/null | head -1)"
            set git_flags "$git_flags?"
        end

        set -l ahead_behind (git rev-list --left-right --count HEAD...@{upstream} 2>/dev/null)
        if test -n "$ahead_behind"
            set -l ahead (echo $ahead_behind | awk '{print $1}')
            set -l behind (echo $ahead_behind | awk '{print $2}')
            if test $ahead -gt 0
                set git_flags "$git_flags↑$ahead"
            end
            if test $behind -gt 0
                set git_flags "$git_flags↓$behind"
            end
        end

        if test -n "$git_flags"
            set git_flags " [$git_flags]"
        end

        # "on" — on_surface_variant, branch — secondary, flags — error
        set git_info \
            " "(set_color '{{colors.on_surface_variant.default.hex}}')"on "$normal \
            " "(set_color '{{colors.secondary.default.hex}}' --bold)"$branch"$normal \
            (set_color '{{colors.error.default.hex}}')"$git_flags"$normal
    end

    # Tool version via
    set -l via_info ""
    if test -f package.json; or test -f .node-version; or test -f .nvmrc
        set -l node_ver (node --version 2>/dev/null)
        if test -n "$node_ver"
            set via_info \
                " "(set_color '{{colors.on_surface_variant.default.hex}}')"via"$normal \
                " "(set_color '{{colors.tertiary.default.hex}}')"⬡ $node_ver"$normal
        end
    else if test -f Cargo.toml
        set -l rust_ver (rustc --version 2>/dev/null | awk '{print "v"$2}')
        if test -n "$rust_ver"
            set via_info \
                " "(set_color '{{colors.on_surface_variant.default.hex}}')"via"$normal \
                " "(set_color '{{colors.tertiary.default.hex}}')"🦀 $rust_ver"$normal
        end
    else if test -f pyproject.toml; or test -f setup.py; or test -f requirements.txt
        set -l py_ver (python3 --version 2>/dev/null | awk '{print "v"$2}')
        if test -n "$py_ver"
            set via_info \
                " "(set_color '{{colors.on_surface_variant.default.hex}}')"via"$normal \
                " "(set_color '{{colors.tertiary.default.hex}}')"🐍 $py_ver"$normal
        end
    else if test -f go.mod
        set -l go_ver (go version 2>/dev/null | awk '{print $3}' | sed 's/go/v/')
        if test -n "$go_ver"
            set via_info \
                " "(set_color '{{colors.on_surface_variant.default.hex}}')"via"$normal \
                " "(set_color '{{colors.tertiary.default.hex}}')"🐹 $go_ver"$normal
        end
    end

    # username — primary, @ — on_surface_variant, hostname — tertiary, path — on_surface
    echo -s $ssh_indicator \
        (set_color '{{colors.primary.default.hex}}' --bold)(whoami)$normal \
        (set_color '{{colors.on_surface_variant.default.hex}}')"@"$normal \
        (set_color '{{colors.tertiary.default.hex}}' --bold)(hostname)$normal \
        " "(set_color '{{colors.on_surface.default.hex}}')(prompt_pwd)$normal \
        $git_info \
        $via_info \
        " "$prompt_status
    echo -n -s (set_color '{{colors.primary.default.hex}}' --bold)$suffix' '$normal
end

function fish_right_prompt
    # Command duration — показывается только если >= 1 сек
    set -l duration_str ""
    if set -q CMD_DURATION; and test $CMD_DURATION -ge 1000
        set -l duration $CMD_DURATION
        if test (math "$duration / 1000") -ge 60
            set -l mins (math -s0 "$duration / 60000")
            set -l rem_secs (math -s0 "($duration % 60000) / 1000")
            set duration_str (set_color '{{colors.secondary.default.hex}}')"⏱ $mins"m"$rem_secs"s$normal" "
        else
            set -l secs (math -s1 "$duration / 1000")
            set duration_str (set_color '{{colors.secondary.default.hex}}')"⏱ $secs"s$normal" "
        end
    end

    echo -n -s $duration_str(set_color '{{colors.on_surface_variant.default.hex}}')(date '+%H:%M')(set_color normal)
end
