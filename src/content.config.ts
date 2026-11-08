import { defineCollection } from 'astro:content';
import { glob } from 'astro/loaders';
import { z } from 'astro/zod';

const posts = defineCollection({
  // `slug` in frontmatter becomes the entry id, so versioned slugs keep their dots
  loader: glob({ base: './src/content/posts', pattern: '**/*.{md,mdx}' }),
  schema: z.object({
    slug: z.string(),
    title: z.string(),
    description: z.string(),
    pubDate: z.coerce.date(),
    updatedDate: z.coerce.date().optional(),
    tags: z.array(z.string()).default([]),
    // software versions the guide was verified against, e.g. "Fedora 45"
    testedOn: z.array(z.string()).default([]),
    series: z.object({ name: z.string(), part: z.number().int().positive() }).optional(),
    draft: z.boolean().default(false),
  }),
});

export const collections = { posts };
