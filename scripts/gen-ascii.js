import { existsSync } from 'node:fs';
import { writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { createCanvas, GlobalFonts } from '@napi-rs/canvas';

const root = (p) => fileURLToPath(new URL(`../${p}`, import.meta.url));

const SHAPE_FONT = process.env.ASCII_SHAPE_FONT ?? 'C:/Windows/Fonts/ariblk.ttf';
if (!existsSync(SHAPE_FONT)) {
  throw new Error(`Shape font not found at ${SHAPE_FONT}. Set ASCII_SHAPE_FONT to a heavy .ttf/.otf.`);
}
GlobalFonts.registerFromPath(SHAPE_FONT, 'AsciiShape');
GlobalFonts.registerFromPath(root('scripts/fonts/DepartureMono-Regular.otf'), 'Departure Mono');
GlobalFonts.registerFromPath(
  root('node_modules/@fontsource-variable/geist/files/geist-latin-wght-normal.woff2'),
  'Geist OG',
);

const HANDLE = 'ahlaulhee';
// Paradise (https://github.com/paradise-theme/paradise), matches src/styles/global.css
const PALETTE = {
  bg: '#151515',
  fg: '#e8e3e3',
  muted: '#a39d9d',
  yellow: '#d9bc8c',
  red: '#b66467',
  blue: '#8da3b9',
};
// keyed by cell size
const TIERS = {
  64: { set: '@#&%$', color: 'yellow' },
  32: { set: '@#&%$', color: 'yellow' },
  16: { set: 'WXOA8', color: 'red' },
  8: { set: '*+=xo', color: 'blue' },
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

function drawCells(ctx, cells, scale, dx, dy) {
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  for (const c of cells) {
    ctx.font = `bold ${c.s * GLYPH_SCALE * scale}px "Departure Mono"`;
    ctx.fillStyle = PALETTE[TIERS[c.s].color];
    ctx.fillText(c.ch, dx + c.x * scale, dy + c.y * scale);
  }
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

async function writeOg() {
  const raster = rasterize(HANDLE);
  const cells = quadtree(raster);
  const scale = 1000 / raster.w;
  await writePng('public/og.png', 1200, 630, (ctx) => {
    drawCells(ctx, cells, scale, 100, 150);
    ctx.textAlign = 'left';
    ctx.textBaseline = 'alphabetic';
    ctx.font = '600 46px "Geist OG"';
    ctx.fillStyle = PALETTE.fg;
    ctx.fillText('Alex Laulhe · setup guides', 124, 150 + raster.h * scale + 70);
    ctx.font = '34px "Geist OG"';
    ctx.fillStyle = PALETTE.muted;
    ctx.fillText('Fedora, Mango, Neovim · Córdoba, Argentina', 124, 150 + raster.h * scale + 122);
  });
  return cells.length;
}

await writeSquare('a', 64, 'public/favicon.png', 1.05);
await writeSquare('a', 180, 'public/apple-touch-icon.png', 1.05);
const glyphs = await writeOg();
// site profile image and github avatar
await writeSquare('ahl', 1024, 'src/assets/avatar.png', 0.86);
console.log(
  `og banner: ${glyphs} glyphs; wrote public/favicon.png, public/apple-touch-icon.png, public/og.png, src/assets/avatar.png`,
);
