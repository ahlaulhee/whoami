# dwl v0.9 + 8 dwl-patches on Fedora 45: porting notes (verified 2026-11-08)

Everything below was done for real in WSL `FedoraLinux-45` (Fedora 45, wlroots-devel 0.20.2, fcft-devel 3.3.3, tllist-devel 1.1.0, gcc 16.2.1). dwl-patches checkout: `427130f` (main).

Result: branch `mine` in `/root/work/dwl`, 9 commits on top of tag `v0.9`. Each one builds with `rm -f config.h && make clean && make`: exit 0, **0 compiler warnings** (plain v0.9 also has 0). Exported series: `C:/dev/scratch/ported/0001…0009-*.patch`. I checked that `git am` of all 9 onto a clean `v0.9` worktree applies without conflicts, gives a tree identical to `mine`, and builds.

| # | commit | patch file | applied cleanly? |
|---|--------|-----------|------------------|
| 1 | `f60e70c` config.mk: enable XWayland | (local) | n/a |
| 2 | `f0cbded` Implement dwm bar clone (sewn) | `bar/bar.patch` | **No**: 1 conflict in config.def.h, 10 in dwl.c, plus 1 silent mis-merge |
| 3 | `858ffc9` Applied autostart patch (A Frederick Christensen) | `autostart/autostart_main-5fd19fe.patch` | Yes (`git apply -3`). But the file has no mail header, see §2 |
| 4 | `2555c1b` Implement vanitygaps (Bonicgamer) + squashed "allow gaps in monocle layout if requested" (Leonardo Hernández Hernández) | `vanitygaps/vanitygaps.patch` (2-commit series) | **No** for 1/2 (2 conflicts in config.def.h, 1 in dwl.c). 2/2 was clean |
| 5 | `47519c6` center floating windows (Guido Cella) | `alwayscenter/alwayscenter.patch` | Yes |
| 6 | `7c244c4` warpcursor (Ben Collerson) | `warpcursor/warpcursor.patch` | Yes (3-way auto-merge, offsets only) |
| 7 | `8ccfa79` swapfocus patch (André Desgualdo Pereira) | `swapfocus/swapfocus-0.8.patch` | **No**: 2 trivial conflicts in dwl.c. I also fixed a NULL dereference |
| 8 | `e2e6531` swallow (Nikita Ivanov) | `swallow/swallow-0.8.patch` | **No**: 1 conflict in config.def.h, 7 in dwl.c |
| 9 | `29ea732` fullscreenadaptivesync refactor for d16036e (julmajustus) | `fullscreenadaptivesync/fullscreenadaptivesync-v0.9.patch` | **No**: 1 conflict in config.def.h, 2 in dwl.c (all just adjacency with earlier patches) |

Upstream author and subject are kept on every commit (`git am -3` → resolve → `git am --continue`).

---

## Guide-relevant gotchas (read first)

1. **The bar reads the status text from dwl's *stdin*, not from the `-s` command.** With bar.patch, `dwl -s 'sh -c "echo foo"'` shows nothing in the status area: the `-s` child gets `close(STDIN_FILENO)` and its stdout is not connected to the bar. The right way is `slstatus -s | dwl -s 'your-startup-cmd'`. I confirmed this in the smoke test: the text piped into dwl's stdin is what gets drawn.
2. **autostart's default config.def.h entry runs `wbg /path/to/your/image`.** If you don't have `wbg`, dwl prints `dwl: execvp wbg: No such file or directory` at startup (the child dies, dwl keeps running). Edit `autostart[]` in config.h.
3. **swallow ships an active rule for `foot`** (`isterm=1, noswallow=1`). That is the rule that makes foot the swallowing terminal. Keep it, or change the app_id if you use another terminal.
4. v0.9 checks **both** the level-0 and level-1 keysym of a key (`keymap_get_one_sym_by_level`, commits `f9c644f`/`aa0c165`). So old-style `XKB_KEY_A`/`XKB_KEY_parenright` bindings still work. I converted the patches' new bindings to the v0.9 style anyway (`XKB_KEY_a`, `XKB_KEY_0`, `XKB_KEY_h`…) so they match the rest of config.def.h.

---

## 1. bar/bar.patch: conflicted

Why: the patch targets v0.8-era `main`. Between v0.8 and v0.9, upstream touched every spot the patch changes.

### config.def.h (1 hunk)
- **Cause:** `8f52e96 replicate dwm behavior for snap resize` added `snap` on the line just above the colour block. The bar replaces that block.
- **Resolution:** keep `snap`, take the bar's lines (`bordercolor/focuscolor/urgentcolor` are gone and replaced by `colors[][3]`):
```c
static const unsigned int snap             = 32; /* snap pixel */
static const int showbar                   = 1; /* 0 means no bar */
static const int topbar                    = 1; /* 0 means bottom bar */
static const char *fonts[]                 = {"monospace:size=10"};
static const float rootcolor[]             = COLOR(0x000000ff);
```

### dwl.c
1. **Macros.** Cause: `7fb2024 move util.c to util.h` moved `LENGTH`/`END` into util.h. Resolution: drop the patch's duplicate `LENGTH`/`END`, keep its tag-array-based mask:
   ```c
   #define TAGMASK                 ((1u << LENGTH(tags)) - 1)
   ```
2. **Enums.** Cause: `2f3fe06 add IME support` (LyrIMPopup), `1fe1b4e show popups in fullscreen Xwayland apps` (LyrUnmanaged) and `e8bf70d implement Axis mouse bindings` (Axis enum). Resolution: keep all of upstream's, add the bar's click enum:
   ```c
   enum { LyrBg, LyrBottom, LyrTile, LyrFloat, LyrTop, LyrFS, LyrUnmanaged, LyrOverlay,
   	LyrIMPopup, LyrBlock, NUM_LAYERS }; /* scene layers */
   enum { AxisUp, AxisRight, AxisDown, AxisLeft };
   enum { ClkTagBar, ClkLtSymbol, ClkStatus, ClkTitle, ClkClient, ClkRoot }; /* clicks */
   ```
3. **Silent mis-merge (no conflict marker!).** `e8bf70d` added `typedef struct { mod; dir; func; arg } Axis;` right above `Button`, and the two structs have the same shape. git's 3-way merge put the bar's new `unsigned int click;` into **`Axis`** instead of `Button`. That compiles in neither case. I moved it back by hand: `Axis` stays upstream, and `Button` gets `click` as its first field.
4. **buttonpress() declarations + body (2 hunks).** Cause: `0a6dc6d add support for layer-shell on-demand keyboard interactivity` added `LayerSurface *l` and focus for layer surfaces. Resolution: the bar's hit-test runs first, then v0.9's client/layer focus code runs, gated on `ClkClient`:
   ```c
   	Arg arg = {0};
   	Client *c = NULL;
   	LayerSurface *l = NULL;
   ...
   		if (!c && !exclusive_focus &&
   			(node = wlr_scene_node_at(&layers[LyrBottom]->node, cursor->x, cursor->y, NULL, NULL)) &&
   			(buffer = wlr_scene_buffer_from_node(node)) && buffer == selmon->scene_buffer) {
   			... /* ClkTagBar / ClkLtSymbol / ClkStatus / ClkTitle detection from the patch */
   		}

   		/* Change focus if the button was _pressed_ over a client
   		   or a layer surface with on-demand keyboard interactivity */
   		xytonode(cursor->x, cursor->y, NULL, &c, &l, NULL, NULL);
   		if (click == ClkClient && (!client_is_unmanaged(c) || client_wants_focus(c))) {
   			focusclient(c, 1);
   		} else if (l && l->layer_surface->current.keyboard_interactive) {
   			focusclient(NULL, 0);
   			client_notify_enter(l->layer_surface->surface, wlr_seat_get_keyboard(seat));
   		}
   ```
5. **focusclient() deactivation block.** Cause: `669b26d let the focus leave an unmanaged surface`, `f6e3a28 deactivate the old client when the new one wants focus` and `6013835 keep the focused border color of the old client…` replaced the old `if (old && …) { … }` block with `focused_client` tracking and an exclusive-keyboard-interactivity check. Resolution: keep v0.9's logic verbatim and swap the colour for the bar's scheme:
   ```c
   	if (focused_client && focused_client != c && !(c && client_is_unmanaged(c))) {
   		struct wlr_surface *s = client_surface(focused_client);
   		if (c)
   			client_set_border_color(focused_client, (float[])COLOR(colors[SchemeNorm][ColBorder]));
   		if (s && s->mapped)
   			client_activate_surface(s, 0);
   		focused_client = NULL;
   	}
   	drawbars();
   ```
6. **setup().** Cause: `2f3fe06 add IME support` created the input-method/text-input managers at the same spot. Resolution: both, upstream first:
   ```c
   	input_method_manager = wlr_input_method_manager_v2_create(dpy);
   	text_input_manager = wlr_text_input_manager_v3_create(dpy);
   	input_method_relay = input_method_relay_create();

   	drwl_init();

   	status_event_source = wl_event_loop_add_fd(wl_display_get_event_loop(dpy),
   		STDIN_FILENO, WL_EVENT_READABLE, statusin, NULL);
   ```
7. **unmapnotify().** Cause: `4847f97 Clear surface->data on unmap to fix idle-inhibitor use-after-free`. Resolution: keep the fix, and `printstatus()` → `drawbars()`:
   ```c
   	client_surface(c)->data = NULL;
   	drawbars();
   ```
8. **updatetitle().** Cause: `721f70e implement ext-foreign-toplevel-list` added the foreign-toplevel state update. Resolution: `drawbars()` plus upstream's update block, unchanged.
9. **xytonode() (2 hunks).** Cause: `4c54bd8 implement xytonode() with toplevel_from_wlr_surface()` removed the `pnode` walk and the local `c`/`l`. Resolution: v0.9 structure plus the bar's NULL-safe buffer check. The bar is a plain `wlr_scene_buffer` with no surface. Without this, clicking the bar would dereference NULL:
   ```c
   	struct wlr_scene_surface *scene_surface = NULL;
   ...
   		if (node->type == WLR_SCENE_NODE_BUFFER) {
   			scene_surface = wlr_scene_surface_try_from_buffer(
   					wlr_scene_buffer_from_node(node));
   			if (!scene_surface) continue;
   			surface = scene_surface->surface;
   		}
   ```
   (`toplevel_from_wlr_surface(surface, pc, pl)` stays at the end, as in v0.9.)

Clean auto-merges worth knowing: the Makefile adds `pixman-1 fcft` to `PKGS`, and `drwl.h` is new. `git am` warns about 4 trailing-whitespace lines from the patch itself (in drwl.h and dwl.c); those are cosmetic.

## 2. autostart/autostart_main-5fd19fe.patch: clean

- `5fd19fe` is a v0.9-era upstream commit (`support monitors above and below in focusmon and tagmon`), so the patch applies with no fuzz.
- **The file is a bare `git diff` with no `From:`/`Subject:` header**, so `git am` fails with "Patch format detection failed". I used `git apply -3 --index` and committed with the author/subject from the same author's mail-formatted siblings (`autostart_0.8.patch`, `autostart_wlroots-next-f4249db.patch`): `A Frederick Christensen <dwl@ivories.org>`, "Applied autostart patch".

## 3. vanitygaps/vanitygaps.patch: conflicted (patch 1/2), squashed

The file is a 2-patch series: "Implement vanitygaps" + "allow gaps in monocle layout if requested". I applied both with `git am -3`, then squashed them into one commit. The author and message of patch 1 are kept, and the second patch's subject/author are appended to the message.

- **config.def.h hunk A.** Cause: the bar's colour rework + `snap` (8f52e96), adjacent to where the gap variables go. Resolution:
  ```c
  static const unsigned int snap             = 32; /* snap pixel */
  static const unsigned int gappih           = 10; /* horiz inner gap between windows */
  static const unsigned int gappiv           = 10; /* vert inner gap between windows */
  static const unsigned int gappoh           = 10; /* horiz outer gap between windows and screen edge */
  static const unsigned int gappov           = 10; /* vert outer gap between windows and screen edge */
  static const int showbar                   = 1; /* 0 means no bar */
  ...
  ```
- **config.def.h hunk B (whole keys[] table).** Cause: `f9c644f`/`aa0c165 use modifier-independent key symbols in keybindings` rewrote every line of `keys[]` (`XKB_KEY_C`→`c`, `parenright`→`0`, `less/greater`→`comma/period`, single-key `TAGKEYS`), and the bar added `togglebar`. Resolution: v0.9 table + `togglebar` + the 16 gap bindings, translated to base keysyms (`XKB_KEY_H`→`h`, `XKB_KEY_L`→`l`, `XKB_KEY_Y`→`y`, `XKB_KEY_O`→`o`, `XKB_KEY_parenright`→`0`).
- **dwl.c (1 hunk).** Cause: the bar's globals (`stext`, `status_event_source`, `buffer_impl`) sit right after `consumed[]`, where the patch adds `enablegaps`. Resolution: both:
  ```c
  static int consumed[KEY_MAX + 1];
  static int enablegaps = 1;   /* enables gaps, used by togglegaps */
  ```
- `tile()`/`monocle()` auto-merged, because v0.9 didn't change them.

## 4. alwayscenter/alwayscenter.patch: clean

Two lines in `setmon()`. It targets 2026-01 `main`, whose `setmon()`/`setfullscreen()` match v0.9 (`setfullscreen(c, 0)` → `resize(c, c->prev, 0)`, so the centred `prev` gets used).

## 5. warpcursor/warpcursor.patch: clean (3-way, offsets only)

Old (Jan 2024) but small. `warpcursor()` is called at the end of `arrange()`, and on `lift` in `focusclient()` after the `if (locked) return;` check.

## 6. swapfocus: used `swapfocus-0.8.patch`, conflicted (trivial)

**Which file:** `swapfocus-0.8.patch`. The other one, `swapfocus.patch`, has no mail header and targets a newer `main` where `focusclient(Client *c, LayerSurface *l, int lift)` takes three arguments. v0.9 still has `focusclient(Client *c, int lift)`, which the 0.8 file uses.

- **Hunk 1 (prototypes).** Cause: the bar's `statusin()` prototype sits where `swapfocus()` goes. Resolution: both (`statusin`, then `swapfocus`).
- **Hunk 2 (focusclient).** Cause: `669b26d` added `exclusive_focus` reset at the same spot. Resolution: both:
  ```c
  	if (old_c && old_c == exclusive_focus && client_wants_focus(old_c))
  		exclusive_focus = NULL;

  	/* Capture the client losing focus as the previous client */
  	if (old_c && !client_is_unmanaged(old_c) && old_c != c) {
  		prevclient = old_c;
  	}
  ```
- **Bug fix I added (deviation from upstream patch).** The patch's fallback branch runs when `prevclient` is NULL (no earlier window, or it was destroyed) and does `selmon = prevclient->mon;`. Pressing Mod+s before a second window has ever been focused would segfault dwl. I guarded it and left the rest of the branch alone (it toggles to the previous tagset like Mod+Tab):
  ```c
  	} else {
  		Arg a = {.ui = 0};
  		if (prevclient && prevclient->mon) selmon = prevclient->mon; /* port: patch derefs NULL here */
  		view(&a);
  ```

## 7. swallow/swallow-0.8.patch: conflicted

- **config.def.h.** Cause: the bar's `colors[][3]` block sits where the swallow globals go. Resolution: `enableautoswallow`/`swallowborder` right after `fullscreen_bg`, then `colors`. The `rules[]` change (new `isterm`/`noswallow` columns, foot rule) and the keybindings merged without conflict. I changed `XKB_KEY_A` → `XKB_KEY_a` for v0.9 style.
- **dwl.c macros.** Cause: `7fb2024` (LENGTH/END moved to util.h) and the bar's `TAGMASK`/`TEXTW`. Resolution:
  ```c
  #define VISIBLEON(C, M)         ((M) && (C)->mon == (M) && ((C)->tags & (M)->tagset[(M)->seltags]) && !(C)->swallowedby)
  #define TAGMASK                 ((1u << LENGTH(tags)) - 1)
  ...
  #define TEXTW(mon, text)        (drwl_font_getwidth(mon->drw, text) + mon->lrpad)
  #define BORDERPX(C)             (borderpx + ((C)->swallowing ? (int)ceilf(swallowborder * (C)->swallowing->bw) : 0))
  ```
- **Client struct.** Cause: `e7f185e remove c->resize` deleted the `uint32_t resize` member that is the patch's context line. Resolution: patch fields without `resize`:
  ```c
  	int isfloating, isurgent, isfullscreen;
  	int isterm, noswallow;
  	pid_t pid;
  	Client *swallowing;  /* client being hidden */
  	Client *swallowedby;
  };
  ```
- **pointerfocus prototype.** Cause: `0a6dc6d` added a `LayerSurface* l` parameter. Resolution: `parentpid()` prototype + v0.9 signature.
- **Prototypes/definitions next to statusin/swapfocus/togglegaps (3 hunks).** Cause: adjacency with patches 1, 4 and 6. Resolution: kept everything (`statusin`, `swallow`, `swapfocus`; `togglegaps`, `toggleswallow`, `toggleautoswallow`).
- **Fix I added (deviation).** The patch's autoswallow check in `applyrules()` reads `c->surface.xdg->initial_commit` for every client. For XWayland clients that reads the `xwayland` union member as if it were an xdg surface: undefined behaviour, and swallowing X11 clients works or fails at random. `applyrules()` only runs from `mapnotify()` for X11, so the check simply doesn't apply there:
  ```c
  	if (enableautoswallow && !c->noswallow && !c->isfloating &&
  			(client_is_x11(c) || !c->surface.xdg->initial_commit)) {
  ```

## 8. fullscreenadaptivesync-v0.9.patch: conflicted (adjacency only)

The patch already targets v0.9 (`d16036e` is the last code commit before the v0.9 tag). The 3 conflicts are only with lines added by patches 4 and 8: the `keys[]` line next to swallow's bindings, the prototype next to togglegaps/toggleswallow, and the function definition next to them. I kept everything: the F5 binding sits right after `togglefullscreen`, and `togglefullscreenadaptivesync()` comes before `togglegaps()`. The patch's whitespace cleanups in `setup()` (spaces → tabs on `wlr_xdg_output_manager_v1_create` and `virtual_pointer` lines) applied as-is.

---

## config.def.h options added, per patch

| patch | options (default) | bindings added |
|---|---|---|
| XWayland (config.mk) | `XWAYLAND = -DXWAYLAND`, `XLIBS = xcb xcb-icccm` | — |
| bar | `showbar = 1`, `topbar = 1`, `fonts[] = {"monospace:size=10"}`, `rootcolor` → `0x000000ff`, `colors[][3]` (`SchemeNorm {0xbbbbbbff,0x222222ff,0x444444ff}`, `SchemeSel {0xeeeeeeff,0x005577ff,0x005577ff}`, `SchemeUrg {0,0,0x770000ff}`) replaces `bordercolor/focuscolor/urgentcolor`; `tags[] = {"1".."9"}` replaces `#define TAGCOUNT (9)`; `Button` gains a click field | `Mod+b` togglebar. Mouse: `ClkLtSymbol` L/R → tile/monocle; `ClkTitle` M → zoom; `ClkStatus` M → spawn termcmd; `ClkClient` Mod+L/M/R → move/togglefloating/resize; `ClkTagBar` L view, R toggleview, Mod+L tag, Mod+R toggletag |
| autostart | `autostart[] = { "wbg", "/path/to/your/image", NULL, NULL }` | — |
| vanitygaps | `smartgaps = 0`, `monoclegaps = 0`, `gappih = gappiv = gappoh = gappov = 10` | `Mod+Super+h/l` incgaps ±1; `Mod+Super+Shift+h/l` incogaps; `Mod+Super+Ctrl+h/l` incigaps; `Mod+Super+0` togglegaps; `Mod+Super+Shift+0` defaultgaps; `Mod+y/o` incihgaps; `Mod+Ctrl+y/o` incivgaps; `Mod+Super+y/o` incohgaps; `Mod+Shift+y/o` incovgaps |
| alwayscenter | none | — |
| warpcursor | none | — |
| swapfocus | none | `Mod+s` swapfocus |
| swallow | `enableautoswallow = 1`, `swallowborder = 1.0f`; `Rule` gains `isterm`, `noswallow` (rule `{ "foot", NULL, 0, 0, 1, 1, -1 }` added) | `Mod+a` toggleswallow, `Mod+Shift+a` toggleautoswallow |
| fullscreenadaptivesync | none (runtime toggle `fullscreen_adaptive_sync_enabled = 1` lives in dwl.c) | `Mod+F5` togglefullscreenadaptivesync |

(`Mod` = `MODKEY` = Alt by default; `Super` = `WLR_MODIFIER_LOGO`.) **If the guide sets `MODKEY` to `WLR_MODIFIER_LOGO`**, `MODKEY|WLR_MODIFIER_LOGO` becomes plain Super, so the vanitygaps bindings collide with the stock ones. `keybinding()` returns the first match in `keys[]`, which gives this in the current order: `Super+h/l` → setmfact (incgaps unreachable); `Super+y/o` → incihgaps (incohgaps unreachable); `Super+0` → **togglegaps instead of view-all**; `Super+Shift+0` → **defaultgaps instead of tag-all**. The guide author has to rebind the gap keys in config.h. [INFERENCE from reading `keybinding()` and the `keys[]` order; not run-tested.]

## New warnings

None. All 10 builds (v0.9 baseline + each of the 9 commits) print 0 `warning:` lines with dwl's default `-Wall -Wextra -Wpedantic …` flags. The only messages are `git am` whitespace warnings from the patch files themselves (bar: 4 lines, swapfocus: 3 lines).

## Fedora 45 packages

Build (dwl + bar + XWayland), with the pkg-config module each provides:
```
sudo dnf install gcc make git pkgconf-pkg-config \
  wlroots-devel wayland-devel wayland-protocols-devel \
  libinput-devel libxkbcommon-devel pixman-devel \
  fcft-devel tllist-devel \
  libxcb-devel xcb-util-wm-devel \
  libX11-devel
```
- `wayland-server`/`wayland-scanner` → wayland-devel; `wayland-protocols` → wayland-protocols-devel; `xkbcommon` → libxkbcommon-devel; `libinput` → libinput-devel; `pixman-1` → pixman-devel; `wlroots-0.20` → wlroots-devel (0.20.2)
- bar: `fcft` → fcft-devel, `tllist` → tllist-devel (header-only, needed by fcft's headers)
- XWayland build: `xcb` → libxcb-devel, `xcb-icccm` → xcb-util-wm-devel
- slstatus: `libX11-devel` (Xlib.h + libX11; also pulls libxcb/libXau at runtime)

Runtime (not needed to compile): `xorg-x11-server-Xwayland` (XWayland clients), any monospace font (fontconfig matched `adwaita-mono-fonts` here). Smoke test only: `grim`, `foot`.

I installed **no extra packages** for this task. Everything above (including grim, foot, Xwayland) was already installed by earlier setup (dnf history transactions 3 and 5).

## slstatus

`git clone https://git.suckless.org/slstatus` (HEAD `675c839 fix getnameinfo sockaddr size for IPv4`), `make`: builds clean (config.mk's `/usr/X11R6` include/lib paths don't exist on Fedora, but Xlib is found in the default paths). `./slstatus -s -1` printed one line and exited 0:
```
2026-11-08 12:25:17
```
(default config.def.h only has `{ datetime, "%s", "%F %T" }`). Needs only gcc, make and libX11-devel. With `-s`, slstatus writes to stdout and never opens an X display, so it works under dwl without XWayland running.

## Smoke test

Headless works. Command (in WSL, WSLg variables unset):
```
XDG_RUNTIME_DIR=/tmp/xdg WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_HEADLESS_OUTPUTS=1 WLR_LIBINPUT_NO_DEVICES=1 \
  sh -c '(echo "status-ok $(date +%H:%M:%S)"; sleep 6) | timeout 10 ./dwl -s "sleep 2; grim /tmp/smoke.png"'
```
- `grim` ran as dwl's startup child (gets dwl's `WAYLAND_DISPLAY=wayland-0`), exit 0, 1280×720 PNG → `C:/dev/scratch/ported/smoke.png`. The bar is drawn at the top: tags 1–9 with tag 1 selected (#005577), layout symbol `[]=`, and the status `status-ok 12:24:08` on the right. That status text came from dwl's stdin.
- In this run XWayland failed with `/tmp/.X11-unix is not a directory`. That is a WSL artefact: WSLg makes `/tmp/.X11-unix` a symlink to `/mnt/wslg/.X11-unix`. It has nothing to do with dwl.
- Second run in a private mount namespace (`unshare -m`, tmpfs on `/tmp`) with `foot &` and `xprop -root` as the startup command: XWayland came up (`DISPLAY=:0`, xprop exit 0). foot was tiled with the 10 px vanitygaps, and the bar showed the focused title `foot` in SchemeSel. Screenshot → `C:/dev/scratch/ported/smoke-xwayland-foot.png`.
- `exit=124` in both runs only means `timeout` killed dwl as planned. dwl does not exit on stdin EOF.
