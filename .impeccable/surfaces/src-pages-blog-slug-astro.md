---
version: 1
slug: "src-pages-blog-slug-astro"
primary_target: "src/pages/blog/[slug].astro"
related_targets: ["src/pages/index.astro","src/pages/blog/index.astro"]
---

Scope: whole site (home, blog index, article, tag pages). Visitor mode: Read for articles and blog index; home is a personal page whose job is to route to articles and identify Alex.

Audience/job: English-speaking Linux users reproducing Fedora 45 + Mango + Neovim setups with a terminal beside the browser; they scan for the next command, copy it, and check whether the guide matches their versions.

seed: none (direction pinned by user: Spectre-inspired, Paradise palette, Geist + Geist Mono, dark only)

## Direction contract

THESIS: A field notebook for one real machine. Every guide states what it was tested on before it says anything else. Refuses the generic blog card grid and the hero banner.

OWN-WORLD: Paradise on #151515 ground; square 1px-bordered panels (#1c1c1c), no radius, no glow. Geist for reading, Geist Mono for code, labels, dates and the "Tested on" stamp. Signature: the article title set as an inverted block (fg on bg swapped) like a terminal selection, and the ASCII "ahl" mark recolored to Paradise.

STORY: Reader lands on a guide, sees title, date, read time, tags, the Tested-on stamp and series position at once, follows sticky contents, copies code, moves to the next part.

FIRST VIEWPORT: Top nav (handle left, Blog / RSS right). Desktop two columns: sticky left rail (contents on articles, profile on home), right reading panel with inverted title, meta line, Tested-on stamp, series strip, then body at ~70ch.

FORM: Documentation-style two-column reader; standard navigation, Expressive Code frames themed Paradise.

RISK: Monospace creeping into running text; keep it to code and labels.
