#!/bin/sh
# Millennium for Bazzite
#
# Installs Millennium (themes and plugins for the Steam desktop client) into
# your home folder, so it works on read-only systems like Bazzite where the
# official installer can't write to /usr. No root, no reboot.
#
#   curl -fsSL https://raw.githubusercontent.com/ethembeldagli/millennium-bazzite/main/install.sh | sh
#
# Run the same command again to update or remove it. Flags are optional:
# see --help.

set -u

INSTALLER_VERSION="1.0.0"
UPSTREAM="SteamClientHomebrew/Millennium"
SELF_URL="https://raw.githubusercontent.com/ethembeldagli/millennium-bazzite/main/install.sh"
ONE_LINER="curl -fsSL $SELF_URL | sh"

action=""
beta=0
yes=0
restart=ask
game_mode=""
from=""

# ---------------------------------------------------------------- output

if [ -t 1 ]; then
    B="$(printf '\033[1m')" D="$(printf '\033[2m')" R="$(printf '\033[0m')"
    RED="$(printf '\033[31m')" GRN="$(printf '\033[32m')" YLW="$(printf '\033[33m')" CYN="$(printf '\033[36m')"
else
    B="" D="" R="" RED="" GRN="" YLW="" CYN=""
fi

say()  { printf '%s\n' "$*"; }
step() { printf '%s::%s %s\n' "$CYN" "$R" "$*"; }
ok()   { printf '%s✓%s %s\n' "$GRN" "$R" "$*"; }
warn() { printf '%s!%s %s\n' "$YLW" "$R" "$*" >&2; }
die()  { printf '%sError:%s %s\n' "$RED" "$R" "$*" >&2; exit 1; }

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

Run with no options to pick install, update or delete from a menu:
  $ONE_LINER

Options (all optional):
  --install         install or reinstall the latest Millennium
  --update          update if a newer Millennium is out
  --uninstall       remove Millennium (asks before deleting plugins/settings)
  --check           show what's installed and whether an update is out
  --game-mode       load Millennium in Game Mode too
  --desktop-only    load Millennium in Desktop Mode only (default)
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
        millennium_loaded && return 0
        i=$((i + 2))
        sleep 2
    done
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
    note_unlocked_usr_copy

    restart_steam with-millennium
    case $? in
        0)
            step "Waiting for Millennium to load (Steam may update itself first)..."
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
    say "  ${D}From your next login it loads automatically. Run this again to update or remove it.${R}"
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
    # Give Decky back the debugger file that Millennium deleted.
    decky_installed && touch "$CEF_FILE"
    rm -rf "$LIB_DIR" "$LIB_DIR.new" "$LIB_DIR.old"
    ok "Removed Millennium${old:+ $old}."

    kept=""
    for d in $DATA_DIRS; do [ -d "$d" ] && kept="$kept $d"; done
    if [ -n "$kept" ]; then
        if confirm "Also delete your Millennium plugins, settings and logs?" n; then
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

    say ""
    say "${B}Millennium for Bazzite${R}  ${D}Steam themes and plugins, no root needed${R}"
    say ""
    if [ -z "$old" ]; then
        say "  Latest Millennium: ${latest:-unknown (offline?)}"
        say ""
        say "  [i] Install"
        say "  [q] Quit"
        default=i
    else
        mode=$(current_mode)
        if [ "$mode" = desktop ]; then mode_text="Desktop Mode only"; else mode_text="Desktop Mode and Game Mode"; fi
        say "  Installed: $old ($mode_text)"
        say "  Latest:    ${latest:-unknown (offline?)}"
        say ""
        default=q
        if [ -n "$latest" ] && older "$old" "$latest"; then
            say "  [u] Update to $latest"
            default=u
        fi
        say "  [r] Reinstall"
        if [ "$mode" = desktop ]; then
            if decky_installed; then
                say "  [g] Also load it in Game Mode (turns Decky off there)"
            else
                say "  [g] Also load it in Game Mode"
            fi
        else
            say "  [g] Load it in Desktop Mode only"
        fi
        say "  [d] Delete"
        say "  [q] Quit"
    fi
    say ""
    printf 'Choose [%s]: ' "$default"
    read -r choice </dev/tty || choice=""
    choice=${choice:-$default}
    say ""
    case "$choice" in
        [Ii]*|[Rr]*) do_install ;;
        [Uu]*) do_update ;;
        [Gg]*)
            if [ -z "$old" ]; then
                say "Nothing changed."
            elif [ "$(current_mode)" = desktop ]; then
                do_set_mode both
            else
                do_set_mode desktop
            fi
            ;;
        [Dd]*) if [ -n "$old" ]; then do_uninstall; else say "Nothing changed."; fi ;;
        *) say "Nothing changed." ;;
    esac
}

# ---------------------------------------------------------------- main

main() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --install|install) action=install ;;
            --update|update|--upgrade) action=update ;;
            --uninstall|uninstall|--remove|--delete) action=uninstall ;;
            --check|check|--status) action=check ;;
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
    if [ -z "$action" ] && [ -n "$game_mode" ] && [ -n "$(installed_version)" ]; then
        do_set_mode "$game_mode"
        return
    fi
    case "$action" in
        install) do_install ;;
        update) do_update ;;
        uninstall) do_uninstall ;;
        check) do_check ;;
        *)
            if interactive; then
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
