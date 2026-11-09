# Quickshell bar for Mango 0.18.5: config and verification

Verified on 2026-11-08 in the WSL distro `FedoraLinux-45` with quickshell 0.3.2 (COPR), mangowm 0.18.5 (Terra), pipewire 1.6.11 / wireplumber 0.5.19, mpd 0.24.15, mpdris2 0.9.1.

Files:
- Config: `C:/dev/scratch-mango/quickshell/shell.qml` → `~/.config/quickshell/shell.qml` (237 lines, about 200 without blanks and comments)
- Screenshot: `C:/dev/scratch-mango/quickshell/bar.png` (top: 24" output HEADLESS-1 at 1920 wide, padded; bottom: HEADLESS-2 at 2560 wide)
- Extra screenshots: `C:/dev/scratch-mango/quickshell/shots/` (`out1.png`/`out2.png` full outputs, `i1`–`i7` interaction states)
- Test harness: `C:/dev/scratch-mango/quickshell/test/` (`run.sh` is the entry point; it only exists for WSL testing and isn't part of the article)

## Install

```sh
sudo dnf copr enable errornointernet/quickshell
sudo dnf install quickshell        # 0.3.2-1.fc45; replaces Fedora's 0.2.1 snapshot
sudo dnf install mpd mpc mpdris2   # MPD + MPRIS bridge for the MPD module
```

Start it from Mango with `exec_once=qs`. With no arguments, `qs` loads `~/.config/quickshell/shell.qml`. The MPRIS bridge has to run too: `systemctl --user enable --now mpDris2.service` (or `exec_once=mpDris2`).

## Reload

Quickshell watches the config and reloads it whenever any of its files change: `Quickshell.watchFiles` / `QuickshellSettings.watchFiles`, "If true then the configuration will be reloaded whenever any files change. Defaults to true." (https://quickshell.org/docs/v0.3.2/types/Quickshell/QuickshellSettings/). Every harness run started `qs` fresh, so I didn't test the live reload itself.

## Show/hide key

The bar has `IpcHandler { target: "bar"; function toggle() }`. Mango bind: `bind=SUPER,b,spawn,qs ipc call bar toggle` (MangoConfig was told). `qs ipc show` lists `target bar / function toggle(): void`. Verified: after `qs ipc call bar toggle` the bar disappears on every output, and tiled windows move up to the gap because the exclusive zone is released (`shots/i6-hidden.png`). A second call brings it back.

## Design notes (what the QML does)

- `Variants { model: Quickshell.screens }` → one `PanelWindow` per output, anchored top/left/right, `implicitHeight: 28`, default `exclusionMode` (Auto = exclusive zone of bar height). Maple Mono at `font.pointSize: 11` fits the 28 px height.
- Tags: `mmsg watch tags <screen.name>`. `ShellScreen.name` matched the Mango output names (`HEADLESS-1`, `HEADLESS-2`) in the test. A tag is shown if `is_active || client_count > 0`. Active: `#151515` on `#e8e3e3` (same as dwl's SchemeSel and the site). Urgent: `#151515` on `#b66467` (dwl SchemeUrg). Occupied but inactive: muted `#a39d9d` on bg. Click → `Quickshell.execDetached(["mmsg","dispatch","viewcrossmon,<n>,<output>"])`.
- Title: `mmsg watch focusing-client`, with `title ?? ""` because Mango sends `null` when nothing is focused. The label is centred on the screen, and its width is capped at `bar.width - 2*max(left,right) - 32` so it elides before touching either side.
- `mmsg` restarts: an inline `component MmsgWatch: Process` parses each line as JSON (bad lines → `console.warn`) and restarts 1 s after `onExited`.
- MPD: `Mpris.players.values.find(p => p.identity === "Music Player Daemon")`, the identity string hard-coded in `/usr/bin/mpDris2` line 77. Shows `▶ artist - title` (fg) when playing and `‖ artist - title` (muted) when paused. Hidden when no player is present. Click → `togglePlaying()`.
- Volume/mic: an inline `component Volume: Label` over `Pipewire.defaultAudioSink` / `defaultAudioSource`, tracked by `PwObjectTracker`. Text `vol 45%` / `mic 80%`, drawn in the muted colour when muted. Click toggles mute; the wheel changes volume by ±5 %, clamped to 0–100 %.
- Clock: `SystemClock { precision: SystemClock.Minutes }`, format `ddd dd MMM HH:mm` → `Sun 08 Nov 21:05`.
- Tray: `//@ pragma UseQApplication`, `Repeater { model: SystemTray.items }` → `Image { source: modelData.icon }` (18 px). Left click → `activate()` unless `onlyMenu`; right click → `QsMenuAnchor.open()`.

### Glyph coverage (Maple Mono non-NF, `MapleMono-Regular.ttf`)

Checked with `fc-query --format='%{charset}'`. In the font: ▶ U+25B6, ‖ U+2016, ■ U+25A0, ● U+25CF, ○ U+25CB, • U+2022, · U+00B7, │ U+2502, — U+2014, ← → U+2190/2192. **Not** in the font: ⏸ U+23F8, ⏵ U+23F5, ⏯ U+23EF, ♪ U+266A, ― U+2015. So the draft's `⏸` was replaced with `‖`. Both glyphs render in Maple Mono in the screenshots.

## API references (v0.3.2)

- PanelWindow: https://quickshell.org/docs/v0.3.2/types/Quickshell/PanelWindow/
- Variants: https://quickshell.org/docs/v0.3.2/types/Quickshell/Variants/
- Quickshell (screens, execDetached): https://quickshell.org/docs/v0.3.2/types/Quickshell/Quickshell/
- SystemClock: https://quickshell.org/docs/v0.3.2/types/Quickshell/SystemClock/
- QsMenuAnchor: https://quickshell.org/docs/v0.3.2/types/Quickshell/QsMenuAnchor/
- Process / SplitParser / IpcHandler: https://quickshell.org/docs/v0.3.2/types/Quickshell.Io/Process/ , https://quickshell.org/docs/v0.3.2/types/Quickshell.Io/SplitParser/ , https://quickshell.org/docs/v0.3.2/types/Quickshell.Io/IpcHandler/
- Pipewire / PwNode / PwNodeAudio / PwObjectTracker: https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.Pipewire/Pipewire/ , https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.Pipewire/PwNodeAudio/ , https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.Pipewire/PwObjectTracker/
- Mpris / MprisPlayer: https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.Mpris/Mpris/ , https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.Mpris/MprisPlayer/
- SystemTray / SystemTrayItem: https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.SystemTray/SystemTray/ , https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.SystemTray/SystemTrayItem/
- QuickshellSettings.watchFiles: https://quickshell.org/docs/v0.3.2/types/Quickshell/QuickshellSettings/

The names `execDetached`, Process `exited`, and the mpDris2 identity were also checked against the installed files (`/usr/lib64/qt6/qml/Quickshell/*.qmltypes`, `/usr/bin/mpDris2`).

## Verification (WSL, headless Mango, 2 outputs)

Setup (`test/ns.sh`, `test/inner.sh`, `test/session.sh`):
- Rendering: scenefx needs GLES, so `WLR_RENDERER=pixman` is ignored. The recipe that works came from MangoConfig: inside `unshare -m` with a tmpfs `/tmp`, run `mount --bind /dev/dri/card0 /dev/dri/renderD128` (the vgem render node can't allocate dumb buffers, the primary node can) and set `LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe WLR_RENDERER_ALLOW_SOFTWARE=1 MESA_LOADER_DRIVER_OVERRIDE=kms_swrast WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=2 WLR_LIBINPUT_NO_DEVICES=1`. qs ran with `QT_QUICK_BACKEND=software`.
- Session: `dbus-run-session` → pipewire, wireplumber and pipewire-pulse, with two `support.null-audio-sink` nodes (sink + `Audio/Source`) from a `pipewire.conf.d` drop-in. WirePlumber in WSL (no logind seat) set `default.configured.audio.*` but never resolved `default.audio.sink/source`, so `Pipewire.defaultAudioSink` stayed null until the harness set the metadata by hand (`pw-metadata -n default 0 default.audio.sink '{ "name": "test-sink" }' Spa:String:JSON`). This is a WSL test artefact; a real seat session doesn't need it [INFERENCE].
- mpd with a 10-minute ffmpeg sine FLAC tagged "Boards of Canada – Roygbiv", null output, `mpc play`, then `mpDris2`.
- `mango -c test/mango.conf -s 'sh session.sh'`: start qs, a PyQt6 `QSystemTrayIcon` with a two-item menu (SNI tray item), two foot windows (one titled `nvim ~/.config/mango/config.conf`), move one to tag 3.
- Screenshots: `grim -o HEADLESS-1` / `-o HEADLESS-2`.
- Interactions: a small persistent wlr-virtual-pointer client (`test/vptr.c`). wlrctl can't be used because each call creates and destroys its own pointer, so focus is lost between the move and the click.

Packages installed for the test: `mpd mpc python3-pyqt6 wlrctl pulseaudio-utils pipewire-utils wlr-protocols-devel` (wayland-devel was already present).

Results (all from real data, visually confirmed in the screenshots):

| Module | Result |
|---|---|
| Docked bar on both outputs | ✓ 28 px, full width on 1920 and 2560 outputs; tiled windows start below it; hiding it via IPC releases the zone |
| Tags | ✓ HEADLESS-1 shows `1` (active, inverted); HEADLESS-2 shows `1` active + `3` occupied |
| Urgent tag | ✓ foot with `bell.urgent=yes` on hidden tag 2 → `is_urgent:true`, tag `2` drawn on red (`shots/i3-urgent.png`) |
| Tag click | ✓ clicking `3` on HEADLESS-2 → `active_tags:[3]` (`viewcrossmon` with the output name works) |
| Window title | ✓ `nvim ~/.config/mango/config.conf`, centred on each output |
| MPD | ✓ `▶ Boards of Canada - Roygbiv`; click → mpd `[paused]`, label `‖ …` in muted colour |
| Output volume | ✓ `vol 45%`; click → `wpctl` reports `[MUTED]`, label turns muted colour; wheel down → 40 % |
| Mic volume | ✓ `mic 80%`; two wheel-ups → 90 % |
| Clock | ✓ `Sun 08 Nov 21:05` |
| Systray | ✓ PyQt6 SNI icon shown; right click opens its menu ("Test action", "Quit") as a Qt platform menu |
| mmsg restart | ✓ `pkill -f 'mmsg watch'` → all three watchers back within ~1 s (new PIDs); next tag change shows on the bar |
| IPC toggle | ✓ `qs ipc call bar toggle` hides/shows |

qs log: only `INFO` lines plus one warning, `WARN qt.qpa.services: Failed to register with host portal … Connection already associated with an application ID`. That comes from Qt's portal registration and has nothing to do with the config. No QML warnings or errors.

Caveats:
- The tray menu uses Qt's default (light) platform style, not Paradise. Theming it would mean replacing `QsMenuAnchor` with a custom popup built on `QsMenuOpener`, which isn't done here.
- Tag rules take the keyword `tag_rule=` with an underscore: `tag_rule=id:*,layout_name:scroller` passes `mango -p`, and mmsg then reports layout "S" (checked by MangoConfig). Mango 0.18.5 rejects `tagrule=` as an unknown keyword.
