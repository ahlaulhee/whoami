import { defineConfig } from 'vite';
import { age, tenure } from './src/age.js';

// fills {{age}} / {{tenure}} in index.html so meta tags and no-JS visitors get real values
const computedFacts = {
  name: 'computed-facts',
  transformIndexHtml(html) {
    const now = new Date();
    return html.replaceAll('{{age}}', String(age(now))).replaceAll('{{tenure}}', tenure(now));
  },
};

export default defineConfig({
  plugins: [computedFacts],
});
