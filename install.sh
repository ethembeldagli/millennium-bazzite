#!/bin/sh
# Millennium for Bazzite
#
# Unofficial: not made by, affiliated with, or endorsed by the Millennium
# project (Steam Homebrew), Valve or Universal Blue. It installs Millennium's
# own official releases, unchanged.
#
# Installs Millennium (themes and plugins for the Steam desktop client) into
# your home folder, so it works on read-only systems like Bazzite where the
# official installer can't write to /usr. No root, no reboot.
#
#   curl -fsSL https://raw.githubusercontent.com/ethembeldagli/millennium-bazzite/main/install.sh | sh
#
# It also installs a `millennium-bazzite` command and keeps Millennium up to
# date in the background. Run either one again to update, change settings or
# remove it. Flags are optional: see --help.

set -u

INSTALLER_VERSION="1.3.0"
UPSTREAM="SteamClientHomebrew/Millennium"
RAW_URL="https://raw.githubusercontent.com/ethembeldagli/millennium-bazzite/main/install.sh"
SELF_URL="${MILLENNIUM_BAZZITE_SELF_URL:-$RAW_URL}"
ONE_LINER="curl -fsSL $RAW_URL | sh"

action=""
beta=0
yes=0
restart=ask
game_mode=""
from=""
auto_choice=""
delete_data=""

# ---------------------------------------------------------------- output

if [ -t 1 ]; then
    B="$(printf '\033[1m')" D="$(printf '\033[2m')" R="$(printf '\033[0m')"
    RED="$(printf '\033[31m')" GRN="$(printf '\033[32m')" YLW="$(printf '\033[33m')"
    CYN="$(printf '\033[36m')" MAG="$(printf '\033[35m')"
else
    B="" D="" R="" RED="" GRN="" YLW="" CYN="" MAG=""
fi

say()  { printf '%s\n' "$*"; }
step() { printf '%s::%s %s\n' "$CYN" "$R" "$*"; }
ok()   { printf '%s✓%s %s\n' "$GRN" "$R" "$*"; }
warn() { printf '%s!%s %s\n' "$YLW" "$R" "$*" >&2; }
die()  { ui_stop; printf '%sError:%s %s\n' "$RED" "$R" "$*" >&2; exit 1; }
row()  { printf '  %s%-12s%s %s\n' "$D" "$1" "$R" "$2"; }

banner() {
    say ""
    say "  ${B}${MAG}Millennium for Bazzite${R}  ${D}v$INSTALLER_VERSION${R}"
    say "  ${D}Steam themes and plugins · no root · survives updates${R}"
    say ""
}

# >>> fullscreen ui >>>
# A full-screen, full-colour, animated menu in the style of Terminal Wrapped's
# slides, shared by the ethembeldagli installers. When the terminal can't show
# it (too small, no colour, not interactive) the plain text menu is used
# instead. INSTALLER_NO_ANIMATION=1 keeps the colours but skips the motion.
# UI_THEME is "TOP|BOTTOM|ACCENT|ACCENT2", each colour as "R G B".

UI_ESC=$(printf '\033')
UI_CR=$(printf '\r')
UI_NL='
'
UI_ACTIVE=0 UI_ANIM=0 UI_TRUE=0 UI_SHOWN=0
UI_CLEANUP="" UI_LOG="" UI_STTY="" UI_PREPARED="" UI_KEY="" UI_CHOICE=""
UI_SEL=1 UI_TICK=0 UI_FADE=0 UI_SLIDE=0 UI_BARFADE=100 UI_SHINE=-99 UI_BG_LEVEL=100
UI_TITLE="" UI_RIGHT="" UI_SUB="" UI_LINES="" UI_OPTS="" UI_FOOT="" UI_BRAND="" UI_SPARKS=""

# ui_supported: can this terminal show the full-screen menu?
ui_supported() {
    [ -z "${NO_COLOR:-}" ] || return 1
    [ -z "${PLAIN_INSTALLER:-}" ] || return 1
    case "${TERM:-dumb}" in dumb | linux | vt*) return 1 ;; esac
    case "${COLORTERM:-}" in
        truecolor | 24bit) UI_TRUE=1 ;;
        *) case "${TERM:-}" in *256col* | xterm-kitty | alacritty | wezterm | foot*) UI_TRUE=0 ;; *) return 1 ;; esac ;;
    esac
    [ -t 1 ] || return 1
    ( : </dev/tty ) 2>/dev/null || return 1
    command -v stty >/dev/null 2>&1 && command -v dd >/dev/null 2>&1 || return 1
    ui_size || return 1
    [ "$UI_COLS" -ge 60 ] && [ "$UI_ROWS" -ge 20 ] || return 1
    # Motion needs a sleep that takes fractions of a second.
    if [ -z "${INSTALLER_NO_ANIMATION:-}" ] && sleep 0.01 2>/dev/null; then UI_ANIM=1; fi
    return 0
}

ui_size() {
    _ui_size=$(stty size </dev/tty 2>/dev/null) || return 1
    UI_ROWS=${_ui_size% *} UI_COLS=${_ui_size#* }
    case "$UI_ROWS$UI_COLS" in '' | *[!0-9]*) return 1 ;; esac
    [ "$UI_ROWS" -gt 0 ]
}

ui_nap() {
    [ "$UI_ANIM" = 1 ] && sleep "$1" 2>/dev/null
    return 0
}

# ui_sgr 38|48 R G B -> UI_C, the escape for that foreground/background colour
ui_sgr() {
    if [ "$UI_TRUE" = 1 ]; then
        UI_C="${UI_ESC}[$1;2;$2;$3;$4m"
    else
        UI_C="${UI_ESC}[$1;5;$((16 + 36 * (($2 * 5 + 127) / 255) + 6 * (($3 * 5 + 127) / 255) + ($4 * 5 + 127) / 255))m"
    fi
}

# ui_mix "R G B" "R G B" STEP STEPS -> _ui_r _ui_g _ui_b and _ui_rgb
ui_mix() {
    # shellcheck disable=SC2086 # split the colours into their parts
    set -- $1 $2 "$3" "$4"
    _ui_r=$(($1 + ($4 - $1) * $7 / $8))
    _ui_g=$(($2 + ($5 - $2) * $7 / $8))
    _ui_b=$(($3 + ($6 - $3) * $7 / $8))
    _ui_rgb="$_ui_r $_ui_g $_ui_b"
}

# ui_spaces N -> _ui_sp, N spaces
ui_spaces() {
    _ui_sp=""
    _ui_sn=$1
    while [ "$_ui_sn" -gt 0 ]; do _ui_sp="$_ui_sp "; _ui_sn=$((_ui_sn - 1)); done
    return 0
}

# ui_lines TEXT -> _ui_cnt, its number of lines
ui_lines() {
    _ui_cnt=0
    _ui_rest=$1
    [ -n "$_ui_rest" ] || return 0
    _ui_cnt=1
    while :; do
        case "$_ui_rest" in
            *"$UI_NL"*) _ui_rest=${_ui_rest#*"$UI_NL"} && _ui_cnt=$((_ui_cnt + 1)) ;;
            *) return 0 ;;
        esac
    done
}

# ui_prepare: geometry and colours for this theme and terminal size.
ui_prepare() {
    _ui_old_ifs=$IFS
    IFS='|'
    # shellcheck disable=SC2086 # split the theme into its four colours
    set -- $UI_THEME
    IFS=$_ui_old_ifs
    UI_TOP=$1 UI_BOTTOM=$2 UI_ACC=$3 UI_ACC2=$4
    ui_mix "$UI_TOP" "$UI_BOTTOM" 1 2 && UI_MID=$_ui_rgb
    ui_mix "240 240 255" "$UI_TOP" 45 100 && UI_DIM_RGB=$_ui_rgb
    ui_spaces "$UI_COLS" && UI_BLANK=$_ui_sp
    UI_W=$((UI_COLS - 8))
    [ "$UI_W" -gt 66 ] && UI_W=66
    UI_X=$(((UI_COLS - UI_W) / 2 + 1))
    UI_PREPARED="$UI_ROWS:$UI_COLS"
    ui_bg_level "$UI_BG_LEVEL"
    ui_fade "$UI_FADE"
    return 0
}

# ui_bg_level PERCENT: the gradient, faded in from black by PERCENT.
ui_bg_level() {
    UI_BG_LEVEL=$1
    _ui_y=1
    while [ "$_ui_y" -le "$UI_ROWS" ]; do
        ui_mix "$UI_TOP" "$UI_BOTTOM" "$((_ui_y - 1))" "$((UI_ROWS > 1 ? UI_ROWS - 1 : 1))"
        ui_mix "0 0 0" "$_ui_rgb" "$1" 100
        ui_sgr 48 "$_ui_r" "$_ui_g" "$_ui_b"
        eval "UI_BG_$_ui_y=\$UI_C"
        _ui_y=$((_ui_y + 1))
    done
    return 0
}

# ui_colour NAME "R G B": set NAME to that text colour, faded in by UI_FADE.
ui_colour() {
    ui_mix "$UI_MID" "$2" "$UI_FADE" 100
    ui_sgr 38 "$_ui_r" "$_ui_g" "$_ui_b"
    eval "$1=\$UI_C"
}

# ui_fade PERCENT: text colours, faded in from the background by PERCENT.
ui_fade() {
    UI_FADE=$1
    ui_colour UI_FG_C "240 240 255"
    ui_colour UI_DIM_C "$UI_DIM_RGB"
    ui_colour UI_ACC_C "$UI_ACC"
    ui_colour UI_ACC2_C "$UI_ACC2"
    ui_colour UI_GOOD_C "124 255 178"
    ui_colour UI_WARN_C "255 206 92"
    ui_colour UI_BAD_C "255 112 120"
    ui_bar "$UI_BARFADE"
    return 0
}

# ui_bar PERCENT: the colour of the selection bar, faded in by PERCENT.
ui_bar() {
    UI_BARFADE=$1
    ui_mix "$UI_MID" "$UI_ACC" "$((UI_FADE * $1 / 100))" 100
    ui_sgr 48 "$_ui_r" "$_ui_g" "$_ui_b" && UI_BAR_BG=$UI_C
    ui_mix "240 240 255" "$UI_BOTTOM" "$1" 100
    ui_sgr 38 "$_ui_r" "$_ui_g" "$_ui_b" && UI_BAR_FG=$UI_C
    return 0
}

ui_start() {
    [ "$UI_ACTIVE" = 1 ] && return 0
    UI_STTY=$(stty -g </dev/tty)
    stty -echo -icanon min 0 time 1 </dev/tty
    printf '%s[?1049h%s[?25l%s[?7l' "$UI_ESC" "$UI_ESC" "$UI_ESC"
    UI_ACTIVE=1 UI_SHOWN=0 UI_PREPARED="" UI_FADE=0
    if [ "$UI_ANIM" = 1 ]; then UI_BG_LEVEL=0; else UI_BG_LEVEL=100; fi
    trap 'ui_stop; eval "${UI_CLEANUP:-:}"' EXIT
    trap 'ui_stop; exit 130' INT TERM HUP
    return 0
}

ui_stop() {
    [ "$UI_ACTIVE" = 1 ] || return 0
    printf '%s[0m%s[?7h%s[?25h%s[?1049l' "$UI_ESC" "$UI_ESC" "$UI_ESC" "$UI_ESC"
    stty "$UI_STTY" </dev/tty 2>/dev/null || true
    UI_ACTIVE=0
    return 0
}

# ui_put ROW COL TEXT: add TEXT at ROW, COL on top of that row's background.
ui_put() {
    [ "$1" -ge 1 ] && [ "$1" -le "$UI_ROWS" ] || return 0
    _ui_bg=""
    eval "_ui_bg=\$UI_BG_$1"
    UI_FRAME="$UI_FRAME${UI_ESC}[$1;$2H$_ui_bg$3"
}

# The gradient rule under the title. It draws itself in as the text fades in,
# and a light sweeps along it at UI_SHINE.
ui_rule() {
    _ui_rule=""
    _ui_len=$((UI_W * UI_FADE / 100))
    _ui_i=0
    while [ "$_ui_i" -lt "$_ui_len" ]; do
        ui_mix "$UI_ACC" "$UI_ACC2" "$_ui_i" "$UI_W"
        _ui_d=$((_ui_i - UI_SHINE))
        [ "$_ui_d" -lt 0 ] && _ui_d=$((-_ui_d))
        if [ "$_ui_d" -lt 8 ]; then ui_mix "$_ui_rgb" "255 255 255" "$((8 - _ui_d))" 11; fi
        ui_mix "$UI_MID" "$_ui_rgb" "$UI_FADE" 100
        ui_sgr 38 "$_ui_r" "$_ui_g" "$_ui_b"
        _ui_rule="$_ui_rule$UI_C━"
        _ui_i=$((_ui_i + 1))
    done
    return 0
}

# A loading bar with a bright stripe gliding back and forth.
ui_loader() {
    _ui_seg=14
    _ui_span=$((UI_W - _ui_seg))
    _ui_pos=$((UI_TICK * 2 % (2 * _ui_span)))
    [ "$_ui_pos" -gt "$_ui_span" ] && _ui_pos=$((2 * _ui_span - _ui_pos))
    ui_mix "$UI_MID" "$UI_DIM_RGB" "$((UI_FADE * 35 / 100))" 100
    ui_sgr 38 "$_ui_r" "$_ui_g" "$_ui_b" && _ui_track=$UI_C
    _ui_load=""
    _ui_i=0
    while [ "$_ui_i" -lt "$UI_W" ]; do
        if [ "$_ui_i" -ge "$_ui_pos" ] && [ "$_ui_i" -lt "$((_ui_pos + _ui_seg))" ]; then
            ui_mix "$UI_ACC" "$UI_ACC2" "$((_ui_i - _ui_pos))" "$_ui_seg"
            ui_mix "$UI_MID" "$_ui_rgb" "$UI_FADE" 100
            ui_sgr 38 "$_ui_r" "$_ui_g" "$_ui_b"
            _ui_load="$_ui_load$UI_C━"
        else
            _ui_load="$_ui_load$_ui_track─"
        fi
        _ui_i=$((_ui_i + 1))
    done
    return 0
}

# ui_draw: draw UI_TITLE, UI_SUB, UI_LINES, UI_OPTS and UI_FOOT, centred on the
# gradient, faded by UI_FADE and shifted by UI_SLIDE rows. UI_LINES holds
# "info|label|value|tone", "text|tone|text", "big|tone|text", "log|text",
# "spin|text", "load" or "blank" lines; UI_OPTS holds "key|label|hint".
ui_draw() {
    ui_size || return 0
    [ "$UI_PREPARED" = "$UI_ROWS:$UI_COLS" ] || ui_prepare
    UI_FRAME="${UI_ESC}[0m"
    _ui_y=1
    while [ "$_ui_y" -le "$UI_ROWS" ]; do
        ui_put "$_ui_y" 1 "$UI_BLANK"
        _ui_y=$((_ui_y + 1))
    done

    ui_lines "$UI_LINES" && _ui_nlines=$_ui_cnt
    ui_lines "$UI_OPTS" && _ui_nopts=$_ui_cnt
    _ui_count=4
    [ "$_ui_nlines" -gt 0 ] && _ui_count=$((_ui_count + _ui_nlines + 1))
    [ "$_ui_nopts" -gt 0 ] && _ui_count=$((_ui_count + _ui_nopts + 1))
    [ -n "$UI_FOOT" ] && _ui_count=$((_ui_count + 2))
    _ui_y=$(((UI_ROWS - _ui_count) / 2 + 1))
    [ "$_ui_y" -lt 2 ] && _ui_y=2
    UI_CARD_TOP=$_ui_y UI_CARD_BOTTOM=$((_ui_y + _ui_count))
    _ui_y=$((_ui_y + UI_SLIDE))
    _ui_x=$UI_X

    if [ "$UI_FADE" -gt 0 ]; then
        # Title, version on the right, subtitle and the gradient rule.
        ui_put "$_ui_y" "$_ui_x" "$UI_ACC_C${UI_ESC}[1m◆ $UI_FG_C$UI_TITLE${UI_ESC}[22m"
        if [ -n "$UI_RIGHT" ]; then
            ui_put "$_ui_y" "$((_ui_x + UI_W - ${#UI_RIGHT}))" "$UI_DIM_C$UI_RIGHT"
        fi
        _ui_y=$((_ui_y + 1))
        ui_put "$_ui_y" "$_ui_x" "$UI_DIM_C$UI_SUB"
        _ui_y=$((_ui_y + 1))
        UI_RULE_Y=$_ui_y
        ui_rule
        ui_put "$_ui_y" "$_ui_x" "$_ui_rule"
        _ui_y=$((_ui_y + 2))

        if [ "$_ui_nlines" -gt 0 ]; then
            while IFS='|' read -r _ui_kind _ui_a _ui_b _ui_c; do
                case "$_ui_kind" in
                    info)
                        ui_tone "$_ui_c"
                        ui_spaces "$((12 - ${#_ui_a}))"
                        ui_put "$_ui_y" "$_ui_x" "$UI_DIM_C$_ui_a$_ui_sp $_ui_tone$_ui_b"
                        ;;
                    text) ui_tone "$_ui_a" && ui_put "$_ui_y" "$_ui_x" "$_ui_tone$_ui_b" ;;
                    big) ui_tone "$_ui_a" && ui_put "$_ui_y" "$_ui_x" "$_ui_tone${UI_ESC}[1m$_ui_b${UI_ESC}[22m" ;;
                    log) ui_put "$_ui_y" "$((_ui_x + 2))" "$UI_DIM_C$_ui_a" ;;
                    spin)
                        ui_spinner
                        ui_put "$_ui_y" "$_ui_x" "$UI_ACC2_C$_ui_spin $UI_FG_C${UI_ESC}[1m$_ui_a${UI_ESC}[22m"
                        ;;
                    load) ui_loader && ui_put "$_ui_y" "$_ui_x" "$_ui_load" ;;
                esac
                _ui_y=$((_ui_y + 1))
            done <<EOF
$UI_LINES
EOF
            _ui_y=$((_ui_y + 1))
        fi

        if [ "$_ui_nopts" -gt 0 ]; then
            _ui_i=1
            while IFS='|' read -r _ui_key _ui_label _ui_hint; do
                _ui_text="$_ui_label${_ui_hint:+  $_ui_hint}"
                _ui_pad=$((UI_W - ${#_ui_text} - 7))
                [ "$_ui_pad" -lt 1 ] && _ui_pad=1
                ui_spaces "$_ui_pad"
                if [ "$_ui_i" = "$UI_SEL" ]; then
                    ui_put "$_ui_y" "$_ui_x" "$UI_BAR_BG$UI_BAR_FG${UI_ESC}[1m ▸ $_ui_label${UI_ESC}[22m${_ui_hint:+  $_ui_hint}$_ui_sp$_ui_key   "
                else
                    ui_put "$_ui_y" "$_ui_x" "   $UI_FG_C$_ui_label$UI_DIM_C${_ui_hint:+  $_ui_hint}$_ui_sp$_ui_key"
                fi
                _ui_i=$((_ui_i + 1))
                _ui_y=$((_ui_y + 1))
            done <<EOF
$UI_OPTS
EOF
            _ui_y=$((_ui_y + 1))
        fi

        if [ -n "$UI_FOOT" ]; then
            _ui_y=$((_ui_y + 1))
            ui_put "$_ui_y" "$_ui_x" "$UI_DIM_C$UI_FOOT"
        fi
    fi
    if [ -n "$UI_BRAND" ] && [ "$UI_BG_LEVEL" -ge 100 ] && [ "$UI_CARD_BOTTOM" -lt "$((UI_ROWS - 1))" ]; then
        ui_put "$UI_ROWS" "$(((UI_COLS - ${#UI_BRAND}) / 2 + 1))" "$UI_DIM_C$UI_BRAND"
    fi
    printf '%s%s' "$UI_FRAME" "$UI_SPARKS"
    return 0
}

# Redraw just the rule, for the light sweeping along it.
ui_draw_rule() {
    [ "$UI_ANIM" = 1 ] && [ "$UI_FADE" -ge 100 ] && [ -n "${UI_RULE_Y:-}" ] || return 0
    UI_FRAME=""
    ui_rule
    ui_put "$UI_RULE_Y" "$UI_X" "$_ui_rule"
    printf '%s' "$UI_FRAME"
    return 0
}

ui_tone() {
    case "$1" in
        good) _ui_tone=$UI_GOOD_C ;;
        warn) _ui_tone=$UI_WARN_C ;;
        bad) _ui_tone=$UI_BAD_C ;;
        dim) _ui_tone=$UI_DIM_C ;;
        accent) _ui_tone=$UI_ACC_C ;;
        accent2) _ui_tone=$UI_ACC2_C ;;
        *) _ui_tone=$UI_FG_C ;;
    esac
    return 0
}

ui_spinner() {
    case $((UI_TICK % 10)) in
        0) _ui_spin="⠋" ;; 1) _ui_spin="⠙" ;; 2) _ui_spin="⠹" ;; 3) _ui_spin="⠸" ;; 4) _ui_spin="⠼" ;;
        5) _ui_spin="⠴" ;; 6) _ui_spin="⠦" ;; 7) _ui_spin="⠧" ;; 8) _ui_spin="⠇" ;; *) _ui_spin="⠏" ;;
    esac
    return 0
}

# ui_show: bring the current screen in. The first one fades the gradient up
# from black; every one slides up a little while its text fades in.
ui_show() {
    ui_size || return 0
    [ "$UI_PREPARED" = "$UI_ROWS:$UI_COLS" ] || ui_prepare
    if [ "$UI_ANIM" = 1 ]; then
        if [ "$UI_SHOWN" = 0 ]; then
            ui_fade 0
            for _ui_lvl in 12 28 46 64 80 92 100; do
                ui_bg_level "$_ui_lvl" && ui_draw && ui_nap 0.03
            done
        fi
        for _ui_step in "15 3" "35 2" "55 2" "75 1" "90 1"; do
            ui_fade "${_ui_step% *}"
            UI_SLIDE=${_ui_step#* }
            ui_draw
            ui_nap 0.025
        done
    fi
    UI_SHOWN=1 UI_SLIDE=0
    [ "$UI_BG_LEVEL" = 100 ] || ui_bg_level 100
    ui_fade 100
    ui_draw
    return 0
}

# ui_hide: fade the current screen's text out, sliding it up.
ui_hide() {
    if [ "$UI_ANIM" != 1 ] || [ "$UI_FADE" = 0 ]; then
        UI_FADE=0
        return 0
    fi
    for _ui_step in "70 0" "40 -1" "15 -1" "0 -2"; do
        ui_fade "${_ui_step% *}"
        UI_SLIDE=${_ui_step#* }
        ui_draw
        ui_nap 0.025
    done
    UI_SLIDE=0
    return 0
}

# ui_key: wait a moment for a key; sets UI_KEY to up, down, enter, esc,
# char:X or "" when nothing was pressed.
ui_key() {
    _ui_k=$(dd bs=1 count=1 2>/dev/null </dev/tty; echo .)
    _ui_k=${_ui_k%.}
    case "$_ui_k" in
        "") UI_KEY="" ;;
        "$UI_ESC")
            # Read the rest of the key's sequence one byte at a time, so keys
            # typed quickly one after another aren't swallowed together.
            _ui_seq=""
            _ui_kn=0
            while [ "$_ui_kn" -lt 8 ]; do
                _ui_c=$(dd bs=1 count=1 2>/dev/null </dev/tty)
                [ -n "$_ui_c" ] || break
                _ui_seq="$_ui_seq$_ui_c"
                _ui_kn=$((_ui_kn + 1))
                [ "$_ui_kn" -gt 1 ] || continue
                case "$_ui_c" in [A-Za-z~]) break ;; esac
            done
            case "$_ui_seq" in
                "[A" | OA) UI_KEY=up ;;
                "[B" | OB) UI_KEY=down ;;
                "") UI_KEY=esc ;;
                *) UI_KEY=other ;;
            esac
            ;;
        "$UI_NL" | "$UI_CR" | " ") UI_KEY=enter ;;
        *) UI_KEY="char:$(printf '%s' "$_ui_k" | tr '[:upper:]' '[:lower:]')" ;;
    esac
    return 0
}

# ui_move N: move the selection to option N, fading the bar in.
ui_move() {
    UI_SEL=$1
    if [ "$UI_ANIM" = 1 ]; then
        ui_bar 45 && ui_draw && ui_nap 0.02
    fi
    ui_bar 100
    ui_draw
    return 0
}

# ui_choose: show the menu until something is picked; sets UI_CHOICE to the
# key of the option, or "esc".
ui_choose() {
    ui_lines "$UI_OPTS" && _ui_n=$_ui_cnt
    [ "$UI_SEL" -ge 1 ] && [ "$UI_SEL" -le "$_ui_n" ] || UI_SEL=1
    UI_FOOT="↑↓ move · enter select · or press a key"
    UI_SHINE=-99
    ui_show
    while :; do
        _ui_before="$UI_ROWS:$UI_COLS"
        ui_key
        case "$UI_KEY" in
            "")
                if ui_size && [ "$UI_ROWS:$UI_COLS" != "$_ui_before" ]; then
                    ui_draw
                elif [ "$UI_ANIM" = 1 ]; then
                    # Every few seconds a light sweeps along the rule.
                    UI_SHINE=$((UI_SHINE + 4))
                    [ "$UI_SHINE" -gt "$((UI_W + 260))" ] && UI_SHINE=-12
                    [ "$UI_SHINE" -le "$((UI_W + 12))" ] && ui_draw_rule
                fi
                ;;
            up) ui_move "$((UI_SEL > 1 ? UI_SEL - 1 : _ui_n))" ;;
            down) ui_move "$((UI_SEL < _ui_n ? UI_SEL + 1 : 1))" ;;
            enter)
                UI_CHOICE=$(printf '%s\n' "$UI_OPTS" | sed -n "${UI_SEL}p" | cut -d'|' -f1)
                break
                ;;
            esc) UI_CHOICE=esc && break ;;
            char:*)
                _ui_letter=${UI_KEY#char:}
                if printf '%s\n' "$UI_OPTS" | grep -q "^$_ui_letter|"; then
                    UI_CHOICE=$_ui_letter
                    break
                fi
                case "$_ui_letter" in
                    k) ui_move "$((UI_SEL > 1 ? UI_SEL - 1 : _ui_n))" ;;
                    j) ui_move "$((UI_SEL < _ui_n ? UI_SEL + 1 : 1))" ;;
                esac
                ;;
        esac
    done
    UI_SHINE=-99
    return 0
}

# ui_ask QUESTION DETAIL DEFAULT(y|n): a full-screen yes/no question.
ui_ask() {
    ui_hide
    _ui_saved_lines=$UI_LINES _ui_saved_opts=$UI_OPTS _ui_saved_sel=$UI_SEL
    UI_LINES="big|accent2|$1"
    [ -n "$2" ] && UI_LINES="$UI_LINES${UI_NL}text||$2"
    UI_OPTS="y|Yes|${UI_NL}n|No|"
    if [ "$3" = y ]; then UI_SEL=1; else UI_SEL=2; fi
    ui_choose
    ui_hide
    UI_LINES=$_ui_saved_lines UI_OPTS=$_ui_saved_opts UI_SEL=$_ui_saved_sel
    [ "$UI_CHOICE" = y ]
}

# ui_busy TEXT: a full-screen "please wait" while something quick runs.
ui_busy() {
    UI_LINES="spin|$1${UI_NL}load" UI_OPTS="" UI_FOOT=""
    ui_show
    return 0
}

# ui_run TITLE COMMAND...: run COMMAND with its output going to a log, showing
# the latest lines on a progress screen, then the result. Returns its status.
ui_run() {
    _ui_title=$1
    shift
    UI_LOG=$(mktemp "${TMPDIR:-/tmp}/installer.XXXXXX") || return 1
    ui_hide
    # The job can't touch the screen: it runs with the full-screen view marked
    # inactive and its questions answered by their defaults.
    # shellcheck disable=SC2030,SC2034 # UI_IN_JOB is only for the job, read by the installers' own functions
    (UI_ACTIVE=0 UI_IN_JOB=1 && "$@") </dev/null >"$UI_LOG" 2>&1 &
    _ui_pid=$!
    UI_TICK=0 UI_OPTS="" UI_FOOT=""
    _ui_log=$(ui_log_lines)
    UI_LINES="spin|$_ui_title${UI_NL}load$_ui_log"
    ui_show
    while kill -0 "$_ui_pid" 2>/dev/null; do
        if [ $((UI_TICK % 5)) = 0 ]; then _ui_log=$(ui_log_lines); fi
        UI_LINES="spin|$_ui_title${UI_NL}load$_ui_log"
        ui_draw
        UI_TICK=$((UI_TICK + 1))
        sleep 0.06 2>/dev/null || sleep 1
    done
    _ui_status=0
    wait "$_ui_pid" || _ui_status=$?
    if [ "$_ui_status" = 0 ]; then
        UI_LINES="big|good|✓ Done$(ui_log_lines)"
    else
        UI_LINES="big|bad|✗ That didn't work$(ui_log_lines)"
    fi
    UI_FOOT="Press any key to close"
    ui_draw
    if [ "$_ui_status" = 0 ]; then ui_celebrate; fi
    UI_KEY=""
    while [ -z "$UI_KEY" ]; do ui_key; done
    return "$_ui_status"
}

# A burst of sparkles across the gradient, like the end of a Wrapped slide.
ui_celebrate() {
    [ "$UI_ANIM" = 1 ] || return 0
    _ui_seed=$(($$ * 7919 % 2147483647 + 1))
    _ui_stars=""
    _ui_i=0
    _ui_tries=0
    while [ "$_ui_i" -lt 34 ] && [ "$_ui_tries" -lt 400 ]; do
        _ui_tries=$((_ui_tries + 1))
        _ui_seed=$(((_ui_seed * 1103515245 + 12345) % 2147483648))
        _ui_sy=$((_ui_seed / 7 % UI_ROWS + 1))
        _ui_seed=$(((_ui_seed * 1103515245 + 12345) % 2147483648))
        _ui_sx=$((_ui_seed / 7 % (UI_COLS - 1) + 1))
        _ui_phase=$((_ui_seed / 13 % 7))
        # Keep the card and the bottom line clear.
        [ "$_ui_sy" -lt "$((UI_ROWS - 1))" ] || continue
        if [ "$_ui_sy" -ge "$((UI_CARD_TOP - 1))" ] && [ "$_ui_sy" -le "$((UI_CARD_BOTTOM + 1))" ] \
            && [ "$_ui_sx" -ge "$((UI_X - 2))" ] && [ "$_ui_sx" -le "$((UI_X + UI_W + 1))" ]; then
            continue
        fi
        _ui_stars="$_ui_stars$_ui_sy $_ui_sx $_ui_phase$UI_NL"
        _ui_i=$((_ui_i + 1))
    done
    _ui_frame=0
    while [ "$_ui_frame" -lt 16 ]; do
        UI_SPARKS=""
        while read -r _ui_sy _ui_sx _ui_phase; do
            [ -n "$_ui_sy" ] || continue
            _ui_t=$((_ui_frame - _ui_phase))
            if [ "$_ui_t" -lt 0 ] || [ "$_ui_t" -ge 9 ]; then continue; fi
            _ui_glow=$((_ui_t < 3 ? (_ui_t + 1) * 33 : (9 - _ui_t) * 16))
            case $_ui_t in 0 | 8) _ui_star="·" ;; 1 | 7) _ui_star="⋆" ;; 2 | 6) _ui_star="✧" ;; *) _ui_star="✦" ;; esac
            if [ $(((_ui_sx + _ui_sy) % 2)) = 0 ]; then _ui_col=$UI_ACC; else _ui_col=$UI_ACC2; fi
            ui_mix "$UI_MID" "$_ui_col" "$_ui_glow" 100
            ui_sgr 38 "$_ui_r" "$_ui_g" "$_ui_b"
            _ui_bg=""
            eval "_ui_bg=\$UI_BG_$_ui_sy"
            UI_SPARKS="$UI_SPARKS${UI_ESC}[$_ui_sy;${_ui_sx}H$_ui_bg$UI_C$_ui_star"
        done <<EOF
$_ui_stars
EOF
        ui_draw
        ui_nap 0.05
        _ui_frame=$((_ui_frame + 1))
    done
    UI_SPARKS=""
    ui_draw
    return 0
}

# The last lines of the log, without colours, as "log|..." lines, padded to a
# fixed height so the card doesn't jump as lines arrive.
ui_log_lines() {
    _ui_max=$((UI_ROWS - 17))
    [ "$_ui_max" -gt 10 ] && _ui_max=10
    [ "$_ui_max" -lt 3 ] && _ui_max=3
    _ui_got=$(tail -n 40 "$UI_LOG" 2>/dev/null | tr "$UI_CR" '\n' \
        | sed -e "s/$UI_ESC\[[0-9;?]*[A-Za-z]//g" -e 's/^ *//' -e '/^$/d' -e 's/|/¦/g' \
        | fold -s -w "$((UI_W - 4))" | sed -e 's/^ *//' -e '/^$/d' \
        | tail -n "$_ui_max" | sed -e 's/^/log|/')
    ui_lines "$_ui_got"
    printf '\nblank'
    [ -n "$_ui_got" ] && printf '\n%s' "$_ui_got"
    while [ "$_ui_cnt" -lt "$_ui_max" ]; do printf '\nblank'; _ui_cnt=$((_ui_cnt + 1)); done
    return 0
}

# ui_finish: fade out, leave the full-screen view and print what the last
# ui_run did, so it stays in the terminal's scrollback.
ui_finish() {
    # shellcheck disable=SC2031 # the job's own copy of UI_ACTIVE doesn't matter here
    if [ "$UI_ACTIVE" = 1 ] && [ "$UI_ANIM" = 1 ]; then
        ui_hide
        for _ui_lvl in 75 50 25 0; do
            ui_bg_level "$_ui_lvl" && ui_draw && ui_nap 0.025
        done
    fi
    ui_stop
    if [ -n "$UI_LOG" ] && [ -f "$UI_LOG" ]; then
        printf '\n'
        cat "$UI_LOG"
        rm -f "$UI_LOG"
        UI_LOG=""
    fi
    return 0
}
# <<< fullscreen ui <<<

# Bazzite purple, from Terminal Wrapped's "night" theme.
UI_THEME="21 27 92|4 5 29|157 140 255|255 122 224"
UI_BRAND="github.com/ethembeldagli/millennium-bazzite"

interactive() { [ "$yes" -eq 0 ] && [ -t 1 ] && ( : </dev/tty ) 2>/dev/null; }

# ask "question" default(y|n) -> returns 0 for yes
confirm() {
    if ! interactive; then
        [ "$2" = y ]
        return
    fi
    if [ "$2" = y ]; then hint="[Y/n]"; else hint="[y/N]"; fi
    printf '%s %s ' "$1" "$hint"
    read -r reply </dev/tty || reply=""
    case "$reply" in
        [Yy]*) return 0 ;;
        [Nn]*) return 1 ;;
        *) [ "$2" = y ] ;;
    esac
}

usage() {
    cat <<EOF
Millennium for Bazzite $INSTALLER_VERSION

Run with no options to pick what to do from a menu:
  $ONE_LINER
  millennium-bazzite        (once installed)

Options (all optional):
  --install         install or reinstall the latest Millennium
  --update          update if a newer Millennium is out
  --uninstall       remove Millennium (asks before deleting plugins/settings)
  --check           show what's installed and whether an update is out
  --game-mode       load Millennium in Game Mode too
  --desktop-only    load Millennium in Desktop Mode only (default)
  --auto-update-on  install new Millennium releases automatically (default)
  --auto-update-off check for new releases only when you run this
  --auto-update     check for updates now and install them quietly
                    (this is what the background timer runs)
  --beta            use Millennium beta releases
  --no-restart      don't restart Steam afterwards
  --yes             don't ask questions; use the defaults
  --from FILE       install from a downloaded millennium-*.tar.gz
  --help            show this help
EOF
}

# ---------------------------------------------------------------- paths

if [ -z "${HOME:-}" ] || [ "$HOME" = "/" ] || [ ! -d "$HOME" ]; then
    die "HOME isn't set to your home folder."
fi

LIB_DIR="$HOME/.local/lib/millennium"
VERSION_FILE="$LIB_DIR/.installed-by-millennium-bazzite"
ENV_DIR="$HOME/.config/environment.d"
ENV_FILE="$ENV_DIR/millennium.conf"
STEAM_DIR="$HOME/.steam/steam"
DATA_DIRS="$HOME/.config/millennium $HOME/.local/share/millennium $HOME/.local/state/millennium"

# Millennium and Decky Loader can't share one Steam session: Millennium deletes
# the file that turns on Steam's debugger, which Decky needs, and Decky blanks
# Millennium's settings page. So Decky gets Game Mode and Millennium gets
# Desktop Mode, using these two small switches.
CEF_FILE="$STEAM_DIR/.cef-enable-remote-debugging"
GAME_MODE_HOOK="$HOME/.config/gamescope-session-plus/sessions.d/steam"
DESKTOP_AUTOSTART="$HOME/.config/autostart/millennium-bazzite.desktop"
HOOK_START="# >>> Millennium for Bazzite >>>"
HOOK_END="# <<< Millennium for Bazzite <<<"

# The `millennium-bazzite` command and the timer that keeps Millennium updated.
CMD_PATH="$HOME/.local/bin/millennium-bazzite"
UNIT_DIR="$HOME/.config/systemd/user"
TIMER="millennium-bazzite-update.timer"
SERVICE="millennium-bazzite-update.service"

# ---------------------------------------------------------------- checks

in_container() {
    [ -f /run/.containerenv ] || [ -f /.dockerenv ] || [ -n "${CONTAINER_ID:-}" ]
}

preflight() {
    [ "$(id -u)" -ne 0 ] || die "Run this as your normal user, not with sudo."
    [ "$(uname -s)" = Linux ] || die "Millennium for Bazzite only runs on Linux."
    [ "$(uname -m)" = x86_64 ] || die "Millennium only supports x86_64 PCs (this is $(uname -m))."
    if in_container && [ -z "${MILLENNIUM_BAZZITE_ALLOW_CONTAINER:-}" ]; then
        die "You're inside a container (distrobox or toolbox). Run this in a normal host terminal."
    fi
    for tool in tar readlink; do
        command -v "$tool" >/dev/null 2>&1 || die "'$tool' is missing."
    done
    if [ -d /usr/lib/millennium ] && [ ! -L /usr/lib/millennium ] && [ ! -e /run/ostree-booted ]; then
        die "Millennium is already installed system-wide in /usr/lib/millennium (by your package manager or the official installer). Remove that one first, or keep using it."
    fi
}

# On Bazzite a copy in /usr can only come from unlocking /usr by hand. It is
# wiped by the next system update and isn't used once this install is in place.
note_unlocked_usr_copy() {
    if [ ! -e /run/ostree-booted ] || [ ! -d /usr/lib/millennium ]; then return 0; fi
    say "  ${D}Note: there's an old Millennium copy in /usr/lib/millennium (from unlocking /usr)."
    say "  It isn't used anymore and disappears with your next Bazzite update.${R}"
}

steam_ready() {
    if [ ! -x "$STEAM_DIR/ubuntu12_32/steam" ]; then
        if [ -d "$HOME/.var/app/com.valvesoftware.Steam" ]; then
            die "Only Flatpak Steam was found. Millennium needs the regular Steam that comes with Bazzite."
        fi
        die "Steam isn't set up yet. Open Steam once, sign in, then run this again."
    fi
}

# ---------------------------------------------------------------- versions

latest_version() {
    if [ -n "$from" ]; then
        name=$(basename "$from")
        name=${name#millennium-v}
        printf '%s\n' "${name%-linux-x86_64.tar.gz}"
        return
    fi
    command -v curl >/dev/null 2>&1 || return 0
    if [ "$beta" -eq 1 ]; then
        curl -fsSL -H 'Accept: application/vnd.github+json' \
            "https://api.github.com/repos/$UPSTREAM/releases?per_page=20" 2>/dev/null \
            | grep '"tag_name"' | head -n 1 | sed 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/'
    else
        url=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$UPSTREAM/releases/latest" 2>/dev/null) || return 0
        case "$url" in */tag/*) tag=${url##*/}; printf '%s\n' "${tag#v}" ;; esac
    fi
}

installed_version() {
    if [ -f "$VERSION_FILE" ]; then
        head -n 1 "$VERSION_FILE"
    elif [ -f "$LIB_DIR/libmillennium_x86.so" ]; then
        echo "unknown"
    fi
}

# text_before A B: does text A sort before text B?
text_before() {
    [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | LC_ALL=C sort | head -n 1)" = "$1" ]
}

# older A B: is version A older than version B? (3.6.2 < 3.6.3-beta.1 < 3.6.3)
older() {
    a=${1#v} b=${2#v}
    [ "$a" = "$b" ] && return 1
    [ "$a" = unknown ] && return 0
    a_pre="" b_pre=""
    case "$a" in *-*) a_pre=${a#*-} ;; esac
    case "$b" in *-*) b_pre=${b#*-} ;; esac
    rest_a="${a%%-*}." rest_b="${b%%-*}."
    while [ -n "$rest_a$rest_b" ]; do
        x=${rest_a%%.*} y=${rest_b%%.*}
        rest_a=${rest_a#*.} rest_b=${rest_b#*.}
        x=${x:-0} y=${y:-0}
        case "$x$y" in *[!0-9]*) text_before "$x" "$y"; return ;; esac
        [ "$x" -lt "$y" ] && return 0
        [ "$x" -gt "$y" ] && return 1
    done
    [ -n "$a_pre" ] && [ -z "$b_pre" ] && return 0
    [ -z "$a_pre" ] && return 1
    [ -n "$b_pre" ] && text_before "$a_pre" "$b_pre"
}

current_mode() {
    if [ -f "$ENV_FILE" ] && ! grep -q GAMESCOPE_MODE_SAVE_FILE "$ENV_FILE"; then
        echo both
    else
        echo desktop
    fi
}

# ---------------------------------------------------------------- Steam processes

real_lib_dir() { readlink -f "$LIB_DIR" 2>/dev/null || printf '%s\n' "$LIB_DIR"; }

steam_pids() {
    want=$(readlink -f "$STEAM_DIR/ubuntu12_32/steam" 2>/dev/null) || return 0
    for d in /proc/[0-9]*; do
        [ "$(readlink "$d/exe" 2>/dev/null)" = "$want" ] && printf '%s\n' "${d#/proc/}"
    done
}

steam_running() { [ -n "$(steam_pids)" ]; }

# The Millennium library Steam has loaded right now, wherever it came from.
loaded_millennium_path() {
    for pid in $(steam_pids); do
        found=$(grep -o '/[^ ]*/libmillennium_x86\.so' "/proc/$pid/maps" 2>/dev/null | head -n 1)
        [ -n "$found" ] && { printf '%s\n' "$found"; return 0; }
    done
    return 1
}

millennium_loaded() {
    [ "$(loaded_millennium_path)" = "$(real_lib_dir)/libmillennium_x86.so" ]
}

# process_named NAME: is a process with this name (as in /proc/PID/comm) running?
process_named() {
    for d in /proc/[0-9]*; do
        { read -r name <"$d/comm"; } 2>/dev/null && [ "$name" = "$1" ] && return 0
    done
    return 1
}

# Steam starts every game through its "reaper" process.
game_running() { process_named reaper; }

in_game_mode() {
    [ "${XDG_CURRENT_DESKTOP:-}" = gamescope ] || process_named gamescope-sessi
}

steam_launch_command() {
    for f in "$HOME/.local/share/applications/steam.desktop" /usr/share/applications/steam.desktop; do
        [ -f "$f" ] || continue
        line=$(grep -m 1 '^Exec=' "$f") || continue
        line=${line#Exec=}
        printf '%s\n' "$line" | sed 's/ *%[a-zA-Z]//g'
        return
    done
    command -v steam >/dev/null 2>&1 && echo steam
}

stop_steam() {
    steam_running || return 0
    step "Closing Steam..."
    if command -v steam >/dev/null 2>&1; then
        steam -shutdown >/dev/null 2>&1 </dev/null &
    else
        for pid in $(steam_pids); do kill "$pid" 2>/dev/null; done
    fi
    i=0
    while steam_running; do
        i=$((i + 1))
        [ "$i" -gt 60 ] && return 1
        sleep 1
    done
}

# start_steam [with-millennium]
start_steam() {
    cmd=$(steam_launch_command)
    [ -n "$cmd" ] || return 1
    step "Starting Steam..."
    if [ "${1:-}" = with-millennium ] && [ "$(current_mode)" = desktop ]; then
        rm -f "$CEF_FILE"
    fi
    if [ "${1:-}" = with-millennium ]; then
        MILLENNIUM_RUNTIME_PATH="$LIB_DIR/libmillennium_x86.so"
        export MILLENNIUM_RUNTIME_PATH
    else
        unset MILLENNIUM_RUNTIME_PATH
    fi
    if command -v setsid >/dev/null 2>&1; then
        (cd "$HOME" && setsid sh -c "$cmd" </dev/null >/dev/null 2>&1 &)
    else
        (cd "$HOME" && nohup sh -c "$cmd" </dev/null >/dev/null 2>&1 &)
    fi
}

wait_for_millennium() {
    i=0
    while [ "$i" -lt 120 ]; do
        if millennium_loaded; then
            [ -t 1 ] && printf '\r\033[K'
            return 0
        fi
        if [ -t 1 ]; then
            case $((i % 4)) in 0) f="⠋" ;; 1) f="⠙" ;; 2) f="⠸" ;; *) f="⠴" ;; esac
            printf '\r%s%s%s Waiting for Millennium to load... %ss %s(Steam may update itself first)%s' \
                "$CYN" "$f" "$R" "$i" "$D" "$R"
        fi
        i=$((i + 1))
        sleep 1
    done
    [ -t 1 ] && printf '\r\033[K'
    return 1
}

# restart_steam with-millennium|without
restart_steam() {
    [ "$restart" = no ] && return 2
    if in_container; then
        return 2
    fi
    if in_game_mode; then
        say "You're in Game Mode. Switch to Desktop Mode to use Millennium."
        return 2
    fi
    if game_running; then
        warn "A game is running, so Steam wasn't restarted. Restart Steam when you're done playing."
        return 2
    fi
    if steam_running; then
        confirm "Restart Steam now?" y || return 2
        stop_steam || { warn "Steam didn't close. Restart it yourself."; return 2; }
    else
        confirm "Start Steam now?" y || return 2
    fi
    start_steam "$1" || { warn "Couldn't find how to start Steam. Start it yourself."; return 2; }
}

# ---------------------------------------------------------------- install

decky_installed() { [ -e "$HOME/homebrew/services/PluginLoader" ]; }

remove_game_mode_hook() {
    if [ ! -f "$GAME_MODE_HOOK" ] || ! grep -qF "$HOOK_START" "$GAME_MODE_HOOK"; then return 0; fi
    sed "/^$HOOK_START\$/,/^$HOOK_END\$/d" "$GAME_MODE_HOOK" >"$GAME_MODE_HOOK.tmp" && mv "$GAME_MODE_HOOK.tmp" "$GAME_MODE_HOOK"
    grep -q '[^[:space:]]' "$GAME_MODE_HOOK" || rm -f "$GAME_MODE_HOOK"
}

# split_with_decky desktop|both: in Desktop-only mode, turn Steam's debugger
# back on for Decky when Game Mode starts, and off again at desktop login.
split_with_decky() {
    remove_game_mode_hook
    rm -f "$DESKTOP_AUTOSTART"
    [ "$1" = desktop ] || return 0

    mkdir -p "$(dirname "$GAME_MODE_HOOK")" "$(dirname "$DESKTOP_AUTOSTART")"
    # shellcheck disable=SC2016 # $HOME is meant to expand when Game Mode reads the hook
    {
        echo "$HOOK_START"
        echo "# Millennium switches off Steam's debugger in Desktop Mode. Decky needs it,"
        echo "# so switch it back on before Steam starts in Game Mode."
        echo 'if [ -e "$HOME/homebrew/services/PluginLoader" ]; then'
        echo '    touch "$HOME/.steam/steam/.cef-enable-remote-debugging"'
        echo 'fi'
        echo "$HOOK_END"
    } >>"$GAME_MODE_HOOK"
    {
        echo "[Desktop Entry]"
        echo "Type=Application"
        echo "Name=Millennium for Bazzite"
        echo "Comment=Keeps Decky Loader out of Desktop Mode so Millennium can load"
        echo "Exec=rm -f \"$CEF_FILE\""
        echo "NoDisplay=true"
        echo "X-GNOME-Autostart-enabled=true"
    } >"$DESKTOP_AUTOSTART"
}

write_env_file() {
    mkdir -p "$ENV_DIR"
    runtime="$LIB_DIR/libmillennium_x86.so"
    {
        echo "# Millennium (Steam themes and plugins), set up by Millennium for Bazzite."
        echo "# Update or remove it by running:"
        echo "#   $ONE_LINER"
        if [ "$1" = desktop ]; then
            echo "#"
            echo "# Desktop Mode only: Game Mode reads this file again after setting"
            echo "# GAMESCOPE_MODE_SAVE_FILE, which turns the path below into one that"
            echo "# doesn't exist, so Steam starts without Millennium there."
            echo "MILLENNIUM_RUNTIME_PATH=\${GAMESCOPE_MODE_SAVE_FILE:+/millennium-is-off-in-game-mode}\${GAMESCOPE_MODE_SAVE_FILE:-$runtime}"
        else
            echo "MILLENNIUM_RUNTIME_PATH=$runtime"
        fi
    } >"$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"
}

link() {
    if [ -e "$2" ] && [ ! -L "$2" ]; then
        mv "$2" "$2.millennium-bazzite.bak"
    fi
    ln -sfn "$1" "$2"
}

link_steam() {
    mkdir -p "$STEAM_DIR/ubuntu12_32" "$STEAM_DIR/ubuntu12_64"
    link "$LIB_DIR/libmillennium_bootstrap_x86.so" "$STEAM_DIR/ubuntu12_32/libXtst.so.6"
    link "$LIB_DIR/libmillennium_bootstrap_hhx64.so" "$STEAM_DIR/ubuntu12_64/libXtst.so.6"
    link "$LIB_DIR/libmillennium_hhx64.so" "$STEAM_DIR/ubuntu12_64/libmillennium_hhx64.so"
}

check_steam_beta() {
    beta_file="$STEAM_DIR/package/beta"
    [ -f "$beta_file" ] || return 0
    branch=$(head -n 1 "$beta_file" 2>/dev/null)
    warn "Steam is on the beta branch '${branch:-unknown}'. Millennium often doesn't load on Steam betas."
    if interactive && confirm "Switch Steam back to the stable branch?" y; then
        rm -f "$beta_file"
        ok "Steam will use the stable branch from its next start."
    else
        say "  To switch back: Steam → Settings → Interface → Client Beta Participation → No beta chosen."
    fi
}

# Settings left by older community install scripts would override ours.
remove_old_env_files() {
    for f in "$ENV_DIR"/*.conf; do
        if [ ! -f "$f" ] || [ "$f" = "$ENV_FILE" ]; then continue; fi
        grep -q '^ *MILLENNIUM' "$f" 2>/dev/null || continue
        name="${f#"$HOME"/}"
        if interactive && ! confirm "Remove old Millennium settings in ~/$name? They override this install." y; then
            warn "Kept ~/$name. Millennium may not load until you remove it."
        else
            rm -f "$f"
            ok "Removed old Millennium settings in ~/$name."
        fi
    done
}

# ---------------------------------------------------------------- command and auto-update

# script_version FILE: the INSTALLER_VERSION inside a copy of this script.
script_version() {
    sed -n 's/^INSTALLER_VERSION="\([^"]*\)"$/\1/p' "$1" 2>/dev/null | head -n 1
}

running_as_command() {
    [ -f "$0" ] && [ "$(readlink -f "$0" 2>/dev/null)" = "$(readlink -f "$CMD_PATH" 2>/dev/null)" ]
}

# fetch_self FILE: download the latest version of this script.
fetch_self() {
    command -v curl >/dev/null 2>&1 || return 1
    curl -fsSL --retry 2 -o "$1" "$SELF_URL" 2>/dev/null || return 1
    [ -n "$(script_version "$1")" ] && sh -n "$1" 2>/dev/null
}

# install_command: put this script at ~/.local/bin/millennium-bazzite.
install_command() {
    running_as_command && return 0
    mkdir -p "$(dirname "$CMD_PATH")"
    if [ -f "$0" ] && [ -n "$(script_version "$0")" ]; then
        cp "$0" "$CMD_PATH.new" || return 1
    else
        fetch_self "$CMD_PATH.new" || { rm -f "$CMD_PATH.new"; return 1; }
    fi
    chmod 755 "$CMD_PATH.new" && mv "$CMD_PATH.new" "$CMD_PATH"
}

# self_update ARGS...: replace the installed command with a newer version from
# GitHub, then run the new one with the same arguments.
self_update() {
    [ -z "${MILLENNIUM_BAZZITE_SELF_UPDATED:-}" ] || return 0
    new="$CMD_PATH.download"
    fetch_self "$new" || { rm -f "$new"; return 0; }
    new_version=$(script_version "$new")
    if older "$INSTALLER_VERSION" "$new_version"; then
        chmod 755 "$new" && mv "$new" "$CMD_PATH" || return 0
        say "Updated Millennium for Bazzite $INSTALLER_VERSION → $new_version."
        MILLENNIUM_BAZZITE_SELF_UPDATED=1
        export MILLENNIUM_BAZZITE_SELF_UPDATED
        exec sh "$CMD_PATH" "$@"
    fi
    rm -f "$new"
}

# A newer script run through curl refreshes an older installed command.
refresh_command() {
    running_as_command && return 0
    if [ ! -f "$CMD_PATH" ]; then
        # Installed by version 1.0, which had no command or automatic updates.
        if install_command && ! auto_update_enabled; then
            enable_auto_update
            ok "Automatic updates are now on. Run millennium-bazzite to change that."
        fi
        return 0
    fi
    old_cmd=$(script_version "$CMD_PATH")
    if [ -z "$old_cmd" ] || older "$old_cmd" "$INSTALLER_VERSION"; then
        install_command
    fi
}

remove_command() {
    if [ -f "$CMD_PATH" ] && [ -n "$(script_version "$CMD_PATH")" ]; then
        rm -f "$CMD_PATH"
    fi
}

use_systemctl() {
    [ -z "${MILLENNIUM_BAZZITE_NO_SYSTEMCTL:-}" ] && command -v systemctl >/dev/null 2>&1 \
        && systemctl --user show-environment >/dev/null 2>&1
}

auto_update_enabled() { [ -L "$UNIT_DIR/timers.target.wants/$TIMER" ] && [ -f "$UNIT_DIR/$TIMER" ]; }

enable_auto_update() {
    mkdir -p "$UNIT_DIR/timers.target.wants"
    {
        echo "[Unit]"
        echo "Description=Install new Millennium releases (Millennium for Bazzite)"
        echo ""
        echo "[Service]"
        echo "Type=oneshot"
        echo "ExecStart=/bin/sh %h/.local/bin/millennium-bazzite --auto-update"
        echo "Nice=10"
    } >"$UNIT_DIR/$SERVICE"
    {
        echo "[Unit]"
        echo "Description=Check for Millennium updates (Millennium for Bazzite)"
        echo ""
        echo "[Timer]"
        echo "OnStartupSec=2min"
        echo "OnUnitActiveSec=6h"
        echo "RandomizedDelaySec=10min"
        echo ""
        echo "[Install]"
        echo "WantedBy=timers.target"
    } >"$UNIT_DIR/$TIMER"
    ln -sfn "../$TIMER" "$UNIT_DIR/timers.target.wants/$TIMER"
    if use_systemctl; then
        systemctl --user daemon-reload >/dev/null 2>&1
        systemctl --user start "$TIMER" >/dev/null 2>&1
    fi
}

disable_auto_update() {
    if use_systemctl; then
        systemctl --user stop "$TIMER" >/dev/null 2>&1
    fi
    rm -f "$UNIT_DIR/timers.target.wants/$TIMER" "$UNIT_DIR/$TIMER" "$UNIT_DIR/$SERVICE"
    rmdir "$UNIT_DIR/timers.target.wants" 2>/dev/null
    if use_systemctl; then
        systemctl --user daemon-reload >/dev/null 2>&1
    fi
}

# notify TITLE BODY: a desktop notification, if one can be shown.
notify() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -a "Millennium for Bazzite" -i steam "$1" "$2" >/dev/null 2>&1 || true
}

# Steam updates can remove the links that load Millennium; put them back.
self_heal() {
    healed=0
    for pair in "ubuntu12_32/libXtst.so.6:libmillennium_bootstrap_x86.so" \
                "ubuntu12_64/libXtst.so.6:libmillennium_bootstrap_hhx64.so" \
                "ubuntu12_64/libmillennium_hhx64.so:libmillennium_hhx64.so"; do
        l="$STEAM_DIR/${pair%%:*}"
        [ "$(readlink "$l" 2>/dev/null)" = "$LIB_DIR/${pair#*:}" ] || healed=1
    done
    [ -f "$ENV_FILE" ] || healed=1
    [ "$healed" -eq 1 ] || return 0
    link_steam
    [ -f "$ENV_FILE" ] || write_env_file "$(current_mode)"
    say "Put back the links that load Millennium into Steam."
}

do_auto_update() {
    old=$(installed_version)
    if [ -z "$old" ]; then
        say "Millennium isn't installed, nothing to update."
        return 0
    fi
    [ -d "$STEAM_DIR/ubuntu12_32" ] && self_heal
    latest=$(latest_version)
    if [ -z "$latest" ]; then
        say "Couldn't reach GitHub, will try again later."
        return 0
    fi
    if ! older "$old" "$latest"; then
        say "Millennium $old is up to date."
        return 0
    fi
    yes=1
    restart=no
    do_install
    if steam_running; then
        notify "Millennium $latest is ready" "Restart Steam to start using it."
    fi
}

sha256_ok() {
    if command -v sha256sum >/dev/null 2>&1; then
        (cd "$1" && sha256sum -c "$2" >/dev/null 2>&1)
    elif command -v shasum >/dev/null 2>&1; then
        (cd "$1" && shasum -a 256 -c "$2" >/dev/null 2>&1)
    else
        warn "No sha256sum found, so the download wasn't verified."
    fi
}

download() {
    if interactive; then
        curl -fL --retry 2 --progress-bar -o "$2" "$1"
    else
        curl -fsSL --retry 2 -o "$2" "$1"
    fi
}

do_install() {
    steam_ready
    if [ -z "$from" ] && ! command -v curl >/dev/null 2>&1; then
        die "'curl' is missing, so Millennium can't be downloaded."
    fi
    version=$(latest_version)
    [ -n "$version" ] || die "Couldn't find the latest Millennium release. Are you online?"
    old=$(installed_version)

    if [ -z "$game_mode" ]; then
        if [ -n "$old" ]; then
            game_mode=$(current_mode)
        elif decky_installed && confirm "Load Millennium in Game Mode too? Decky stops working there if you do." n; then
            game_mode=both
        elif ! decky_installed && confirm "Load Millennium in Game Mode too?" n; then
            game_mode=both
        else
            game_mode=desktop
        fi
    fi

    tmp=$(mktemp -d "${TMPDIR:-/tmp}/millennium-bazzite.XXXXXX") || die "Couldn't create a temporary folder."
    trap '[ -n "${tmp:-}" ] && rm -rf "$tmp"' EXIT
    trap 'exit 130' INT TERM
    tarball="millennium-v$version-linux-x86_64.tar.gz"

    if [ -n "$from" ]; then
        [ -f "$from" ] || die "$from doesn't exist."
        cp "$from" "$tmp/$tarball"
        if [ -f "$from.sha256" ]; then
            cp "$from.sha256" "$tmp/$tarball.sha256"
        elif [ -f "${from%.tar.gz}.sha256" ]; then
            cp "${from%.tar.gz}.sha256" "$tmp/$tarball.sha256"
        fi
    else
        base="https://github.com/$UPSTREAM/releases/download/v$version"
        step "Downloading Millennium $version..."
        download "$base/$tarball" "$tmp/$tarball" || die "Download failed."
        curl -fsSL -o "$tmp/$tarball.sha256" "$base/millennium-v$version-linux-x86_64.sha256" \
            || die "Couldn't download the checksum, so the download can't be verified."
    fi
    if [ -f "$tmp/$tarball.sha256" ]; then
        step "Verifying checksum..."
        sha256_ok "$tmp" "$tarball.sha256" || die "The download doesn't match its checksum. Try again."
    fi

    mkdir "$tmp/x"
    tar xzf "$tmp/$tarball" -C "$tmp/x" || die "Couldn't unpack $tarball."
    src="$tmp/x/usr/lib/millennium"
    if [ ! -f "$src/libmillennium_x86.so" ] || [ ! -f "$src/libmillennium_bootstrap_x86.so" ]; then
        die "Millennium $version has files this installer doesn't know. Please open an issue."
    fi
    extra=$(tar tzf "$tmp/$tarball" | grep -v '/$' | grep -v '^\(\./\)\{0,1\}usr/lib/millennium/' | head -n 1)
    [ -z "$extra" ] || die "Millennium $version now ships files outside /usr/lib (like ${extra#./}). This installer needs an update for that; please open an issue."

    step "Installing to ~/${LIB_DIR#"$HOME"/}..."
    mkdir -p "$(dirname "$LIB_DIR")"
    rm -rf "$LIB_DIR.new" "$LIB_DIR.old"
    cp -R "$src" "$LIB_DIR.new" || die "Couldn't copy files into $LIB_DIR."
    chmod 755 "$LIB_DIR.new"/*
    printf '%s\n' "$version" >"$LIB_DIR.new/.installed-by-millennium-bazzite"
    if [ -d "$LIB_DIR" ]; then
        mv "$LIB_DIR" "$LIB_DIR.old"
    fi
    mv "$LIB_DIR.new" "$LIB_DIR"
    rm -rf "$LIB_DIR.old"

    link_steam
    write_env_file "$game_mode"
    split_with_decky "$game_mode"
    remove_old_env_files
    check_steam_beta

    # New installs get automatic updates; updates keep what was chosen before.
    if [ "$auto_choice" = off ]; then
        disable_auto_update
    elif [ "$auto_choice" = on ] || [ -z "$old" ] || auto_update_enabled; then
        if install_command; then
            enable_auto_update
        else
            warn "Couldn't install the millennium-bazzite command, so automatic updates are off."
        fi
    else
        install_command || true
    fi

    if [ "$old" = unknown ]; then
        ok "Installed Millennium $version (replaced an older copy)."
    elif [ "$old" = "$version" ]; then
        ok "Reinstalled Millennium $version."
    elif [ -n "$old" ] && [ "$old" != "$version" ]; then
        ok "Updated Millennium $old → $version."
    else
        ok "Installed Millennium $version."
    fi
    if [ "$game_mode" = desktop ]; then
        say "  It loads in Desktop Mode. Game Mode stays stock."
        decky_installed && say "  Decky keeps working in Game Mode (it's switched off in Desktop Mode, where it clashes with Millennium)."
    else
        say "  It loads in Desktop Mode and Game Mode."
        decky_installed && warn "Decky Loader won't work in Game Mode while Millennium loads there."
    fi
    if auto_update_enabled; then
        say "  New Millennium releases install automatically (checked every 6 hours)."
    fi
    note_unlocked_usr_copy

    restart_steam with-millennium
    case $? in
        0)
            [ -t 1 ] || step "Waiting for Millennium to load (Steam may update itself first)..."
            if wait_for_millennium; then
                ok "Millennium is running. Open it from the Steam menu (top left) → Millennium."
                say "  Log out and back in once, so it also loads when you open Steam yourself."
            else
                warn "Steam started, but Millennium hasn't loaded yet. If it doesn't show up, log out and back in."
            fi
            ;;
        *)
            if millennium_loaded; then
                say "  Restart Steam to load the new version."
            else
                say "  Restart Steam (or log out and back in) and Millennium will load."
            fi
            ;;
    esac
    say "  ${D}From your next login it loads automatically. Run ${R}millennium-bazzite${D} to change settings or remove it.${R}"
}

# ---------------------------------------------------------------- update / check

do_check() {
    old=$(installed_version)
    latest=$(latest_version)
    if [ -z "$old" ]; then
        say "Millennium isn't installed. Latest: ${latest:-unknown}."
        return 0
    fi
    mode=$(current_mode)
    if [ "$mode" = desktop ]; then mode="Desktop Mode only"; else mode="Desktop Mode and Game Mode"; fi
    say "Installed: Millennium $old ($mode)"
    loaded=$(loaded_millennium_path)
    if millennium_loaded; then
        say "Running:   yes, Steam has it loaded"
    elif [ -n "$loaded" ]; then
        say "Running:   an older copy from ${loaded%/*}. Log out and back in to switch."
    elif steam_running; then
        say "Running:   no. Log out and back in, or run this again and restart Steam."
    fi
    if [ -z "$latest" ]; then
        say "Latest:    couldn't check (offline?)"
    elif older "$old" "$latest"; then
        say "Latest:    ${B}$latest${R} — update available"
    else
        say "Latest:    $latest (up to date)"
    fi
    if auto_update_enabled; then
        say "Updates:   automatic, checked every 6 hours"
    else
        say "Updates:   manual, run millennium-bazzite to update"
    fi
}

do_update() {
    old=$(installed_version)
    [ -n "$old" ] || { say "Millennium isn't installed yet, so installing it."; do_install; return; }
    latest=$(latest_version)
    [ -n "$latest" ] || die "Couldn't check for updates. Are you online?"
    if older "$old" "$latest"; then
        do_install
    else
        ok "Millennium $old is up to date."
    fi
}

do_set_mode() {
    write_env_file "$1"
    split_with_decky "$1"
    if [ "$1" = desktop ]; then
        ok "Millennium now loads in Desktop Mode only."
    else
        ok "Millennium now loads in Desktop Mode and Game Mode."
        decky_installed && warn "Decky Loader won't work in Game Mode while Millennium loads there."
    fi
    say "  The change applies from your next login or switch to Game Mode."
}

do_set_auto_update() {
    if [ "$1" = on ]; then
        install_command || die "Couldn't install the millennium-bazzite command."
        enable_auto_update
        ok "Automatic updates are on. New Millennium releases install by themselves."
    else
        disable_auto_update
        ok "Automatic updates are off. Run millennium-bazzite to update."
    fi
}

# ---------------------------------------------------------------- uninstall

unlink_steam() {
    real=$(real_lib_dir)
    for l in "$STEAM_DIR/ubuntu12_32/libXtst.so.6" "$STEAM_DIR/ubuntu12_64/libXtst.so.6" \
             "$STEAM_DIR/ubuntu12_64/libmillennium_hhx64.so"; do
        [ -L "$l" ] || continue
        target=$(readlink "$l")
        case "$target" in
            "$LIB_DIR"/*|"$real"/*|*/millennium/libmillennium_*) rm -f "$l" ;;
            *) continue ;;
        esac
        [ -e "$l.millennium-bazzite.bak" ] && mv "$l.millennium-bazzite.bak" "$l"
    done
}

do_uninstall() {
    old=$(installed_version)
    if [ -z "$old" ] && [ ! -f "$ENV_FILE" ] && [ ! -L "$STEAM_DIR/ubuntu12_32/libXtst.so.6" ]; then
        say "Millennium isn't installed."
        return 0
    fi
    was_loaded=0
    millennium_loaded && was_loaded=1

    unlink_steam
    if [ -f "$ENV_FILE" ] && grep -q MILLENNIUM "$ENV_FILE"; then
        rm -f "$ENV_FILE"
    fi
    split_with_decky none
    disable_auto_update
    remove_command
    # Give Decky back the debugger file that Millennium deleted.
    decky_installed && touch "$CEF_FILE"
    rm -rf "$LIB_DIR" "$LIB_DIR.new" "$LIB_DIR.old"
    ok "Removed Millennium${old:+ $old}."

    kept=""
    for d in $DATA_DIRS; do [ -d "$d" ] && kept="$kept $d"; done
    if [ -n "$kept" ]; then
        if [ "$delete_data" = yes ] || { [ -z "$delete_data" ] && confirm "Also delete your Millennium plugins, settings and logs?" n; }; then
            for d in $kept; do rm -rf "$d"; done
            ok "Deleted plugins, settings and logs."
        else
            say "  Kept your plugins and settings in case you reinstall:"
            for d in $kept; do say "    ${d#"$HOME"/}"; done
        fi
    fi

    if [ "$was_loaded" -eq 1 ]; then
        restart_steam without || say "  Restart Steam to unload it."
    fi
}

# ---------------------------------------------------------------- menu

menu() {
    old=$(installed_version)
    latest=$(latest_version)
    banner

    if [ -z "$old" ]; then
        row "Millennium" "not installed"
        row "Latest" "${latest:-unknown (offline?)}"
        decky_installed && row "Decky" "found, it keeps working in Game Mode"
        say ""
        say "  ${B}[i]${R} Install"
        say "  ${B}[q]${R} Quit"
        default=i
    else
        mode=$(current_mode)
        if [ -z "$latest" ]; then
            row "Millennium" "$old ${D}(couldn't check for updates)${R}"
        elif older "$old" "$latest"; then
            row "Millennium" "$old ${YLW}→ $latest available${R}"
        else
            row "Millennium" "$old ${GRN}✓ up to date${R}"
        fi
        if [ "$mode" = desktop ]; then
            row "Loads in" "Desktop Mode ${D}(Game Mode stays stock)${R}"
        else
            row "Loads in" "Desktop Mode and Game Mode"
        fi
        if auto_update_enabled; then
            row "Updates" "${GRN}automatic${R} ${D}(every 6 hours)${R}"
        else
            row "Updates" "manual"
        fi
        loaded=$(loaded_millennium_path)
        if millennium_loaded; then
            row "Steam" "${GRN}running with Millennium${R}"
        elif [ -n "$loaded" ]; then
            row "Steam" "${YLW}running an older copy, log out and back in${R}"
        elif steam_running; then
            row "Steam" "${YLW}running without it, log out and back in${R}"
        else
            row "Steam" "not running"
        fi
        say ""
        default=q
        if [ -n "$latest" ] && older "$old" "$latest"; then
            say "  ${B}[u]${R} Update to $latest"
            default=u
        fi
        if auto_update_enabled; then
            say "  ${B}[a]${R} Turn automatic updates off"
        else
            say "  ${B}[a]${R} Turn automatic updates on"
        fi
        if [ "$mode" = desktop ]; then
            if decky_installed; then
                say "  ${B}[g]${R} Also load it in Game Mode ${D}(turns Decky off there)${R}"
            else
                say "  ${B}[g]${R} Also load it in Game Mode"
            fi
        else
            say "  ${B}[g]${R} Load it in Desktop Mode only"
        fi
        say "  ${B}[r]${R} Reinstall"
        say "  ${B}[d]${R} Delete"
        say "  ${B}[q]${R} Quit"
    fi
    say ""
    printf 'Choose [%s]: ' "$default"
    read -r choice </dev/tty || choice=""
    choice=${choice:-$default}
    say ""
    case "$choice" in
        [Ii]*|[Rr]*) do_install ;;
        [Uu]*) do_update ;;
        [Aa]*)
            if [ -z "$old" ]; then
                say "Nothing changed."
            elif auto_update_enabled; then
                do_set_auto_update off
            else
                do_set_auto_update on
            fi
            ;;
        [Gg]*)
            if [ -z "$old" ]; then
                say "Nothing changed."
            elif [ "$(current_mode)" = desktop ]; then
                do_set_mode both
            else
                do_set_mode desktop
            fi
            ;;
        [Dd]*)
            if [ -z "$old" ]; then
                say "Nothing changed."
            elif confirm "Delete Millennium?" n; then
                do_uninstall
            else
                say "Nothing changed."
            fi
            ;;
        *) say "Nothing changed." ;;
    esac
}

# The same menu, full screen and in colour, when the terminal can show it.
fullscreen_menu() {
    ui_start
    UI_TITLE="Millennium for Bazzite" UI_RIGHT="v$INSTALLER_VERSION"
    UI_SUB="Steam themes and plugins · no root · survives updates"
    ui_busy "Checking for updates"
    old=$(installed_version)
    latest=$(latest_version)

    if [ -z "$old" ]; then
        UI_LINES="info|Millennium|not installed yet|dim
info|Latest|${latest:-unknown (offline?)}|"
        if decky_installed; then
            UI_LINES="$UI_LINES${UI_NL}info|Decky|found, keeps working in Game Mode|good"
        fi
        UI_OPTS="i|Install Millennium${latest:+ $latest}|${UI_NL}q|Quit|"
    else
        if [ -z "$latest" ]; then
            UI_LINES="info|Millennium|$old  (couldn't check for updates)|"
        elif older "$old" "$latest"; then
            UI_LINES="info|Millennium|$old  → $latest available|warn"
        else
            UI_LINES="info|Millennium|$old  ✓ up to date|good"
        fi
        if [ "$(current_mode)" = desktop ]; then
            UI_LINES="$UI_LINES${UI_NL}info|Loads in|Desktop Mode (Game Mode stays stock)|"
        else
            UI_LINES="$UI_LINES${UI_NL}info|Loads in|Desktop Mode and Game Mode|"
        fi
        if auto_update_enabled; then
            UI_LINES="$UI_LINES${UI_NL}info|Updates|automatic, every 6 hours|good"
        else
            UI_LINES="$UI_LINES${UI_NL}info|Updates|manual|dim"
        fi
        if millennium_loaded; then
            UI_LINES="$UI_LINES${UI_NL}info|Steam|running with Millennium|good"
        elif [ -n "$(loaded_millennium_path)" ]; then
            UI_LINES="$UI_LINES${UI_NL}info|Steam|running an older copy, log out and back in|warn"
        elif steam_running; then
            UI_LINES="$UI_LINES${UI_NL}info|Steam|running without it, log out and back in|warn"
        else
            UI_LINES="$UI_LINES${UI_NL}info|Steam|not running|dim"
        fi
        UI_OPTS=""
        if [ -n "$latest" ] && older "$old" "$latest"; then
            UI_OPTS="u|Update to $latest|$UI_NL"
        fi
        if auto_update_enabled; then
            UI_OPTS="${UI_OPTS}a|Turn automatic updates off|$UI_NL"
        else
            UI_OPTS="${UI_OPTS}a|Turn automatic updates on|$UI_NL"
        fi
        if [ "$(current_mode)" = both ]; then
            UI_OPTS="${UI_OPTS}g|Load it in Desktop Mode only|$UI_NL"
        elif decky_installed; then
            UI_OPTS="${UI_OPTS}g|Also load it in Game Mode|(turns Decky off there)$UI_NL"
        else
            UI_OPTS="${UI_OPTS}g|Also load it in Game Mode|$UI_NL"
        fi
        UI_OPTS="${UI_OPTS}r|Reinstall|${UI_NL}d|Delete|${UI_NL}q|Quit|"
    fi

    UI_SEL=1
    if [ -n "$old" ] && ! { [ -n "$latest" ] && older "$old" "$latest"; }; then
        UI_SEL=$(printf '%s\n' "$UI_OPTS" | grep -c '')
    fi
    ui_choose
    status=0
    case "$UI_CHOICE" in
        i | r)
            if [ -z "$old" ] && [ -z "$game_mode" ]; then
                if decky_installed; then
                    detail="Decky stops working in Game Mode if you do. Most people say no."
                else
                    detail="Themes are made for the desktop client; Game Mode works either way."
                fi
                if ui_ask "Load Millennium in Game Mode too?" "$detail" n; then game_mode=both; else game_mode=desktop; fi
            fi
            if [ -z "$old" ]; then title="Installing Millennium${latest:+ $latest}"; else title="Reinstalling Millennium"; fi
            ui_run "$title" do_install || status=$?
            ;;
        u) ui_run "Updating Millennium to $latest" do_update || status=$? ;;
        a)
            if auto_update_enabled; then
                ui_run "Turning automatic updates off" do_set_auto_update off || status=$?
            else
                ui_run "Turning automatic updates on" do_set_auto_update on || status=$?
            fi
            ;;
        g)
            if [ "$(current_mode)" = desktop ]; then
                ui_run "Loading Millennium in Game Mode too" do_set_mode both || status=$?
            else
                ui_run "Loading Millennium in Desktop Mode only" do_set_mode desktop || status=$?
            fi
            ;;
        d)
            if ui_ask "Delete Millennium?" "Steam goes back to normal, and Decky gets back what Millennium took." n; then
                delete_data=no
                for d in $DATA_DIRS; do
                    if [ -d "$d" ]; then
                        if ui_ask "Also delete your plugins and settings?" "Keep them if you might come back." n; then delete_data=yes; fi
                        break
                    fi
                done
                ui_run "Removing Millennium" do_uninstall || status=$?
            fi
            ;;
    esac
    if [ -z "$UI_LOG" ]; then
        ui_finish
        say "Nothing changed."
    else
        ui_finish
    fi
    return "$status"
}

# ---------------------------------------------------------------- main

main() {
    all_args="$*"
    while [ $# -gt 0 ]; do
        case "$1" in
            --install|install) action=install ;;
            --update|update|--upgrade) action=update ;;
            --uninstall|uninstall|--remove|--delete) action=uninstall ;;
            --check|check|--status) action=check ;;
            --auto-update) action=auto ;;
            --auto-update-on) auto_choice=on ;;
            --auto-update-off) auto_choice=off ;;
            --game-mode) game_mode=both ;;
            --desktop-only) game_mode=desktop ;;
            --beta) beta=1 ;;
            --no-restart) restart=no ;;
            --yes|-y) yes=1 ;;
            --from) shift; from=${1:-} ;;
            --from=*) from=${1#*=} ;;
            --version) say "$INSTALLER_VERSION"; exit 0 ;;
            -h|--help) usage; exit 0 ;;
            *) usage >&2; die "Unknown option: $1" ;;
        esac
        shift
    done

    preflight

    # The installed command keeps itself up to date; a newer script run through
    # curl refreshes an older installed command.
    if running_as_command && [ "$action" != uninstall ]; then
        # shellcheck disable=SC2086 # the original arguments, split again on purpose
        self_update $all_args
    elif [ -n "$(installed_version)" ]; then
        refresh_command
    fi

    if [ -z "$action" ] && [ -n "$(installed_version)" ] && { [ -n "$game_mode" ] || [ -n "$auto_choice" ]; }; then
        [ -n "$game_mode" ] && do_set_mode "$game_mode"
        [ -n "$auto_choice" ] && do_set_auto_update "$auto_choice"
        return 0
    fi
    case "$action" in
        install) do_install ;;
        update) do_update ;;
        uninstall) do_uninstall ;;
        check) do_check ;;
        auto) do_auto_update ;;
        *)
            if interactive && ui_supported; then
                fullscreen_menu
            elif interactive; then
                menu
            elif [ -n "$(installed_version)" ]; then
                do_update
            else
                do_install
            fi
            ;;
    esac
}

# Tests source this file with MILLENNIUM_BAZZITE_TEST=1 to call single functions.
[ -n "${MILLENNIUM_BAZZITE_TEST:-}" ] || main "$@"
