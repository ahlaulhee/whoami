# dwl-0.9-setup: before publishing

- Set `pubDate` to the publish day and confirm every `testedOn` version on the real machine.
- Link dotfiles snippets to a fixed commit, not to `main`.
- Patches: bar, autostart, vanitygaps, alwayscenter, swapfocus, swallow, warpcursor, fullscreenadaptivesync.
- Only document NVIDIA environment variables that fixed something on this machine.
- Fedora 45 runs kmscon on tty1-6 and it holds the DRM device. Check how greetd/dwl coexist with it (`kmscon-launch-gui`, or greetd on its own VT). Source: `notes/research/fedora-45-base.md` §3.
