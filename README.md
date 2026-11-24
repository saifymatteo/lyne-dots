# lyne-dots (Matteo's fork)

A personal fork of [caioax/lyne-dots](https://github.com/caioax/lyne-dots), running as the Fedora Workstation desktop of Matteo's private Settings (dotfiles) repo.

> [!NOTE]
> This README only covers what differs from upstream. For features, screenshots, themes, keybindings, the `lyne` CLI and credits, read the [upstream README](https://github.com/caioax/lyne-dots#readme). Upstream targets Arch Linux; this fork also runs on Fedora.

## What's different

### Fedora support

- **Autostart:** finds the KDE polkit agent under Fedora's `/usr/libexec/kf6/` and falls back to `hyprpolkitagent`. `kbuildsycoca6` runs only when installed.
- **Menus:** `XDG_MENU_PREFIX=arch-` is set only when `arch-applications.menu` exists.
- **Mission Center:** the dashboard button launches the Flathub app (`io.missioncenter.MissionCenter`) when the binary is missing.

### Face unlock lock screen (Howdy)

- **Face first:** the lock starts PAM as soon as the screen locks, so Howdy scans before a password is asked. A password typed early waits until PAM asks for it. PAM restarts after a failure and on wake, because the camera does not survive sleep.
- **PAM service:** `lock.pamService` in `state.json` picks the `/etc/pam.d` stack (for example `hyprlock`). The default is `login`.
- **Retry button:** "Unlock with Howdy" under the password field runs the face scan again. It is hidden for `login`.
- **Crash guard:** `scripts/start.sh` preloads `pam_howdy.so` into Quickshell when the lock's stack uses it, because unloading the module can crash the next PAM log. Apps the shell launches don't inherit `LD_PRELOAD` or `MALLOC_CONF`.
- **`loginctl lock-session`** locks the screen. Unlocking still needs PAM.

### Launcher calculator

- Sums and conversions typed in apps mode (`2*21`, `5 km to mi`, `100usd`) are answered above the apps through `qalc`.
- **Settings › Launcher:** "Calculator in search" (`launcher.inferCalc`) turns it on or off. "Home currency" (`launcher.homeCurrency`) sets the currency for bare amounts.
- Detection is in `services/calc.js`; it ignores app names such as `7zip` and `gimp 2`.

### Keybinds

- **`komorebi` navigation preset** (Settings › Keybinds) matches komorebi + whkd on Windows:

  | Action | Keys |
  | --- | --- |
  | Focus / move window | Super (+ Shift) + arrows |
  | Resize, 50 px per press | Super + Shift + E/I/N/O |
  | Previous / next workspace | Super + Ctrl + `-` / `=` (add Shift to move the window) |
  | Previous / next monitor | Super + `,` / `.` (add Shift to move the window) |
  | Launcher | Alt + Space |
  | Power menu | Alt + F4 |

- **New bind ids:** `focus-monitor-*`, `move-to-monitor-*`, `launcher-alt` and `power-menu-alt`. Every preset can set them; none has keys by default.
- **Resize step:** presets set `_resize_step` (`LYNE_RESIZE_STEP`, default 20 px).

### Smaller changes

- **Clipboard:** `clipboard.enabled = false` stops keeping history.
- **Wallpaper IPC:** `qs ipc call wallpapers set <path>` applies a wallpaper as Settings does; `current` prints it. Re-applying a path whose file changed rebuilds its thumbnail, so the daily Bing image refreshes.
- **Start script:** autostart and `lyne reload` both start the shell through `scripts/start.sh`.
- **State sync:** `lock.pamService`, `clipboard.enabled` and `matteo.switched` are in `defaults.json`, so `lyne state sync` keeps them.
- **Power menu:** icon-only buttons show their label as a tooltip.

Full list: `git log --oneline upstream/main..main`.

## Install

This fork is installed by the Settings repo, not by upstream's `curl | bash`:

```bash
bash "$MATTEO_SETTINGS/installer/Installer_Personal.sh"   # full Fedora machine
bash "$MATTEO_SETTINGS/hyprland/install.sh"               # just (re)activate lyne + the Settings layer
```

The Settings layer (`hyprland/matteo.lua`: monitors, window rules, plugins, Matteo binds, daily wallpaper) is loaded from `~/.config/hypr/local/` and lives in Settings, not here. `$MATTEO_SETTINGS/hyprland/AGENTS.md` decides what belongs in this fork and what belongs in Settings.

## Update

Don't use `lyne update` or its channels: they move the checkout off the fork. Merge upstream instead:

```bash
git -C ~/.lyne-dots fetch upstream && git -C ~/.lyne-dots merge upstream/main
(cd ~/.lyne-dots && node --test tests/js && lua tests/lua/bind_presets.lua)
git -C ~/.lyne-dots push origin main
lyne reload
```

When upstream changes its README, the merge conflicts on `README.md`. Keep this one with `git checkout --ours README.md`, then add anything new the fork changed.

Fork commits are prefixed `fork:`. Generic fixes are offered upstream so the fork stays small. Run bats inside a lyne session with `env -u LD_PRELOAD -u MALLOC_CONF`.

## License

[GPL-3.0](LICENSE), as upstream.
