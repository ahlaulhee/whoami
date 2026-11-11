import { readFileSync } from 'node:fs';
import mdx from '@astrojs/mdx';
import sitemap from '@astrojs/sitemap';
import expressiveCode, { ExpressiveCodeTheme } from 'astro-expressive-code';
import { defineConfig } from 'astro/config';

// https://github.com/paradise-theme/vscode (MIT, see src/themes/paradise.LICENSE)
const paradise = ExpressiveCodeTheme.fromJSONString(
  readFileSync(new URL('./src/themes/paradise.json', import.meta.url), 'utf8'),
);

export default defineConfig({
  site: 'https://ahlaulhee.pages.dev',
  trailingSlash: 'always',
  integrations: [
    expressiveCode({
      themes: [paradise],
      useThemedScrollbars: false,
      // long lines wrap with a hanging indent on narrow screens; from 64em prose.css turns wrapping off again
      defaultProps: { wrap: true, hangingIndent: 2 },
      styleOverrides: {
        borderRadius: '0',
        borderColor: '#2b2b2b',
        codeBackground: '#1a1a1a',
        codeFontFamily: "'Geist Mono Variable', ui-monospace, monospace",
        codeFontSize: '0.875rem',
        codeLineHeight: '1.65',
        uiFontFamily: "'Geist Variable', system-ui, sans-serif",
        focusBorder: '#8da3b9',
        frames: {
          frameBoxShadowCssValue: 'none',
          editorTabBarBackground: '#151515',
          editorActiveTabBackground: '#1a1a1a',
          editorActiveTabIndicatorTopColor: '#8da3b9',
          editorActiveTabIndicatorBottomColor: 'transparent',
          editorTabBarBorderBottomColor: '#2b2b2b',
          terminalBackground: '#1a1a1a',
          terminalTitlebarBackground: '#151515',
          terminalTitlebarBorderBottomColor: '#2b2b2b',
          terminalTitlebarDotsOpacity: '0.35',
          inlineButtonBorder: '#424242',
          tooltipSuccessBackground: '#8c977d',
          tooltipSuccessForeground: '#151515',
        },
      },
    }),
    mdx(),
    sitemap(),
  ],
});
