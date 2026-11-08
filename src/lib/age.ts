// shared by the build (static HTML) and the home page script (browser refresh)
type CalendarDate = { y: number; m: number; d: number };

const BIRTH: CalendarDate = { y: 2000, m: 8, d: 4 };
const START: CalendarDate = { y: 2023, m: 12, d: 1 };
const TZ = 'America/Argentina/Cordoba';

const cordobaDate = new Intl.DateTimeFormat('en-US', {
  timeZone: TZ,
  year: 'numeric',
  month: 'numeric',
  day: 'numeric',
});

function today(now: Date): CalendarDate {
  const parts = Object.fromEntries(cordobaDate.formatToParts(now).map((p) => [p.type, p.value]));
  return { y: Number(parts.year), m: Number(parts.month), d: Number(parts.day) };
}

// whole months elapsed from `from` to the Córdoba calendar date of `now`
function monthsSince(from: CalendarDate, now: Date) {
  const t = today(now);
  return (t.y - from.y) * 12 + (t.m - from.m) - (t.d < from.d ? 1 : 0);
}

const unit = (n: number, word: string) => `${n} ${word}${n === 1 ? '' : 's'}`;

export function age(now = new Date()) {
  return Math.floor(monthsSince(BIRTH, now) / 12);
}

export function tenure(now = new Date()) {
  const months = monthsSince(START, now);
  const years = Math.floor(months / 12);
  const rest = months % 12;
  return [years && unit(years, 'year'), rest && unit(rest, 'month')].filter(Boolean).join(' and ');
}
