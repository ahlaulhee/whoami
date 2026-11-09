# kew 4.4.2 (Terra) research notes — 2026-11-08

Upstream: https://github.com/ravachol/kew (the RPM's URL field points to https://codeberg.org/ravachol/kew), site https://kewplayer.com.
Everything below was observed on the installed package in WSL FedoraLinux-45 unless marked [INFERENCE].

## Install
`sudo dnf install kew` installs `kew-4.4.2-1.fc45` from Terra, pulling in taglib and opusfile.
For testing I also installed: `playerctl ffmpeg-free pipewire wireplumber pipewire-pulseaudio tmux grim` (most were already present).
Package files: `/usr/bin/kew`, `/usr/share/kew/themes/*.theme` + `THEMES-HOWTO.md`, `/usr/share/kew/layouts/`, `kew.desktop`.
Linked libs include libchafa (cover rendering), libgio (D-Bus/MPRIS), opus, vorbis. There is no libnotify; notifications presumably go over D-Bus via gio [INFERENCE].

## Music library
- On first start with an empty `path=`, kew shows a prompt: "Music Library: ~/Music  Is this correct? Press Enter. Or type a path". So the default is ~/Music.
- Config key: `path=` under `[miscellaneous]` in kewrc. `kew path <dir>` sets it, and that is the only time kew writes to kewrc.
- `kew <name>` plays a matching folder, artist or song, e.g. `kew Paradise`.

## Config
- `~/.config/kew/kewrc`, INI-style (`[section]`, `key=value`, `#` comments). It is generated on first run with every setting and its comment. The header says that changes made inside the app go to `kewstaterc`, which takes precedence over kewrc.
- Themes go in `~/.config/kew/themes/` (kew copies the bundled themes there on first run; layouts go to `~/.config/kew/layouts/`).
- The article only needs these:
```ini
[miscellaneous]
path=~/Music          # or leave empty and confirm the first-run prompt
[colors]
theme=paradise
colorMode=2          # 2 = colours from the TrueColor theme; the generated default is 3 = album colours
```
I tested with `theme=paradise` set and the default colorMode=3; the track view rendered fine. The colorMode=2 line comes from the kewrc comment ("2 = Colors derived from TrueColor theme"). The `i` key cycles colour modes at runtime.
- Other useful keys: `allowNotifications=1` (desktop notification on track change, on by default), `coverStyle=auto` (choices: auto, kitty, sixels, block, braille, ascii, dot, vhalf, quad), `coverEnabled=1`.

## Theme
Format: `[theme]` section plus `name=` and keys such as `accent`, `text`, `textMuted`, `header`, `footer`, `nowplaying`, `playlist.*`, `trackview.*`, `library.*`, `search.*`, `progress.*`, `status.*`. Values can be `#rrggbb`, an ANSI index 0–15, `-1` (terminal fg), or 101–104 (album colours). Docs: `/usr/share/kew/themes/THEMES-HOWTO.md`.
Paradise theme: `C:/dev/scratch-kew/paradise.theme`, installed as `~/.config/kew/themes/paradise.theme`. kew loaded it with no errors.

## Key bindings (from the generated kewrc `[key bindings]`, format `bind = Key, action`)
| Key | Action |
|---|---|
| Space / p | play/pause |
| l / → , h / ← | next / previous track |
| + / - | volume ±5 % |
| F2 / F3 / F4 / F5 / F6 | playlist / library / track / search / help |
| Tab | next view |
| Enter / Alt+Enter | expand folder / enqueue and play |
| a / d | seek back / forward |
| s, r | shuffle, repeat |
| q / Esc | quit |

## MPRIS (verified)
Setup: user session under `dbus-run-session` with pipewire + wireplumber, and kew running in tmux (`kew Paradise`). The test file was a 2-minute 440 Hz FLAC made with `ffmpeg -f lavfi -i sine=...` and tagged artist="Test Artist", title="Sine Wave".
- `busctl --user list` shows `org.mpris.MediaPlayer2.kew` (process kew).
- `Identity` = `'kew'`.
- `Metadata`: `xesam:title 'Sine Wave'`, `xesam:artist ['Test Artist']`, `xesam:album`, `xesam:url file://…`, `mpris:length 120000000`, `mpris:trackid /org/kew/Track/t1`. `mpris:artUrl` is empty when there is no cover.
- `PlaybackStatus` = `'Playing'`. `playerctl -l` lists `kew`.
- `playerctl -p kew play-pause` changes Playing → Paused → Playing; checked with `playerctl status`.
kew has MPRIS built in, so it needs no mpDris2-style bridge.

## Bar (`C:/dev/scratch-kew/shell.qml`)
Copied from `public/files/mango-0.18/shell.qml`. The changes: the property `mpd` is now `music`, it matches `p.identity === "kew"`, the comment reads "kew's built-in MPRIS server", and "Right: MPD, …" became "Right: music, …". Nothing else changed.
Checked in headless Mango (qs 0.3.2, software backend) with kew playing:
- `C:/dev/scratch-kew/bar.png` shows `▶ Test Artist - Sine Wave`.
- `bar-paused.png`, taken after `playerctl -p kew pause`, shows `‖ Test Artist - Sine Wave` in the muted colour.
The vol/mic widgets don't appear in the harness because it has no audio devices. This setup issue isn't caused by the change.

## Album art / foot
- kew draws covers with chafa. `coverStyle=auto` picks kitty, sixels or a character mode. The README says "Full color covers in sixel-capable terminals".
- foot supports Sixel (since 1.2.0, https://codeberg.org/dnkl/foot/src/branch/master/CHANGELOG.md) but not the kitty graphics protocol, so in foot kew uses sixels. I did not check this visually; the test used tmux in a headless pty, where kew drew no cover.
- Notifications: `allowNotifications=1` is the default, so a notification daemon (mako etc.) shows track changes [INFERENCE: not tested].
