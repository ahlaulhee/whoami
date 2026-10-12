import { existsSync } from 'node:fs';
import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { createCanvas, GlobalFonts } from '@napi-rs/canvas';

const root = (p) => fileURLToPath(new URL(`../${p}`, import.meta.url));

const SHAPE_FONT = process.env.ASCII_SHAPE_FONT ?? 'C:/Windows/Fonts/ariblk.ttf';
if (!existsSync(SHAPE_FONT)) {
  throw new Error(`Shape font not found at ${SHAPE_FONT}. Set ASCII_SHAPE_FONT to a heavy .ttf/.otf.`);
}
GlobalFonts.registerFromPath(SHAPE_FONT, 'AsciiShape');
GlobalFonts.registerFromPath(root('scripts/fonts/DepartureMono-Regular.otf'), 'Departure Mono');

const HANDLE = 'ahlaulhee';
// also written to src/tokens.css, edit colors here
const PALETTE = {
  bg: '#0b0b0d',
  fg: '#d9d4c7',
  muted: '#8a857a',
  amber: '#ffb454',
  magenta: '#ff6ac1',
  cyan: '#5ccfe6',
};
// keyed by cell size
const TIERS = {
  64: { set: '@#&%$', color: 'amber' },
  32: { set: '@#&%$', color: 'amber' },
  16: { set: 'WXOA8', color: 'magenta' },
  8: { set: '*+=xo', color: 'cyan' },
};
const GLYPH_SCALE = 1.2; // relative to the cell
const SHAPE_PX = 240;
const BLOCK = 64; // biggest cell
const MIN_CELL = 8; // smallest cell

function mulberry32(seed) {
  return () => {
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function rasterize(text) {
  const pad = 24;
  const probe = createCanvas(1, 1).getContext('2d');
  probe.font = `${SHAPE_PX}px AsciiShape`;
  const w = Math.ceil(probe.measureText(text).width) + pad * 2;
  const h = Math.ceil(SHAPE_PX * 1.05) + pad * 2;
  const canvas = createCanvas(w, h);
  const ctx = canvas.getContext('2d');
  ctx.font = `${SHAPE_PX}px AsciiShape`;
  ctx.textBaseline = 'middle';
  ctx.fillStyle = '#fff';
  ctx.fillText(text, pad, h / 2);
  const rgba = ctx.getImageData(0, 0, w, h).data;
  const alpha = new Float32Array(w * h);
  for (let i = 0; i < alpha.length; i++) alpha[i] = rgba[i * 4 + 3] / 255;
  return { w, h, alpha };
}

function coverage({ w, h, alpha }, x0, y0, s) {
  let sum = 0;
  let n = 0;
  for (let y = y0; y < Math.min(y0 + s, h); y++) {
    for (let x = x0; x < Math.min(x0 + s, w); x++) {
      sum += alpha[y * w + x];
      n++;
    }
  }
  return n ? sum / n : 0;
}

// solid areas become big cells, edges keep splitting down to MIN_CELL
function quadtree(raster) {
  const rand = mulberry32(7);
  const cells = [];
  const place = (x, y, s) => {
    const { set } = TIERS[s];
    cells.push({ x: x + s / 2, y: y + s / 2, s, ch: set[Math.floor(rand() * set.length)] });
  };
  const visit = (x, y, s) => {
    const cov = coverage(raster, x, y, s);
    if (cov < 0.02) return;
    if (s <= MIN_CELL) {
      if (cov >= 0.45) place(x, y, s);
      return;
    }
    if (cov > 0.93) return place(x, y, s);
    const h = s / 2;
    visit(x, y, h);
    visit(x + h, y, h);
    visit(x, y + h, h);
    visit(x + h, y + h, h);
  };
  for (let y = 0; y < raster.h; y += BLOCK) for (let x = 0; x < raster.w; x += BLOCK) visit(x, y, BLOCK);
  return cells;
}

const escapeXml = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

function toSvg(cells, { w, h }) {
  const body = cells.map((c) => `<text x="${c.x}" y="${c.y}" class="q${c.s}">${escapeXml(c.ch)}</text>`).join('');
  return `<svg class="banner" viewBox="0 0 ${w} ${h}" aria-hidden="true" focusable="false">${body}</svg>`;
}

function drawCells(ctx, cells, scale, dx, dy) {
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  for (const c of cells) {
    ctx.font = `bold ${c.s * GLYPH_SCALE * scale}px "Departure Mono"`;
    ctx.fillStyle = PALETTE[TIERS[c.s].color];
    ctx.fillText(c.ch, dx + c.x * scale, dy + c.y * scale);
  }
}

async function writeBanner() {
  const raster = rasterize(HANDLE);
  const cells = quadtree(raster);
  const file = root('index.html');
  const html = await readFile(file, 'utf8');
  const marker = /(<!-- ascii:banner -->)[\s\S]*?(<!-- \/ascii:banner -->)/;
  if (!marker.test(html)) throw new Error('index.html is missing the <!-- ascii:banner --> markers');
  await writeFile(file, html.replace(marker, `$1${toSvg(cells, raster)}$2`));
  return { raster, cells };
}

async function writeTokens() {
  const vars = Object.entries(PALETTE).map(([name, hex]) => `  --${name}: ${hex};`);
  const tiers = Object.entries(TIERS).map(
    ([s, { color }]) => `.q${s} { font-size: ${+(s * GLYPH_SCALE).toFixed(2)}px; fill: var(--${color}); }`,
  );
  const css = [
    ':root {',
    ...vars,
    '}',
    '',
    ...tiers,
    '',
  ].join('\n');
  await writeFile(root('src/tokens.css'), css);
}

async function writePng(path, w, h, draw) {
  const canvas = createCanvas(w, h);
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = PALETTE.bg;
  ctx.fillRect(0, 0, w, h);
  draw(ctx);
  await writeFile(root(path), canvas.toBuffer('image/png'));
}

// span = glyphs diagonal / size, under ~0.9 it survives github's round crop
async function writeSquare(text, size, path, span) {
  const cells = quadtree(rasterize(text));
  const x0 = Math.min(...cells.map((c) => c.x - c.s / 2));
  const x1 = Math.max(...cells.map((c) => c.x + c.s / 2));
  const y0 = Math.min(...cells.map((c) => c.y - c.s / 2));
  const y1 = Math.max(...cells.map((c) => c.y + c.s / 2));
  const scale = (size * span) / Math.hypot(x1 - x0, y1 - y0);
  await writePng(path, size, size, (ctx) =>
    drawCells(ctx, cells, scale, size / 2 - ((x0 + x1) / 2) * scale, size / 2 - ((y0 + y1) / 2) * scale),
  );
}

async function writeOg({ raster, cells }) {
  const scale = 1000 / raster.w;
  await writePng('public/og.png', 1200, 630, (ctx) => {
    drawCells(ctx, cells, scale, 100, 150);
    ctx.textAlign = 'left';
    ctx.textBaseline = 'alphabetic';
    ctx.font = '44px "Departure Mono"';
    ctx.fillStyle = PALETTE.fg;
    ctx.fillText('Alex Laulhe · dev', 124, 150 + raster.h * scale + 70);
    ctx.font = '33px "Departure Mono"';
    ctx.fillStyle = PALETTE.muted;
    ctx.fillText('Córdoba, Argentina', 124, 150 + raster.h * scale + 122);
  });
}

await writeTokens();
const banner = await writeBanner();
await writeSquare('a', 64, 'public/favicon.png', 1.05);
await writeSquare('a', 180, 'public/apple-touch-icon.png', 1.05);
await writeOg(banner);
await writeSquare('ahl', 1024, 'avatar.png', 0.86); // github avatar
console.log(
  `banner: ${banner.cells.length} glyphs; wrote src/tokens.css, index.html, public/favicon.png, public/apple-touch-icon.png, public/og.png, avatar.png`,
);
