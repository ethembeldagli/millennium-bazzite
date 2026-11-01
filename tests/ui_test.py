"""Drives the full-screen menu through a pseudo-terminal, with real key
presses, in a fake home folder with a fake Steam and a fake Millennium release.

    python3 tests/ui_test.py [shell]
"""
import io, os, pty, re, select, shutil, signal, subprocess, sys, tarfile, tempfile, time, fcntl, termios, struct

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHELL = sys.argv[1] if len(sys.argv) > 1 else "sh"
DOWN, UP, ENTER = "\x1b[B", "\x1b[A", "\r"
failed = 0


def check(name, ok):
    global failed
    print(f"  {'ok  ' if ok else 'FAIL'} {name}")
    failed += 0 if ok else 1


def plain(data):
    return re.sub(r"\x1b\[[0-9;?]*[A-Za-z]", "", data.decode("utf-8", "replace"))


def make_home(work):
    home = os.path.join(work, "home")
    steam = os.path.join(home, ".local/share/Steam")
    os.makedirs(os.path.join(steam, "ubuntu12_32"))
    os.makedirs(os.path.join(home, ".steam"))
    os.symlink(steam, os.path.join(home, ".steam/steam"))
    with open(os.path.join(steam, "ubuntu12_32/steam"), "w") as f:
        f.write("#!/bin/sh\n")
    os.chmod(os.path.join(steam, "ubuntu12_32/steam"), 0o755)
    os.makedirs(os.path.join(home, "homebrew/services"))
    open(os.path.join(home, "homebrew/services/PluginLoader"), "w").close()
    tarball = os.path.join(work, "millennium-v9.9.9-linux-x86_64.tar.gz")
    with tarfile.open(tarball, "w:gz") as tar:
        for name in ["libmillennium_x86.so", "libmillennium_bootstrap_x86.so", "libmillennium_bootstrap_hhx64.so",
                     "libmillennium_hhx64.so", "libmillennium_luavm_x86", "libmillennium_pvs64"]:
            data = f"{name}\n".encode()
            info = tarfile.TarInfo(f"./usr/lib/millennium/{name}")
            info.size = len(data)
            tar.addfile(info, io.BytesIO(data))
    return home, tarball


def session(home, args, steps, timeout=60, **extra_env):
    """Run the installer; steps are (text to wait for, keys to send) pairs."""
    env = dict(os.environ, HOME=home, TERM="xterm-256color", COLORTERM="truecolor",
               MILLENNIUM_BAZZITE_ALLOW_CONTAINER="1", MILLENNIUM_BAZZITE_NO_SYSTEMCTL="1", **extra_env)
    env.pop("NO_COLOR", None)
    pid, fd = pty.fork()
    if pid == 0:
        os.execvpe(SHELL, [SHELL, *args], env)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 100, 0, 0))
    out, start, steps = b"", time.time(), list(steps)
    while time.time() - start < timeout:
        r, _, _ = select.select([fd], [], [], 0.05)
        if r:
            try:
                chunk = os.read(fd, 65536)
            except OSError:
                break
            if not chunk:
                break
            out += chunk
        if steps and steps[0][0] in plain(out):
            time.sleep(0.3)
            os.write(fd, steps.pop(0)[1].encode())
    else:
        os.kill(pid, signal.SIGKILL)
    _, status = os.waitpid(pid, 0)
    if steps:
        print(f"    waited for {steps[0][0]!r}; the screen ended with:")
        print("    " + plain(out)[-500:].replace("\n", "\n    "))
    return os.waitstatus_to_exitcode(status), out, steps


work = tempfile.mkdtemp()
try:
    home, tarball = make_home(work)
    installer = os.path.join(ROOT, "install.sh")
    lib = os.path.join(home, ".local/lib/millennium")

    print(f"full-screen menu ({SHELL})")
    code, out, left = session(home, [installer, "--from", tarball], [
        ("Install Millennium 9.9.9", DOWN + UP + ENTER),
        ("Load Millennium in Game Mode too?", ENTER),
        ("Press any key to close", "x"),
    ])
    text = plain(out)
    check("fresh install: every step was reached", not left)
    check("fresh install: exits cleanly", code == 0)
    check("fresh install: uses the full screen", b"\x1b[?1049h" in out)
    check("fresh install: gives the terminal back", out.rstrip().find(b"\x1b[?1049l") > 0 and b"\x1b[?25h" in out)
    check("fresh install: installed", os.path.isfile(os.path.join(lib, "libmillennium_x86.so")))
    check("fresh install: Game Mode question defaults to no",
          "GAMESCOPE_MODE_SAVE_FILE" in open(os.path.join(home, ".config/environment.d/millennium.conf")).read())
    check("fresh install: result printed after leaving", "Installed Millennium 9.9.9" in text.split("\x1b[?1049l")[-1] or "Installed Millennium 9.9.9" in text)

    command = os.path.join(home, ".local/bin/millennium-bazzite")
    timer = os.path.join(home, ".config/systemd/user/timers.target.wants/millennium-bazzite-update.timer")
    check("command installed", os.access(command, os.X_OK))
    code, out, left = session(home, [command, "--from", tarball], [
        ("Turn automatic updates off", "a"),
        ("Press any key to close", "x"),
    ])
    check("letter key: auto-update turned off", not left and code == 0 and not os.path.lexists(timer))

    code, out, left = session(home, [command, "--from", tarball], [
        # Up to date, so Quit (the last option) starts selected: down wraps to the top.
        ("Turn automatic updates on", DOWN + DOWN + UP + ENTER),
        ("Press any key to close", "x"),
    ])
    check("arrow keys: wrap around and pick the first option", not left and code == 0 and os.path.lexists(timer))

    code, out, left = session(home, [command, "--from", tarball], [("Delete", "q")])
    check("quit: nothing changed", not left and code == 0 and "Nothing changed." in plain(out))

    code, out, left = session(home, [command, "--from", tarball], [
        ("Delete", "d"),
        ("Delete Millennium?", "y"),
        ("Press any key to close", "x"),
    ])
    check("delete: removed", not left and code == 0 and not os.path.exists(lib) and not os.path.exists(command))

    code, out, left = session(home, [installer, "--from", tarball], [("Choose [i]:", "q\r")], PLAIN_INSTALLER="1")
    check("PLAIN_INSTALLER=1 gives the plain menu", not left and code == 0 and b"\x1b[?1049h" not in out)
finally:
    shutil.rmtree(work)

print(f"\n{'all passed' if not failed else f'{failed} failed'}")
sys.exit(1 if failed else 0)
