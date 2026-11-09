# Colorschemes similar to Paradise and Vague: research notes — 2026-11-09

Goal: find lesser-known dark palettes close to Paradise (used by dwl, mango, foot, mako, swaylock, wmenu, Quickshell, kew, zathura, tmux) and Vague (Neovim), to pick one scheme for everything. Research only: no article, dotfile or site change.
Image: `notes/research/colorschemes.png` (swatches for 10 roles + the same JavaScript snippet in each theme's own syntax colors).

## Rules agreed with the user
- Dark variants only. Excluded as too well known: Gruvbox, Catppuccin, Tokyo Night, Rosé Pine, Nord, Everforest, Kanagawa and all its variants/derivatives, Oxocarbon, Mellow, Nightfox family. Own repos must have < 1000 GitHub stars. Palettes that only live in collections (iTerm2-Color-Schemes, Gogh, tinted-theming, NvChad base46) are allowed.
- A Neovim port is not required (we can port it); it is recorded.
- A candidate must meet at least 3 of 4 criteria. Thresholds (OKLab / WCAG), tuned so Paradise and Vague both pass all four:
  - neutral background: OKLab L 0.12–0.26 and chroma < 0.005 (Paradise 0.196/0, Vague 0.192/0.002)
  - muted accents: mean OKLab chroma of red..cyan ≤ 0.095 (Paradise 0.060, Vague 0.087)
  - soft foreground: fg OKLab L ≤ 0.935 (Paradise 0.920, Vague 0.848)
  - medium-low contrast: WCAG fg/bg ≤ 15.5 (Paradise 14.4, Vague 11.6)
- ΔE = mean OKLab Euclidean distance ×100 over the 10 roles bg, fg, muted, border, red, green, yellow, blue, magenta, cyan, against Paradise (P) and Vague (V). Sorted by the smaller of the two.
- Role mapping when a theme has no role by that name: muted ← comment / dim fg, border ← bright0 / selection / window separator. Mapped roles have a dashed outline in the image and are listed per theme below.

## Reference palettes
| role | Paradise | Vague |
|---|---|---|
| bg | `#151515` | `#141415` |
| fg | `#e8e3e3` | `#cdcdcd` |
| muted | `#a39d9d` | `#606079` |
| border | `#424242` | `#252530` |
| red | `#b66467` | `#d8647e` |
| green | `#8c977d` | `#7fa563` |
| yellow | `#d9bc8c` | `#f3be7c` |
| blue | `#8da3b9` | `#6e94b2` |
| magenta | `#a988b0` | `#bb9dbd` |
| cyan | `#8aa6a2` | `#aeaed1` |

- Paradise: core set used in the articles (see `src/styles/global.css`); syntax from `src/themes/paradise.json` (keyword `#a988b0`, string `#8c977d`, function `#8da3b9`, number/type `#d9bc8c`, comment `#424242`, variable `#b66467`).
- Vague: `lua/vague/config/internal.lua` + `lua/vague/terminal.lua` at vague.nvim commit `73f8aaa`. Accent roles follow its terminal mapping (red=error, green=plus, yellow=warning, blue=keyword, magenta=parameter, cyan=constant); muted = comment `#606079`, border = line `#252530` (both mapped).

## Candidates (sorted by min ΔE)
| # | theme | where | stars | last commit | Neovim | criteria | ΔE P | ΔE V |
|---|---|---|---|---|---|---|---|---|
| 1 | [No Clown Fiesta](https://github.com/aktersnurra/no-clown-fiesta.nvim) (dark) | repo | 434 | 2025-09-29 | yes | 4/4 | 3.8 | 7.4 |
| 2 | [Tinta](https://github.com/Teshre/ocote-themes) (base16 dark) | tinted-theming | 1 | 2026-06-17 | yes | 4/4 | 6.6 | 4.4 |
| 3 | [Chinoiserie Morandi](https://github.com/stonebuddha/base16-chinoiserie-scheme) (base16 dark) | tinted-theming | 1 | 2025-09-11 | yes | 4/4 | 5.3 | 6.5 |
| 4 | [Luna](https://github.com/WTFox/luna.nvim) (luna (dark)) | repo | 167 | 2026-08-25 | yes | 3/4 (fails low contrast) | 5.8 | 8.8 |
| 5 | [Analog Heartbeat](https://github.com/mbadolato/iTerm2-Color-Schemes/blob/master/ghostty/Analog%20Heartbeat) (dark) | iTerm2-Color-Schemes | — | 2026-10-27 | no | 3/4 (fails neutral bg) | 6.0 | 6.4 |
| 6 | [Chocolate](https://github.com/NvChad/base46/blob/v3.0/lua/base46/themes/chocolate.lua) (dark) | base46 | — | 2024-01-19 | yes | 4/4 | 7.2 | 6.1 |
| 7 | [Oldworld](https://github.com/dgox16/oldworld.nvim) (default) | repo | 482 | 2025-12-30 | yes | 4/4 | 6.4 | 6.2 |
| 8 | [Melange](https://github.com/savq/melange-nvim) (dark) | repo | 991 | 2025-06-16 | yes | 3/4 (fails neutral bg) | 6.6 | 11.5 |
| 9 | [Ashes](https://github.com/NvChad/base46/blob/v3.0/lua/base46/themes/ashes.lua) (dark) | base46 | — | 2023-02-27 | yes | 3/4 (fails neutral bg) | 9.2 | 6.6 |
| 10 | [Mountain](https://github.com/mountain-theme/Mountain) (base16 dark) | tinted-theming (palette), repo | 391 | 2026-07-18 | yes | 4/4 | 9.1 | 6.8 |
| 11 | [Shadow](https://github.com/rjshkhr/shadow.nvim) (dark) | repo | 80 | 2025-02-28 | yes | 3/4 (fails neutral bg) | 7.4 | 6.9 |
| 12 | [Rasmus](https://github.com/kvrohit/rasmus.nvim) (dark) | repo | 219 | 2024-11-12 | yes | 4/4 | 6.9 | 9.2 |

Near-monochrome (contrast entries):
| theme | stars | last commit | Neovim | ΔE P | ΔE V |
|---|---|---|---|---|---|
| [Ashen](https://github.com/ficd0/ashen.nvim) | 185 | 2025-07-13 | yes | 7.6 | 8.4 |
| [Lackluster](https://github.com/slugbyte/lackluster.nvim) | 584 | 2025-10-06 | yes | 8.0 | 11.6 |

## Per theme
### No Clown Fiesta (dark)
- Source of hex: https://raw.githubusercontent.com/aktersnurra/no-clown-fiesta.nvim/master/lua/no-clown-fiesta/palettes.lua ; https://raw.githubusercontent.com/aktersnurra/no-clown-fiesta.nvim/master/lua/no-clown-fiesta/groups/highlights.lua ; https://raw.githubusercontent.com/aktersnurra/no-clown-fiesta.nvim/master/lua/no-clown-fiesta/groups/treesitter.lua ; https://raw.githubusercontent.com/no-clown-fiesta/no-clown-fiesta.kitty/master/colors.conf
- Neovim: https://github.com/aktersnurra/no-clown-fiesta.nvim
- Roles: bg `#151515`, fg `#e1e1e1`, muted `#afafaf`, border `#373737`, red `#b46958`, green `#90a959`, yellow `#f4bf75`, blue `#7e97ab`, magenta `#aa759f`, cyan `#88afa2`
- Mapped roles: muted: palette light_gray (comment is medium_gray #727272); border: palette gray; blue: palette gray_blue (palette 'blue' is pale #BAD7FF; medium_gray_blue #A2B5C1 used for strings)
- Terminal 0–15: `#202020` `#ac4142` `#88afa2` `#f4bf75` `#73c0ff` `#aa759f` `#5f9ea0` `#d0d0d0` `#555555` `#cd5c5c` `#90a959` `#ffdead` `#a5d6ff` `#cf75bc` `#75b5aa` `#e1e1e1`
- Notes: by aktersnurra; 'a dark gray colorscheme' with identical bg #151515 to Paradise; syntax mostly greys + grey-blue, few accents. Variants dark/dim/light. Ports in no-clown-fiesta org: kitty, iterm, zathura, emacs, vscode (terminal16 from kitty port is more saturated than nvim palette).

### Tinta (base16 dark)
- Source of hex: https://raw.githubusercontent.com/tinted-theming/schemes/main/base16/tinta.yaml
- Neovim: https://github.com/tinted-theming/tinted-vim (colorscheme `base16-tinta`)
- Roles: bg `#101012`, fg `#d8d6d0`, muted `#62626a`, border `#2c2c30`, red `#d0726a`, green `#9aa890`, yellow `#c8b86a`, blue `#8a9ab0`, magenta `#b0a0b8`, cyan `#80b8b4`
- Mapped roles: muted: base03 (comments); border: base02 (selection)
- Terminal 0–15: `#101012` `#d0726a` `#9aa890` `#c8b86a` `#8a9ab0` `#b0a0b8` `#80b8b4` `#d8d6d0` `#62626a` `#d0726a` `#9aa890` `#c8b86a` `#8a9ab0` `#b0a0b8` `#80b8b4` `#eeece6`
- Notes: Teshre, parte de ocote-themes (8 paletas base16). En tinted-theming y Gogh.

### Chinoiserie Morandi (base16 dark)
- Source of hex: https://raw.githubusercontent.com/tinted-theming/schemes/main/base16/chinoiserie-morandi.yaml
- Neovim: https://github.com/tinted-theming/tinted-vim (colorscheme `base16-chinoiserie-morandi`)
- Roles: bg `#1d1d1d`, fg `#c4cbcf`, muted `#918072`, border `#373737`, red `#c06061`, green `#8ca07b`, yellow `#e5bc84`, blue `#839ec9`, magenta `#98a1d8`, cyan `#5e8c9b`
- Mapped roles: muted: base03 (comments); border: base02 (selection)
- Terminal 0–15: `#1d1d1d` `#c06061` `#8ca07b` `#e5bc84` `#839ec9` `#98a1d8` `#5e8c9b` `#c4cbcf` `#918072` `#c06061` `#8ca07b` `#e5bc84` `#839ec9` `#98a1d8` `#5e8c9b` `#fffef9`
- Notes: Di Wang (CMU); variante de Tomorrow con colores tradicionales chinos estilo Morandi. En tinted-theming y Gogh.

### Luna (luna (dark))
- Source of hex: https://raw.githubusercontent.com/WTFox/luna.nvim/main/lua/luna/palette.lua ; https://raw.githubusercontent.com/WTFox/luna.nvim/main/extras/kitty/luna.conf ; https://raw.githubusercontent.com/WTFox/luna.nvim/main/lua/luna/groups/syntax.lua ; https://raw.githubusercontent.com/WTFox/luna.nvim/main/lua/luna/groups/treesitter.lua
- Neovim: https://github.com/WTFox/luna.nvim
- Roles: bg `#060606`, fg `#e4e4e8`, muted `#a8a8a8`, border `#404040`, red `#e08585`, green `#9eb38e`, yellow `#d9a35a`, blue `#75a1c7`, magenta `#c4a8d6`, cyan `#8c9cb8`
- Mapped roles: muted: grey_light (operators/punctuation; comment is #7c7c7c); border: palette border; red: diag 'error'; green: syntax 'string' (terminal green is 'ok' #6fbe80); yellow: diag 'warning'; blue: syntax 'func'; magenta: syntax 'type'; cyan: diag 'info' (no cyan in palette; kitty color6 reuses func #75a1c7)
- Terminal 0–15: `#000000` `#e08585` `#6fbe80` `#c2916a` `#75a1c7` `#c4a8d6` `#75a1c7` `#c7c7c7` `#888888` `#e08585` `#6fbe80` `#d9a35a` `#8c9cb8` `#c4a8d6` `#75a1c7` `#ffffff`
- Notes: by WTFox (also author of jellybeans.nvim); 'near-black colorscheme built on greys, with four accent hues and nothing else'. Accent set (orange keyword, steel-blue func, lavender type, sage string) is close to Vague. bg #060606 is darker than Paradise; contrast is intentionally high (6.9-9:1). Has 'accent' option (0-1) to desaturate syntax toward grey. Extras: alacritty, ghostty, kitty.

### Analog Heartbeat (dark)
- Source of hex: https://raw.githubusercontent.com/mbadolato/iTerm2-Color-Schemes/master/ghostty/Analog%20Heartbeat
- Neovim: none (port needed)
- Roles: bg `#211f1c`, fg `#e6ddcb`, muted `#62594d`, border `#454034`, red `#c96f64`, green `#94b26a`, yellow `#d9ac63`, blue `#839eb2`, magenta `#b28da1`, cyan `#7eafa5`
- Mapped roles: muted: ANSI 8 (no comment/fg-dim role in terminal scheme); border: selection-background; red..cyan: ANSI 1-6
- Terminal 0–15: `#302c27` `#c96f64` `#94b26a` `#d9ac63` `#839eb2` `#b28da1` `#7eafa5` `#d6cbb8` `#62594d` `#e57b73` `#b7d36b` `#f2c87b` `#a8c4d6` `#d0a9bd` `#a1d4c5` `#fff0d6`
- No syntax colors in source (terminal-only); the image maps keyword=magenta, string=green, function=blue, number=yellow, type=cyan, comment=bright0.
- Notes: Recent (2026) terminal scheme in iTerm2-Color-Schemes; warm brown-black bg #211f1c (fails strict neutral), cream fg, muted brick/olive/amber/steel accents. All terminal formats available in the collection.

### Chocolate (dark)
- Source of hex: https://raw.githubusercontent.com/NvChad/base46/v3.0/lua/base46/themes/chocolate.lua ; https://raw.githubusercontent.com/NvChad/base46/v3.0/lua/base46/integrations/syntax.lua ; https://raw.githubusercontent.com/NvChad/base46/v3.0/lua/base46/integrations/treesitter.lua ; https://raw.githubusercontent.com/NvChad/base46/v3.0/lua/base46/integrations/defaults.lua (Comment=grey_fg) ; https://raw.githubusercontent.com/NvChad/base46/v3.0/lua/base46/term.lua (terminal map)
- Neovim: https://github.com/NvChad/base46
- Roles: bg `#252221`, fg `#cdc0ad`, muted `#575453`, border `#322f2e`, red `#c65f5f`, green `#8ca589`, yellow `#d9b27c`, blue `#7d92a2`, magenta `#998396`, cyan `#829e9b`
- Mapped roles: muted: base_30.grey_fg (comment color); border: base_30.line (window separator)
- Terminal 0–15: `#2b2827` `#c65f5f` `#8ca589` `#d9b27c` `#7d92a2` `#c65f5f` `#998396` `#c8baa4` `#393635` `#c65f5f` `#8ca589` `#d9b27c` `#7d92a2` `#c65f5f` `#998396` `#cdc0ad`
- Notes: base46 modified port of snakedye's 'chocolate' (gitlab.com/snakedye/chocolate, a Wayland ricer palette). Warm-tinted, slightly lighter bg (#252221) fails neutral bg; accents very close in mood to Paradise (#c65f5f/#8ca589/#d9b27c/#7d92a2).

### Oldworld (default)
- Source of hex: https://raw.githubusercontent.com/dgox16/oldworld.nvim/main/lua/oldworld/variants.lua ; https://raw.githubusercontent.com/dgox16/oldworld.nvim/main/extras/kitty/oldworld.conf ; https://raw.githubusercontent.com/dgox16/oldworld.nvim/main/lua/oldworld/groups/syntax.lua ; https://raw.githubusercontent.com/dgox16/oldworld.nvim/main/lua/oldworld/groups/integrations/treesitter.lua
- Neovim: https://github.com/dgox16/oldworld.nvim
- Roles: bg `#161617`, fg `#c9c7cd`, muted `#8b8693`, border `#353539`, red `#ea83a5`, green `#90b99f`, yellow `#e6b99d`, blue `#92a2d5`, magenta `#aca1cf`, cyan `#85b5ba`
- Mapped roles: muted: subtext3 (Comment color); border: kitty color8 / bright0
- Terminal 0–15: `#27272a` `#ea83a5` `#90b99f` `#e6b99d` `#9ca2cf` `#aca1cf` `#85b5ba` `#c9c7cd` `#353539` `#ed96b3` `#a7c8b3` `#eac5ae` `#acb1d7` `#b7aed5` `#97c0c4` `#d3d1d7`
- Notes: by dgox16; 'dark theme with relaxing, non-saturated colors'. Variants default/cooler/oled. Extras: alacritty, kitty, ghostty, iterm2, windows-terminal, zathura, waybar, cava. Pastel accents slightly more saturated than Paradise (pink red).

### Melange (dark)
- Source of hex: https://raw.githubusercontent.com/savq/melange-nvim/master/lua/melange/palettes/dark.lua ; https://raw.githubusercontent.com/savq/melange-nvim/master/colors/melange.lua ; https://raw.githubusercontent.com/savq/melange-nvim/master/term/kitty/melange_dark.conf
- Neovim: https://github.com/savq/melange-nvim
- Roles: bg `#292522`, fg `#ece1d7`, muted `#c1a78e`, border `#867462`, red `#bd8183`, green `#78997a`, yellow `#e49b5d`, blue `#7f91b2`, magenta `#b380b0`, cyan `#7b9695`
- Mapped roles: muted: a.com (Comment color); border: a.ui (WinSeparator / bright0); accents: group c (normal-intensity) palette; group b holds the brighter set
- Terminal 0–15: `#34302c` `#bd8183` `#78997a` `#e49b5d` `#7f91b2` `#b380b0` `#7b9695` `#c1a78e` `#867462` `#d47766` `#85b695` `#ebc06d` `#a3a9ce` `#cf9bc2` `#89b3b6` `#ece1d7`
- Notes: by savq; 'warm color scheme for Neovim and beyond'. Accent set c is strikingly close to Paradise (dusty rose/sage/slate/mauve) but bg is warm brown #292522, not neutral. 991 stars (just under the 1000 cap). Terminal ports: alacritty, foot, ghostty, kitty, wezterm etc. keyword = Statement; punctuation = @punctuation.delimiter (brackets use Delimiter #8B7449).

### Ashes (dark)
- Source of hex: https://raw.githubusercontent.com/NvChad/base46/v3.0/lua/base46/themes/ashes.lua ; https://raw.githubusercontent.com/NvChad/base46/v3.0/lua/base46/integrations/syntax.lua ; https://raw.githubusercontent.com/NvChad/base46/v3.0/lua/base46/integrations/treesitter.lua ; https://raw.githubusercontent.com/NvChad/base46/v3.0/lua/base46/integrations/defaults.lua (Comment=grey_fg) ; https://raw.githubusercontent.com/NvChad/base46/v3.0/lua/base46/term.lua (terminal map)
- Neovim: https://github.com/NvChad/base46
- Roles: bg `#1c2023`, fg `#c7ccd1`, muted `#4a4e51`, border `#303437`, red `#c79595`, green `#aec795`, yellow `#c7c795`, blue `#95aec7`, magenta `#ae95c7`, cyan `#9eb7d0`
- Mapped roles: muted: base_30.grey_fg (comment color); border: base_30.line (window separator)
- Terminal 0–15: `#272b2e` `#c7ae95` `#95c7ae` `#aec795` `#ae95c7` `#c795ae` `#95aec7` `#c7ccd1` `#44484b` `#c7ae95` `#95c7ae` `#aec795` `#ae95c7` `#c795ae` `#95aec7` `#f3f4f5`
- Notes: base46 port of base16 'Ashes' (Jannik Siebert, via chriskempson/base16-vim). Uniformly desaturated pastel accents (all S~0.3), soft fg; bg #1c2023 has a mild cool slate tint. Base16 ports exist for most terminals via tinted-theming.

### Mountain (base16 dark)
- Source of hex: https://raw.githubusercontent.com/tinted-theming/schemes/main/base16/mountain.yaml
- Neovim: https://github.com/mountain-theme/Mountain/tree/master/vim
- Roles: bg `#0f0f0f`, fg `#cacaca`, muted `#393939`, border `#262626`, red `#ac8a8c`, green `#8aac8b`, yellow `#aca98a`, blue `#8f8aac`, magenta `#ac8aac`, cyan `#8aabac`
- Mapped roles: muted: base03 (comments); border: base02 (selection)
- Terminal 0–15: `#0f0f0f` `#ac8a8c` `#8aac8b` `#aca98a` `#8f8aac` `#ac8aac` `#8aabac` `#cacaca` `#393939` `#ac8a8c` `#8aac8b` `#aca98a` `#8f8aac` `#ac8aac` `#8aabac` `#f0f0f0`
- Notes: Paleta base16 de gnsfujiwara (autor de Mountain). La variante Fuji del repo usa fg #f0f0f0 y queda fuera por contraste.

### Shadow (dark)
- Source of hex: https://raw.githubusercontent.com/rjshkhr/shadow.nvim/main/lua/shadow/init.lua
- Neovim: https://github.com/rjshkhr/shadow.nvim
- Roles: bg `#1d2326`, fg `#e6e7e6`, muted `#485457`, border `#242b2d`, red `#bc8f7d`, green `#96b088`, yellow `#ccac7d`, blue `#7e9aab`, magenta `#a68caa`, cyan `#839c98`
- Mapped roles: muted: black_bright (Comment color); border: black (WinSeparator fg)
- Terminal 0–15: `#242b2d` `#bc8f7d` `#96b088` `#ccac7d` `#7e9aab` `#a68caa` `#839c98` `#ced3dc` `#485457` `#d4a394` `#abc49e` `#e2bf8f` `#94b1c4` `#bc9ec0` `#97b3af` `#e8ebf0`
- Notes: by rjshkhr; 'a dark, muted colorscheme'. Accent hues/saturation are very close to Paradise (rust-rose, sage, sand, slate, mauve, teal-grey) but bg #1D2326 has a blue-teal tint. Single-file nvim theme; no terminal extras. syntax from legacy groups + TS* groups (TSVariable/Identifier = magenta).

### Rasmus (dark)
- Source of hex: https://raw.githubusercontent.com/kvrohit/rasmus.nvim/main/lua/rasmus/colors.lua ; https://raw.githubusercontent.com/kvrohit/rasmus.nvim/main/extras/kitty/rasmus.conf ; https://raw.githubusercontent.com/kvrohit/rasmus.nvim/main/lua/rasmus/init.lua
- Neovim: https://github.com/kvrohit/rasmus.nvim
- Roles: bg `#1a1a19`, fg `#d1d1d1`, muted `#b6b6b5`, border `#3a3a39`, red `#ff968c`, green `#61957f`, yellow `#ffc591`, blue `#8db4d4`, magenta `#de9bc8`, cyan `#7bb099`
- Mapped roles: muted: palette gray07 (comment is gray05 #6a6a69); border: palette gray04 (kitty active_border_color)
- Terminal 0–15: `#333332` `#ff968c` `#61957f` `#ffc591` `#8db4d4` `#de9bc8` `#7bb099` `#d1d1d1` `#4c4c4b` `#ffafa5` `#7aae98` `#ffdeaa` `#a6cded` `#f7b4e1` `#94c9b2` `#eaeaea`
- Notes: by kvrohit; based on the Rasmus (Helix/Zed-like) palette; syntax restrained to blue/cyan with mostly-fg treesitter (function/variable = fg; legacy Function/Identifier = blue). Red/yellow/magenta are pastel but fairly saturated. Also has a 'monochrome' variant. Extras: alacritty, foot, kitty, iterm, warp.

### Ashen (default (dark))
- Source of hex: https://raw.githubusercontent.com/ficd0/ashen.nvim/main/lua/ashen/variants/default/colors.lua ; https://raw.githubusercontent.com/ficd0/ashen.nvim/main/lua/ashen/variants/default/theme.lua ; https://raw.githubusercontent.com/ficd0/ashen/main/foot/ashen.ini
- Neovim: https://github.com/ficd0/ashen.nvim
- Roles: bg `#121212`, fg `#b4b4b4`, muted `#a7a7a7`, border `#323232`, red `#b14242`, green `#629c7d`, yellow `#e49a44`, blue `#4a8b8b`, magenta `#a7a7a7`, cyan `#b4b4b4`
- Mapped roles: fg: nvim Normal fg g_3 (foot terminal fg is #d5d5d5); muted: g_4 (comment is g_6 #737373); border: g_8 (WinSeparator fg); green: green_light; yellow: orange_smolder (ANSI3); blue: 'blue' = muted teal; magenta: ANSI5 (grey; theme has no magenta); cyan: ANSI6 (grey; theme has no cyan)
- Terminal 0–15: `#121212` `#b14242` `#d87c4a` `#e49a44` `#4a8b8b` `#a7a7a7` `#b4b4b4` `#d5d5d5` `#949494` `#b14242` `#d87c4a` `#e49a44` `#4a8b8b` `#a7a7a7` `#b4b4b4` `#d5d5d5`
- Notes: by ficd0 (Daniel Fichtinger); 'warm, muted' grayscale theme with red/orange accents + one teal. Ports repo (ficd0/ashen, Codeberg-canonical) has alacritty, foot, kitty, ghostty?, fish, fzf, yazi, bat, emacs, base16 etc. Reds/oranges are fairly saturated; scored as near-monochrome contrast entry.

### Lackluster (lackluster (default))
- Source of hex: https://raw.githubusercontent.com/slugbyte/lackluster.nvim/main/lua/lackluster/color.lua ; https://raw.githubusercontent.com/slugbyte/lackluster.nvim/main/lua/lackluster/color-special.lua ; https://raw.githubusercontent.com/slugbyte/lackluster.nvim/main/lua/lackluster/create-theme.lua ; https://raw.githubusercontent.com/slugbyte/lackluster.nvim/main/lua/lackluster/highlight.lua ; https://raw.githubusercontent.com/slugbyte/lackluster.nvim/main/extra/kitty/lackluster.conf
- Neovim: https://github.com/slugbyte/lackluster.nvim
- Roles: bg `#101010`, fg `#cccccc`, muted `#aaaaaa`, border `#444444`, red `#d70000`, green `#789978`, yellow `#abab77`, blue `#7788aa`, magenta `#d7007d`, cyan `#708090`
- Mapped roles: fg: ui.fg_normal = gray8; muted: gray7 (comment is #3A3A3A); border: ui.fg_border = gray4; magenta: kitty color5 (no magenta in nvim palette); cyan: 'lack' slate grey (kitty: 'Cyan is set to lack')
- Terminal 0–15: `#080808` `#d70000` `#789978` `#ffaa88` `#7788aa` `#d7007d` `#708090` `#deeeed` `#444444` `#d70000` `#789978` `#ffaa88` `#7788aa` `#d7007d` `#708090` `#deeeed`
- Notes: by slugbyte; 'mostly monochrome' greys with slate 'lack' + 'luster' highlights; red #D70000 reserved for errors (not muted). Variants lackluster/hack/mint/night/dark (syntax swaps). Extras: alacritty, foot, kitty, wezterm-ish. kitty bg #0A0A0A vs nvim #101010. function = func_def (luster); func_call is gray6 #7a7a7a.

## Left out
- Did not meet 3 of 4 criteria: Mountain "Fuji" palette from the repo's alacritty file (fg `#f0f0f0`: fails soft fg and contrast; the base16 Mountain above is the same author's softer palette), Tumbling Stones (iTerm2; fails soft fg and contrast).
- Too well known: Tomorrow Night (base46 variant scored ΔE V 5.0, but it is the classic Tomorrow palette). Kanso (Ink/Zen/Mist score ΔE P 3.3–4.1 in iTerm2/Gogh, but its README calls it an evolution of Kanagawa). Jellybeans (> 1000 stars). Yoru (3.5k stars).
- Qualified but ranked below the top 12: Posterpole 7.0, Nightlamp (base46) 7.0, Agave (Gogh) 7.0, Pnevma 7.2, Meliora (Gogh) 7.2, Patina Dark / Dark Soft (iTerm2) 7.6, Spacegray Eighties Dull 7.7, Sequoia night 7.8, Neomodern hojicha 9.3 / moon 10.5. Charcoal (iTerm2) was a third monochrome option (ΔE 8.6).
- No literal hex in source (colors computed in Lua): mellifluous, vesper.nvim. Too saturated or tinted: kurayami, darkrose, makurai, warm-burnout, thorn, evergarden, sora, cendre, decay, everblush, radium, black-metal family. Miasma has no blue/purple.

## How the candidates were found
- Two web searches (GitHub, r/neovim, r/unixporn, dotfyle) for Neovim and ricing palettes; every hex was read from the raw file listed under each theme.
- A programmatic screen of every dark scheme in iTerm2-Color-Schemes (906, `windowsterminal/*.json`), Gogh (`data/themes.json`) and tinted-theming base16/base24, scored with the criteria above. Tinta and Chinoiserie Morandi came from this screen.
- For tinted-theming entries, "stars" is the origin repo and "last commit" is the scheme file in tinted-theming/schemes. Mountain's row uses the repo's stars and last push. Terminal colors use the standard base16 mapping and syntax colors follow the base16 styling guide (keyword base0E, string base0B, function base0D, number base09, type base0A, comment base03, variable base08); Neovim support for them comes from tinted-theming's Neovim builder.
- Star counts and dates were read on 2026-11-09.
