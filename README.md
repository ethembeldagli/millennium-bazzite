# Millennium for Bazzite

**Steam themes and plugins on Bazzite.** One command, no root, survives system updates, and keeps Decky working in Game Mode.

```sh
curl -fsSL https://raw.githubusercontent.com/ethembeldagli/millennium-bazzite/main/install.sh | sh
```

Run it in a normal terminal in Desktop Mode (not inside distrobox). It installs the latest [Millennium](https://github.com/SteamClientHomebrew/Millennium), restarts Steam, and checks that Millennium loaded. Then open **Steam → Millennium** to pick a theme.

Run the same command again any time to **update**, **reinstall** or **delete** it. You get a menu, no flags needed.

## Why this exists

Millennium's official installer copies its files into `/usr/lib`, but Bazzite's `/usr` is read-only. People got around it by unlocking `/usr` or by pasting scripts from a [GitHub discussion](https://github.com/SteamClientHomebrew/Millennium/discussions/835), and those setups break: the next Bazzite update wipes the files, a reboot is needed, or Decky stops working.

This installer does it the Bazzite way:

| | Official installer | Millennium for Bazzite |
|---|---|---|
| Where files go | `/usr/lib/millennium` (read-only on Bazzite) | `~/.local/lib/millennium` |
| Needs `sudo` | Yes | No |
| Survives Bazzite updates | No | Yes, it's all in your home folder |
| Needs a reboot | — | No, it restarts Steam for you |
| Decky Loader | Stops working | Keeps working in Game Mode |
| Update / uninstall | Manual | Same command, pick from a menu |

It downloads Millennium's own release from GitHub and checks its SHA-256 checksum. Nothing in Millennium is modified.

## Millennium and Decky, together

Millennium and Decky Loader can't run in the same Steam session. Millennium deletes the file that switches on Steam's debugger, which Decky needs, and Decky leaves Millennium's settings page black ([Millennium#472](https://github.com/SteamClientHomebrew/Millennium/issues/472)).

So by default each one gets its own mode:

- **Desktop Mode:** Millennium with your themes and plugins. Decky has no menu here anyway.
- **Game Mode:** stock Steam with Decky, exactly as before.

You can also load Millennium in Game Mode (menu option **[g]**), but then Decky won't work there.

## Update or uninstall

Run the install command again:

```
Millennium for Bazzite  Steam themes and plugins, no root needed

  Installed: 3.6.2 (Desktop Mode only)
  Latest:    3.6.3

  [u] Update to 3.6.3
  [r] Reinstall
  [g] Also load it in Game Mode (turns Decky off there)
  [d] Delete
  [q] Quit

Choose [u]:
```

**Delete** removes everything it added and gives Decky its debugger file back. It asks before deleting your Millennium plugins and settings.

<details>
<summary>Options for scripts</summary>

```sh
curl -fsSL https://raw.githubusercontent.com/ethembeldagli/millennium-bazzite/main/install.sh | sh -s -- --update --yes
```

| Option | What it does |
|---|---|
| `--install` | Install or reinstall the latest Millennium |
| `--update` | Update if a newer Millennium is out |
| `--uninstall` | Remove Millennium |
| `--check` | Show what's installed and whether an update is out |
| `--game-mode` / `--desktop-only` | Choose where Millennium loads |
| `--beta` | Use Millennium beta releases |
| `--no-restart` | Don't restart Steam afterwards |
| `--yes` | Don't ask questions; use the defaults |
| `--from FILE` | Install from a downloaded `millennium-*.tar.gz` |

</details>

## What it changes

Everything is in your home folder:

| File | Why |
|---|---|
| `~/.local/lib/millennium/` | Millennium itself |
| `~/.steam/steam/ubuntu12_32/libXtst.so.6`<br>`~/.steam/steam/ubuntu12_64/libXtst.so.6` | Links that load Millennium into Steam (the same hook the official installer uses) |
| `~/.config/environment.d/millennium.conf` | Tells Millennium where it's installed. In Desktop-only mode it points nowhere in Game Mode, so Millennium stays off there |
| `~/.config/gamescope-session-plus/sessions.d/steam` | A marked block that turns Decky's debugger back on when Game Mode starts. Anything else in this file is kept |
| `~/.config/autostart/millennium-bazzite.desktop` | Turns Decky's debugger off when you log into Desktop Mode |

## FAQ

**Does it work on Steam's beta / 64-bit client?** Millennium often doesn't load on Steam betas yet. The installer tells you if you're on one and can switch you back to stable.

**Flatpak Steam?** No. Millennium doesn't support it. Use the Steam that comes with Bazzite.

**Other atomic distros?** It only uses your home folder, so it should also work on Bluefin, Aurora, Silverblue and Kinoite with regular Steam. The Game Mode parts are for Bazzite's Game Mode. Only Bazzite is tested so far; reports are welcome.

**I already unlocked `/usr` and copied Millennium there.** That copy is ignored once this is installed, and it disappears with your next Bazzite update.

**Is this official?** No. It's a community installer. Millennium is made by [Steam Homebrew](https://github.com/SteamClientHomebrew/Millennium). Report problems with themes or plugins there, and problems with installing here.

## Credits

[Millennium](https://github.com/SteamClientHomebrew/Millennium) by Steam Homebrew does all the real work. The home-folder approach builds on ideas from @igor-tsiglyar, @Shellke, @LunRos and @Zeglius in [Millennium#835](https://github.com/SteamClientHomebrew/Millennium/discussions/835).

Not affiliated with Steam Homebrew, Valve or Universal Blue.

## Also by me

- [Terminal Wrapped](https://github.com/ethembeldagli/termwrapped): Spotify Wrapped, but for your terminal.
- [roastfetch](https://github.com/ethembeldagli/roastfetch): your fastfetch, plus a roast of your setup.

## License

MIT
