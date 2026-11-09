# mango-0.18-setup: verify on the real machine

Verified in the Fedora 45 WSL environment on 2026-11-08: Terra install (`mangowm 0.18.5`), source build, `mango -p` on the article's config, headless Mango with two outputs (scroller on all tags, monitor positions, all exec_once programs running), idle options (`idle_inhibit_when_fullscreen` stops swayidle in fullscreen), kew 4.4.2 from Terra (MPRIS identity `kew`, play/pause via playerctl, Paradise theme loads), Quickshell bar rendering under headless Mango including the kew module (see `notes/research/quickshell-bar.md`, `kew.md`). Notes: `notes/research/mango-0.18.md`, `mango-config.md`, `mango-statusbar.md`, `quickshell-bar.md`, `kew.md`.

Only the real machine can confirm:

- `testedOn` versions (driver may be 620.x).
- Monitor names: replace `DP-1`/`DP-2` with `mmsg get all-monitors` output; confirm 144/240 Hz apply.
- NVIDIA: mango#1594 (right edge glitch with a single window at 1440p). Note in the article whether you see it.
- VRR: `vrr_only_fullscreen` + NVIDIA forcing VRR; watch the monitor OSD on the desktop and in a game.
- Swallow (`is_term` foot) and the Steam float rule titles.
- greetd + tuigreet `--cmd mango` with kmscon on the other VTs; `kmscon-launch-gui mango` from a console.
- Bar on real hardware: tags clicks on both monitors, title, kew song, volume/mic scroll and mute, tray icons and menus (e.g. Steam, nm-applet if used).
- kew: `colorMode=2` with the Paradise theme (only the default album-color mode was rendered in the test), covers through sixel in foot, track-change notifications in mako.
- Screen sharing with the wmenu chooser; xdpw 0.8.4 issues #411/#409.
- Idle: fullscreen game with a controller doesn't lock; video on a hidden tag keeps the screen awake (`idle_inhibit_ignore_visible`, untested); Super+Shift+i toggle.
- Keybinds are a proposal carried over from the dwl draft; adjust to yours.
- Screenshots: desktop with the bar, scroller with several windows, kew.
