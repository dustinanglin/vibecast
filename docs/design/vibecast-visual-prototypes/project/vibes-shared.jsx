// Vibecast — Vibes exploration (built on Direction B's editorial language)
// Data + small primitives shared across the variants in vibes.html.

const VIBE_TOKENS = {
  bg: '#F4EFE6',
  paper: '#FBF7EE',
  paperDeep: '#EFE9DD',
  ink: '#1A1714',
  inkDim: 'rgba(26,23,20,0.62)',
  inkMuted: 'rgba(26,23,20,0.40)',
  inkFaint: 'rgba(26,23,20,0.22)',
  hairline: 'rgba(26,23,20,0.10)',
  serif: '"Fraunces", "Times New Roman", Georgia, serif',
  sans: '"Inter", -apple-system, system-ui, sans-serif',
  mono: '"JetBrains Mono", "SF Mono", ui-monospace, monospace',
};

// Each vibe has a single hue. Colors are oklch with shared chroma/lightness so
// they live as a family — paint chips, not jelly beans.
const VIBES = [
  { id: 'morning',    name: 'Morning routine',     emoji: null, color: 'oklch(0.68 0.14 35)',   chip: 'oklch(0.92 0.04 35)',  ink: 'oklch(0.32 0.10 35)',   icon: '☀'  },
  { id: 'around',     name: 'Around town',         emoji: null, color: 'oklch(0.62 0.13 200)',  chip: 'oklch(0.92 0.03 200)', ink: 'oklch(0.32 0.10 220)',  icon: '✦'  },
  { id: 'workout',    name: 'Workout',             emoji: null, color: 'oklch(0.60 0.16 145)',  chip: 'oklch(0.92 0.04 145)', ink: 'oklch(0.30 0.10 145)',  icon: '↟'  },
  { id: 'winddown',   name: 'Wind down',           emoji: null, color: 'oklch(0.55 0.13 280)',  chip: 'oklch(0.92 0.04 280)', ink: 'oklch(0.30 0.10 280)',  icon: '☾'  },
  { id: 'deepwork',   name: 'Deep work',           emoji: null, color: 'oklch(0.45 0.04 60)',   chip: 'oklch(0.92 0.02 60)',  ink: 'oklch(0.25 0.04 60)',   icon: '◆'  },
];
const VIBE_BY_ID = Object.fromEntries(VIBES.map(v => [v.id, v]));

// Podcasts the user follows, plus which vibes they belong to.
// Order within each vibe is intentional — that's the whole product idea.
const PODCASTS = [
  { id: 'hard-fork',     title: 'Hard Fork',                 publisher: 'The New York Times',     hue: 18,  chroma: 0.16, vibes: ['around', 'morning'],
    latest: { title: 'The Future of AI Regulation in Europe', age: '2d ago', mins: 0,  total: 62, blurb: 'New rules could reshape how companies deploy large language models across the EU.' } },
  { id: 'daily',         title: 'The Daily',                 publisher: 'The New York Times',     hue: 8,   chroma: 0.18, vibes: ['morning'],
    latest: { title: 'A Quiet Revolution in Climate Policy',   age: 'Today',  mins: 0,  total: 28, blurb: 'How one bill is reshaping how cities think about heat and water.' } },
  { id: 'up-first',      title: 'Up First',                  publisher: 'NPR',                    hue: 12,  chroma: 0.16, vibes: ['morning'],
    latest: { title: 'Wednesday Briefing',                     age: 'Today',  mins: 0,  total: 14, blurb: 'The three biggest stories you need to know this morning.' } },
  { id: 'vergecast',     title: 'The Vergecast',             publisher: 'The Verge',              hue: 282, chroma: 0.18, vibes: ['around'],
    latest: { title: 'How Figma Became the Design Standard',   age: '1w ago', mins: 12, total: 75, blurb: 'A deep dive into collaborative design tools and why they won the decade.' } },
  { id: '99pi',          title: '99% Invisible',             publisher: 'SiriusXM',               hue: 38,  chroma: 0.15, vibes: ['around', 'winddown'],
    latest: { title: 'The Architecture of Crowds',             age: '3d ago', mins: 0,  total: 38, blurb: 'How buildings shape the behavior of the people inside them.' } },
  { id: 'planet-money',  title: 'Planet Money',              publisher: 'NPR',                    hue: 142, chroma: 0.14, vibes: ['around'],
    latest: { title: 'Inside the Semiconductor Supply Chain',  age: '2w ago', mins: 0,  total: 45, blurb: 'From Taiwan to Texas: the geopolitics of chip manufacturing.' } },
  { id: 'huberman',      title: 'Huberman Lab',              publisher: 'Scicomm Media',          hue: 145, chroma: 0.15, vibes: ['workout'],
    latest: { title: 'Building Strength After 40',             age: '5d ago', mins: 0,  total: 92, blurb: 'Protocols for muscle, mobility, and recovery as you age.' } },
  { id: 'rich-roll',     title: 'The Rich Roll Podcast',     publisher: 'Rich Roll',              hue: 162, chroma: 0.14, vibes: ['workout', 'around'],
    latest: { title: 'Endurance, Patience, and the Long Road', age: '1w ago', mins: 0,  total: 110, blurb: 'A conversation about training for things that take decades.' } },
  { id: 'sleep-with-me', title: 'Sleep With Me',             publisher: 'Slumber Studios',        hue: 285, chroma: 0.14, vibes: ['winddown'],
    latest: { title: 'A Slow Tour Through a Forgotten Library',age: '4d ago', mins: 0,  total: 75, blurb: 'A meandering, deliberately dull bedtime story.' } },
  { id: 'on-being',      title: 'On Being',                  publisher: 'On Being Studios',       hue: 298, chroma: 0.13, vibes: ['winddown'],
    latest: { title: 'The Practice of Slow Attention',         age: '1w ago', mins: 0,  total: 52, blurb: 'A conversation on what it means to truly notice the world.' } },
  { id: 'acquired',      title: 'Acquired',                  publisher: 'David Rosenthal & Ben Gilbert', hue: 220, chroma: 0.15, vibes: ['deepwork'],
    latest: { title: 'The Long Road to Autonomous Vehicles',   age: '3w ago', mins: 0,  total: 188, blurb: 'Self-driving cars keep failing. Here is why the timeline keeps slipping.' } },
  { id: 'ezra',          title: 'The Ezra Klein Show',       publisher: 'NYT Opinion',            hue: 50,  chroma: 0.12, vibes: ['deepwork'],
    latest: { title: 'Why the Dollar Is Still King',           age: '4d ago', mins: 0,  total: 65, blurb: 'The reserve currency and its uncertain future in a multipolar world.' } },
];
const PODCAST_BY_ID = Object.fromEntries(PODCASTS.map(p => [p.id, p]));

// User's manual ordering inside each vibe (the whole product idea).
const VIBE_ORDER = {
  morning:  ['up-first', 'daily', 'hard-fork'],
  around:   ['vergecast', 'hard-fork', '99pi', 'planet-money', 'rich-roll'],
  workout:  ['huberman', 'rich-roll'],
  winddown: ['on-being', '99pi', 'sleep-with-me'],
  deepwork: ['ezra', 'acquired'],
};

// Default "all" order — user's master order across all podcasts.
const ALL_ORDER = [
  'up-first', 'daily', 'hard-fork', 'vergecast', '99pi', 'planet-money',
  'huberman', 'rich-roll', 'ezra', 'acquired', 'on-being', 'sleep-with-me',
];

// Cover artwork — flat color block with serif initials, matches B's vocabulary.
function VibeCover({ pod, size = 64, radius = 6, style }) {
  const initials = pod.title.split(/\s+/).filter(w => w[0] && /[A-Z0-9]/.test(w[0])).slice(0, 2).map(w => w[0]).join('') || pod.title.slice(0, 2);
  const bg = `oklch(0.42 ${pod.chroma * 0.7} ${pod.hue})`;
  return (
    <div style={{
      width: size, height: size, borderRadius: radius, background: bg,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      position: 'relative', overflow: 'hidden', flexShrink: 0,
      boxShadow: 'inset 0 0 0 1px rgba(255,255,255,0.06)',
      ...style,
    }}>
      <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(180deg, rgba(255,255,255,0.10) 0%, rgba(0,0,0,0.10) 100%)' }} />
      <span style={{
        fontFamily: VIBE_TOKENS.serif, fontWeight: 600,
        fontSize: size * 0.42, color: 'rgba(255,255,255,0.92)', letterSpacing: '-0.02em', position: 'relative',
      }}>{initials}</span>
    </div>
  );
}

// A small "vibe chip" — used in row metadata.
function VibeDot({ vibe, size = 8 }) {
  return <span style={{ width: size, height: size, borderRadius: 99, background: vibe.color, flexShrink: 0, display: 'inline-block' }} />;
}

function VibeChip({ vibe, dense = false, active = false }) {
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 5,
      padding: dense ? '2px 7px' : '4px 9px',
      borderRadius: 99,
      background: active ? vibe.color : vibe.chip,
      color: active ? '#fff' : vibe.ink,
      fontFamily: VIBE_TOKENS.mono, fontSize: dense ? 9 : 10,
      letterSpacing: '0.06em', textTransform: 'uppercase', fontWeight: 600,
      whiteSpace: 'nowrap',
    }}>
      <span style={{ width: dense ? 5 : 6, height: dense ? 5 : 6, borderRadius: 99, background: active ? '#fff' : vibe.color }} />
      {vibe.name}
    </span>
  );
}

Object.assign(window, {
  VIBE_TOKENS, VIBES, VIBE_BY_ID, PODCASTS, PODCAST_BY_ID, VIBE_ORDER, ALL_ORDER,
  VibeCover, VibeDot, VibeChip,
});
