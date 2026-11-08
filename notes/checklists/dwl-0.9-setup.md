# dwl-0.9-setup: before publishing

Verified in a Fedora 45 WSL build environment on 2026-11-08: build dependencies, subtree + `git am --directory=dwl` with the hosted mbox, `config.h` below, slstatus build, Stow layout, `foot --check-config`, and a headless run of dwl with slstatus, autostart (kanshi, swaybg, mako, polkit agent, cliphist, swayidle), foot and a mako notification. Not verifiable there: real monitors, NVIDIA, greetd/kmscon on a real VT, XWayland/Steam, screen sharing.

On the real machine:

- Set `pubDate` and confirm every `testedOn` version (driver may be 620.x after updates).
- Keybinds and `config.h` choices are a proposal (Super as MODKEY, the extra bindings table, Paradise colors, `swaybg -c 151515`, 600 s idle lock). Replace with your own and update the article's snippets and table.
- Keyboard layout: `xkb_rules` is left at the default (us). Add `.layout = "..."` if you use another layout, and mention it.
- Run `wlr-randr` and put the real output names in the kanshi config (the article shows DP-1/DP-2).
- NVIDIA section: record which (if any) WLR_* variables you needed and say so in the article.
- greetd: confirm tuigreet on tty1 and dwl start correctly with kmscon on the other VTs; confirm `kmscon-launch-gui dwl-session` works from a console.
- Screen sharing: test in a browser that the wlr portal shows up (Fedora's `wlroots-portals.conf` is relied upon).
- VRR on NVIDIA: watch the monitor OSD refresh counter on the desktop and in a fullscreen game; report what the driver does (it forces VRR by default per the 615 README).
- Portal override: confirm a GTK/libadwaita app follows dark mode with `Settings=gtk`.
- Screen sharing: xdpw 0.8.4 has open NVIDIA issues (#411 freeze after first frame, #409); test OBS/Discord/browser and mention if hit.
- Font: Maple Mono 7.9 TTF verified in WSL (checksum, fontconfig name, bar/foot/mako render; foot shows the cursive italic but no ligatures). Confirm the size (11 bar/menu, 12 foot) on your 1440p/1080p screens.
- wlopm: confirm monitors turn off after 15 min and come back on input.
- Steam: confirm it starts under XWayland, and test one game with fullscreenadaptivesync (Super+F5) and the gamescope line.
- Once a dotfiles repo exists, link the article's snippets to a fixed commit and consider pointing the patch downloads at it.
- Hosted patches: `public/files/dwl-0.9/` (GPL-3.0, from dwl-patches, ported to v0.9). Porting details: `notes/research/dwl-0.9-patches.md`.
- Screenshots next to the article: the desktop with the bar, tuigreet, a notification.
- Then set `draft: false`.
