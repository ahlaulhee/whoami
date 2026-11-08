import { type CollectionEntry, getCollection } from 'astro:content';

export type Post = CollectionEntry<'posts'>;

// drafts render in `astro dev` so they can be previewed, never in a build
const visible = (post: Post) => import.meta.env.DEV || !post.data.draft;

export async function getPosts(): Promise<Post[]> {
  return (await getCollection('posts', visible)).sort((a, b) => b.data.pubDate.valueOf() - a.data.pubDate.valueOf());
}

export async function getTags(): Promise<Map<string, Post[]>> {
  const tags = new Map<string, Post[]>();
  for (const post of await getPosts()) {
    for (const tag of post.data.tags) tags.set(tag, [...(tags.get(tag) ?? []), post]);
  }
  return new Map([...tags].sort(([a], [b]) => a.localeCompare(b)));
}

export type SeriesPart = { part: number; title: string; href?: string; current: boolean };

// every part of the series, drafts included: unpublished parts show up as "coming soon" without a link
export async function getSeries(post: Post): Promise<{ name: string; parts: SeriesPart[] } | undefined> {
  const series = post.data.series;
  if (!series) return undefined;
  const all = await getCollection('posts', (p) => p.data.series?.name === series.name);
  const parts = all
    .sort((a, b) => a.data.series!.part - b.data.series!.part)
    .map((p) => ({
      part: p.data.series!.part,
      title: p.data.title,
      href: visible(p) ? postHref(p) : undefined,
      current: p.id === post.id,
    }));
  return { name: series.name, parts };
}

export const postHref = (post: Post) => `/blog/${post.id}/`;

export const tagHref = (tag: string) => `/tags/${tag}/`;

const WORDS_PER_MINUTE = 220;

export function readingMinutes(body: string | undefined): number {
  const words = (body ?? '').split(/\s+/).filter(Boolean).length;
  return Math.max(1, Math.round(words / WORDS_PER_MINUTE));
}

const dateFormat = new Intl.DateTimeFormat('en-CA', { year: 'numeric', month: '2-digit', day: '2-digit', timeZone: 'UTC' });

// ISO-style dates read the same everywhere: 2026-11-08
export const formatDate = (date: Date) => dateFormat.format(date);
