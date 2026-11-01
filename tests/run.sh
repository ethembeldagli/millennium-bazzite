#!/bin/sh
# Tests for install.sh. They use a fake home folder with a fake Steam and fake
# Millennium release tarballs, so they never touch your real Steam.
#
#   sh tests/run.sh            # with your default sh
#   bash tests/run.sh          # or any other POSIX shell

set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
INSTALLER="$ROOT/install.sh"
SHELL_UNDER_TEST=${SHELL_UNDER_TEST:-sh}
WORK=$(mktemp -d "${TMPDIR:-/tmp}/millennium-bazzite-test.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

passed=0
failed=0

pass() { passed=$((passed + 1)); printf '  ok   %s\n' "$1"; }
fail() { failed=$((failed + 1)); printf '  FAIL %s\n' "$1"; }
check() { name=$1; shift; if "$@"; then pass "$name"; else fail "$name"; fi; }

# A fake release tarball that has the same layout as the real one.
make_release() {
    version=$1 dir="$WORK/release-$1"
    mkdir -p "$dir/usr/lib/millennium"
    for f in libmillennium_pvs64 libmillennium_bootstrap_x86.so libmillennium_hhx64.so \
             libmillennium_bootstrap_hhx64.so libmillennium_x86.so libmillennium_luavm_x86; do
        echo "$f $version" >"$dir/usr/lib/millennium/$f"
        chmod 644 "$dir/usr/lib/millennium/$f"
    done
    [ "${2:-}" = extra ] && mkdir -p "$dir/usr/share/millennium" && echo x >"$dir/usr/share/millennium/assets"
    name="millennium-v$version-linux-x86_64"
    (cd "$dir" && tar czf "$WORK/$name.tar.gz" ./)
    (cd "$WORK" && sha256sum "$name.tar.gz" >"$name.sha256")
    printf '%s\n' "$WORK/$name.tar.gz"
}

new_home() {
    HOME="$WORK/home-$1"
    mkdir -p "$HOME/.local/share/Steam/ubuntu12_32" "$HOME/.local/share/Steam/ubuntu12_64" "$HOME/.steam"
    ln -s "$HOME/.local/share/Steam" "$HOME/.steam/steam"
    printf '#!/bin/sh\n' >"$HOME/.local/share/Steam/ubuntu12_32/steam"
    chmod +x "$HOME/.local/share/Steam/ubuntu12_32/steam"
    export HOME
}

run() {
    MILLENNIUM_BAZZITE_ALLOW_CONTAINER=1 XDG_CURRENT_DESKTOP=test \
        "$SHELL_UNDER_TEST" "$INSTALLER" --yes --no-restart "$@" </dev/null >"$WORK/out" 2>&1
}

out_has() { grep -qF -- "$1" "$WORK/out"; }
link_to() { [ -L "$1" ] && [ "$(readlink "$1")" = "$2" ]; }

echo "Shell: $SHELL_UNDER_TEST"

# ------------------------------------------------------------ version compare
echo "versions"
if (
    export MILLENNIUM_BAZZITE_TEST=1
    # shellcheck source=/dev/null
    . "$INSTALLER"
    ok=0
    t() { if older "$1" "$2"; then r=yes; else r=no; fi; [ "$r" = "$3" ] || { echo "    older $1 $2 -> $r, want $3"; ok=1; }; }
    t 3.6.2 3.6.3 yes
    t 3.6.3 3.6.2 no
    t 3.6.2 3.6.2 no
    t 3.6.2 3.10.0 yes
    t 3.10.0 3.9.9 no
    t 3.6.3-beta.1 3.6.3 yes
    t 3.6.3 3.6.3-beta.1 no
    t 3.6.2 3.6.3-beta.1 yes
    t 3.6.3-beta.1 3.6.3-beta.2 yes
    t 3.6 3.6.1 yes
    t v3.6.2 3.6.3 yes
    t unknown 3.6.2 yes
    exit $ok
); then
    pass "older() orders versions"
else
    fail "older() orders versions"
fi

# ------------------------------------------------------------ install
echo "install"
v1=$(make_release 3.6.2)
v2=$(make_release 3.6.3)
new_home main
mkdir -p "$HOME/.config/environment.d"
# shellcheck disable=SC2016 # written literally, like the old community script did
echo 'MILLENNIUM_RUNTIME_PATH=$HOME/.millennium/usr/lib/millennium/libmillennium_x86.so' >"$HOME/.config/environment.d/milllennium.conf"
echo 'KEEP_ME=1' >"$HOME/.config/environment.d/other.conf"
echo "real libXtst" >"$HOME/.steam/steam/ubuntu12_64/libXtst.so.6"
mkdir -p "$HOME/homebrew/services" "$HOME/.config/gamescope-session-plus/sessions.d"
touch "$HOME/homebrew/services/PluginLoader" "$HOME/.steam/steam/.cef-enable-remote-debugging"
echo 'export MY_OWN_SETTING=1' >"$HOME/.config/gamescope-session-plus/sessions.d/steam"
HOOK="$HOME/.config/gamescope-session-plus/sessions.d/steam"
AUTOSTART="$HOME/.config/autostart/millennium-bazzite.desktop"
CEF="$HOME/.steam/steam/.cef-enable-remote-debugging"
hook_blocks() { grep -c '>>> Millennium for Bazzite >>>' "$HOOK" 2>/dev/null || true; }
LIB="$HOME/.local/lib/millennium"
ENVF="$HOME/.config/environment.d/millennium.conf"

check "install succeeds" run --install --from "$v1"
check "says installed" out_has "Installed Millennium 3.6.2"
check "files copied" test -f "$LIB/libmillennium_x86.so"
check "helpers are executable" test -x "$LIB/libmillennium_luavm_x86" -a -x "$LIB/libmillennium_pvs64"
check "version recorded" grep -qx 3.6.2 "$LIB/.installed-by-millennium-bazzite"
check "32-bit hook linked" link_to "$HOME/.steam/steam/ubuntu12_32/libXtst.so.6" "$LIB/libmillennium_bootstrap_x86.so"
check "64-bit hook linked" link_to "$HOME/.steam/steam/ubuntu12_64/libXtst.so.6" "$LIB/libmillennium_bootstrap_hhx64.so"
check "hhx64 linked" link_to "$HOME/.steam/steam/ubuntu12_64/libmillennium_hhx64.so" "$LIB/libmillennium_hhx64.so"
check "existing file backed up" grep -q "real libXtst" "$HOME/.steam/steam/ubuntu12_64/libXtst.so.6.millennium-bazzite.bak"
check "env file written" grep -q "^MILLENNIUM_RUNTIME_PATH=" "$ENVF"
check "desktop only by default" grep -q GAMESCOPE_MODE_SAVE_FILE "$ENVF"
check "old community env file removed" test ! -e "$HOME/.config/environment.d/milllennium.conf"
check "unrelated env file kept" test -f "$HOME/.config/environment.d/other.conf"

# The env file is read by systemd (Desktop Mode) and sourced by bash in Game Mode.
desk=$(env -i HOME="$HOME" sh -c "set -a; . '$ENVF'; printf %s \"\$MILLENNIUM_RUNTIME_PATH\"")
game=$(env -i HOME="$HOME" GAMESCOPE_MODE_SAVE_FILE=/x sh -c "set -a; . '$ENVF'; printf %s \"\$MILLENNIUM_RUNTIME_PATH\"")
check "desktop session gets the library" test "$desk" = "$LIB/libmillennium_x86.so"
check "game mode session gets it switched off" test "$game" = "/millennium-is-off-in-game-mode/x"
gen=/usr/lib/systemd/user-environment-generators/30-systemd-environment-d-generator
if [ -x "$gen" ]; then
    sysd=$(env -i HOME="$HOME" XDG_CONFIG_HOME="$HOME/.config" "$gen" | grep '^MILLENNIUM_RUNTIME_PATH=')
    check "systemd reads the env file" test "$sysd" = "MILLENNIUM_RUNTIME_PATH=$LIB/libmillennium_x86.so"
fi

# Decky gets Game Mode, Millennium gets Desktop Mode.
check "game mode hook added" test "$(hook_blocks)" = 1
check "own game mode settings kept" grep -q MY_OWN_SETTING "$HOOK"
check "desktop autostart added" grep -qF "Exec=rm -f \"$CEF\"" "$AUTOSTART"
rm -f "$CEF"
env -i HOME="$HOME" bash -c "set -a; . '$HOOK'" 2>/dev/null || env -i HOME="$HOME" sh -c "set -a; . '$HOOK'"
check "game mode hook turns Decky's debugger back on" test -e "$CEF"

# ------------------------------------------------------------ check / update
echo "check and update"
check "check works" run --check --from "$v2"
check "check sees the update" out_has "update available"
check "update succeeds" run --update --from "$v2"
check "says updated" out_has "Updated Millennium 3.6.2 → 3.6.3"
check "new files in place" grep -q "3.6.3" "$LIB/libmillennium_x86.so"
check "no staging dirs left" test ! -e "$LIB.new" -a ! -e "$LIB.old"
check "update again is a no-op" run --update --from "$v2"
check "says up to date" out_has "3.6.3 is up to date"

# ------------------------------------------------------------ game mode toggle
echo "game mode"
check "turn on game mode" run --game-mode
check "env file is plain" sh -c "! grep -q GAMESCOPE_MODE_SAVE_FILE '$ENVF'"
game=$(env -i HOME="$HOME" GAMESCOPE_MODE_SAVE_FILE=/x sh -c "set -a; . '$ENVF'; printf %s \"\$MILLENNIUM_RUNTIME_PATH\"")
check "game mode session gets the library" test "$game" = "$LIB/libmillennium_x86.so"
check "game mode hook removed" test "$(hook_blocks)" = 0
check "own settings still kept" grep -q MY_OWN_SETTING "$HOOK"
check "desktop autostart removed" test ! -e "$AUTOSTART"
check "says Decky stops" out_has "Decky Loader won't work in Game Mode"
check "reinstall keeps game mode" run --install --from "$v2"
check "still game mode" sh -c "! grep -q GAMESCOPE_MODE_SAVE_FILE '$ENVF'"
check "back to desktop only" run --desktop-only
check "desktop only again" grep -q GAMESCOPE_MODE_SAVE_FILE "$ENVF"
check "exactly one game mode hook" test "$(hook_blocks)" = 1
check "update keeps one hook" run --install --from "$v2"
check "still exactly one hook" test "$(hook_blocks)" = 1

# ------------------------------------------------------------ bad downloads
echo "bad downloads"
bad=$(make_release 9.9.9)
echo "0000000000000000000000000000000000000000000000000000000000000000  millennium-v9.9.9-linux-x86_64.tar.gz" >"$WORK/millennium-v9.9.9-linux-x86_64.sha256"
if run --install --from "$bad"; then fail "bad checksum fails"; else pass "bad checksum fails"; fi
check "says checksum" out_has "checksum"
check "old version untouched" grep -q "3.6.3" "$LIB/libmillennium_x86.so"
odd=$(make_release 9.9.8 extra)
if run --install --from "$odd"; then fail "unknown layout fails"; else pass "unknown layout fails"; fi
check "explains layout" out_has "outside /usr/lib"

# ------------------------------------------------------------ uninstall
echo "uninstall"
mkdir -p "$HOME/.config/millennium" "$HOME/.local/share/millennium/plugins"
check "uninstall succeeds" run --uninstall
check "says removed" out_has "Removed Millennium 3.6.3"
check "library gone" test ! -e "$LIB"
check "env file gone" test ! -e "$ENVF"
check "32-bit hook gone" test ! -e "$HOME/.steam/steam/ubuntu12_32/libXtst.so.6"
check "original file restored" grep -q "real libXtst" "$HOME/.steam/steam/ubuntu12_64/libXtst.so.6"
check "hhx64 link gone" test ! -e "$HOME/.steam/steam/ubuntu12_64/libmillennium_hhx64.so"
check "plugins kept by default" test -d "$HOME/.local/share/millennium/plugins"
check "game mode hook gone" test "$(hook_blocks)" = 0
check "own settings survive uninstall" grep -q MY_OWN_SETTING "$HOOK"
check "desktop autostart gone" test ! -e "$AUTOSTART"
check "Decky's debugger file restored" test -e "$CEF"
check "uninstall again is harmless" run --uninstall
check "says not installed" out_has "isn't installed"

# ------------------------------------------------------------ preflight
echo "preflight"
new_home nosteam
rm "$HOME/.local/share/Steam/ubuntu12_32/steam"
if run --install --from "$v1"; then fail "no Steam fails"; else pass "no Steam fails"; fi
check "explains Steam" out_has "Open Steam once"
if MILLENNIUM_BAZZITE_ALLOW_CONTAINER='' CONTAINER_ID=box "$SHELL_UNDER_TEST" "$INSTALLER" --check </dev/null >"$WORK/out" 2>&1; then
    fail "refuses to run in a container"
else
    pass "refuses to run in a container"
fi
check "help works" sh -c "\"\$0\" \"\$1\" --help >/dev/null" "$SHELL_UNDER_TEST" "$INSTALLER"

echo
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
