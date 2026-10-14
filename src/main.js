import { age, tenure } from './age.js';

// the build-time values go stale between deploys; refresh them on load
const values = { age: String(age()), tenure: tenure() };
for (const el of document.querySelectorAll('[data-calc]')) el.textContent = values[el.dataset.calc];
