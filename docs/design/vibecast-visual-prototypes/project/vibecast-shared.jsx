// Shared primitives for all three Vibecast directions
// Episode/show data, fallback artwork, common icons.

const SHOWS = [
  {
    id: 'hard-fork',
    title: 'Hard Fork',
    publisher: 'The New York Times',
    // hue used for fallback artwork & accent extraction in Direction C
    hue: 18,   // warm orange
    chroma: 0.16,
  },
  {
    id: 'vergecast',
    title: 'The Vergecast',
    publisher: 'The Verge',
    hue: 282,  // purple
    chroma: 0.18,
  },
  {
    id: 'planet-money',
    title: 'Planet Money',
    publisher: 'NPR',
    hue: 142,  // green
    chroma: 0.14,
  },
  {
    id: 'acquired',
    title: 'Acquired',
    publisher: 'David Rosenthal & Ben Gilbert',
    hue: 220,  // blue
    chroma: 0.15,
  },
  {
    id: 'ezra',
    title: 'The Ezra Klein Show',
    publisher: 'New York Times Opinion',
    hue: 50,   // ochre
    chroma: 0.12,
  },
  {
    id: 'darknet',
    title: 'Darknet Diaries',
    publisher: 'Jack Rhysider',
    hue: 162,  // teal
    chroma: 0.14,
  },
];

const SHOW_BY_ID = Object.fromEntries(SHOWS.map(s => [s.id, s]));

const EPISODES = [
  { id: 'e1', show: 'hard-fork',    title: 'The Future of AI Regulation in Europe',  blurb: 'New rules could reshape how companies deploy large language models across the EU.', age: '2d ago',  mins: 0,    total: 62, played: true },
  { id: 'e2', show: 'vergecast',    title: 'How Figma Became the Design Standard',   blurb: 'A deep dive into collaborative design tools and why they won the decade.',          age: '1w ago',  mins: 75,   total: 75, played: true },
  { id: 'e3', show: 'planet-money', title: 'Inside the Semiconductor Supply Chain',  blurb: 'From Taiwan to Texas: the geopolitics of chip manufacturing.',                      age: '2w ago',  mins: 45,   total: 45, played: true },
  { id: 'e4', show: 'acquired',     title: 'The Long Road to Autonomous Vehicles',   blurb: 'Self-driving cars keep failing. Here is why the timeline keeps slipping.',          age: '3w ago',  mins: 90,   total: 90, played: true },
  { id: 'e5', show: 'ezra',         title: 'Why the Dollar Is Still King',           blurb: 'The global reserve currency and its uncertain future in a multipolar world.',       age: '4w ago',  mins: 36,   total: 65, played: false },
  { id: 'e6', show: 'darknet',      title: 'The Social Media Paradox',               blurb: 'Platforms that promised connection are delivering anxiety instead.',                age: '1mo ago', mins: 0,    total: 110,played: false },
  { id: 'e7', show: 'hard-fork',    title: 'Rethinking the Office',                  blurb: 'Hybrid is dead, long live hybrid. What companies actually do now.',                 age: '1mo ago', mins: 0,    total: 60, played: false },
  { id: 'e8', show: 'planet-money', title: 'Climate Tech\u2019s Quiet Revolution',   blurb: 'Behind the headlines, a generation of founders is rewiring industry.',              age: '1mo ago', mins: 0,    total: 75, played: false },
];

// ─── Fallback artwork ────────────────────────────────────────
// Generates a deterministic-ish mark from the show's first letters + hue.
// Used everywhere artwork would be in the real app.
function FallbackArt({ show, size = 72, radius, style, variant = 'gradient' }) {
  const r = radius ?? Math.round(size * 0.18);
  const initials = show.title
    .split(/\s+/).filter(w => w[0] && /[A-Z]/.test(w[0]))
    .slice(0, 2).map(w => w[0]).join('') || show.title.slice(0, 2).toUpperCase();
  const h = show.hue;
  const c = show.chroma;
  // Two stops of same hue, different lightness — matches "all accents share chroma & lightness"
  const stop1 = `oklch(0.55 ${c} ${h})`;
  const stop2 = `oklch(0.32 ${c * 0.9} ${(h + 24) % 360})`;
  const stop3 = `oklch(0.20 ${c * 0.8} ${(h + 40) % 360})`;
  let bg;
  if (variant === 'flat') bg = `oklch(0.36 ${c * 0.6} ${h})`;
  else if (variant === 'duotone') bg = `linear-gradient(135deg, ${stop1} 0%, ${stop3} 100%)`;
  else bg = `radial-gradient(circle at 28% 22%, ${stop1} 0%, ${stop2} 55%, ${stop3} 100%)`;

  return (
    <div style={{
      width: size, height: size, borderRadius: r,
      background: bg,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      position: 'relative', overflow: 'hidden',
      boxShadow: 'inset 0 0 0 1px rgba(255,255,255,0.06)',
      ...style,
    }}>
      {/* subtle noise / texture line */}
      <div style={{
        position: 'absolute', inset: 0, borderRadius: r,
        background: 'linear-gradient(180deg, rgba(255,255,255,0.08) 0%, rgba(255,255,255,0) 40%)',
        pointerEvents: 'none',
      }} />
      <span style={{
        fontFamily: '"Fraunces", "Times New Roman", Georgia, serif',
        fontWeight: 600,
        fontSize: size * 0.42,
        color: 'rgba(255,255,255,0.92)',
        letterSpacing: '-0.02em',
        lineHeight: 1,
      }}>{initials}</span>
    </div>
  );
}

// ─── Icons (minimal, hand-tuned, monoline) ───────────────────
const Icon = {
  play: (s = 16, c = 'currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill={c}><path d="M7 5.5v13a1 1 0 0 0 1.55.83l10-6.5a1 1 0 0 0 0-1.66l-10-6.5A1 1 0 0 0 7 5.5z"/></svg>
  ),
  pause: (s = 16, c = 'currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill={c}><rect x="6" y="5" width="4" height="14" rx="1"/><rect x="14" y="5" width="4" height="14" rx="1"/></svg>
  ),
  back15: (s = 28, c = 'currentColor') => (
    <svg width={s} height={s} viewBox="0 0 32 32" fill="none" stroke={c} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M16 6 V2 L11 6 L16 10"/>
      <path d="M16 6 a10 10 0 1 1 -9.5 7"/>
      <text x="16" y="20" textAnchor="middle" fontFamily="-apple-system, system-ui" fontSize="9.5" fontWeight="600" fill={c} stroke="none">15</text>
    </svg>
  ),
  fwd30: (s = 28, c = 'currentColor') => (
    <svg width={s} height={s} viewBox="0 0 32 32" fill="none" stroke={c} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M16 6 V2 L21 6 L16 10"/>
      <path d="M16 6 a10 10 0 1 0 9.5 7"/>
      <text x="16" y="20" textAnchor="middle" fontFamily="-apple-system, system-ui" fontSize="9.5" fontWeight="600" fill={c} stroke="none">30</text>
    </svg>
  ),
  plus: (s = 18, c = 'currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="2" strokeLinecap="round"><path d="M12 5v14M5 12h14"/></svg>
  ),
  search: (s = 18, c = 'currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="2" strokeLinecap="round"><circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/></svg>
  ),
  queue: (s = 18, c = 'currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="2" strokeLinecap="round"><path d="M4 7h12M4 12h12M4 17h8"/><path d="M19 14v6M19 14l3 2M19 14l-3 2"/></svg>
  ),
  speed: (s = 18, c = 'currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="2" strokeLinecap="round"><path d="M12 4a8 8 0 1 0 7.5 5.2"/><path d="M12 12l4-3"/></svg>
  ),
  sleep: (s = 18, c = 'currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M20 14a8 8 0 0 1-10-10 8 8 0 1 0 10 10z"/></svg>
  ),
  airplay: (s = 18, c = 'currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M5 17H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2h-1"/><path d="M8 21l4-5 4 5z"/></svg>
  ),
  share: (s = 18, c = 'currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M12 3v12"/><path d="M8 7l4-4 4 4"/><path d="M5 12v7a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-7"/></svg>
  ),
  more: (s = 18, c = 'currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill={c}><circle cx="5" cy="12" r="1.6"/><circle cx="12" cy="12" r="1.6"/><circle cx="19" cy="12" r="1.6"/></svg>
  ),
  check: (s = 14, c = 'currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><path d="M5 12l5 5 9-11"/></svg>
  ),
  download: (s = 16, c = 'currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M12 4v12"/><path d="M7 11l5 5 5-5"/><path d="M5 20h14"/></svg>
  ),
  resume: (s = 16, c = 'currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M3 12a9 9 0 1 0 3-6.7"/><path d="M3 4v5h5"/></svg>
  ),
  chevronDown: (s = 18, c = 'currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M6 9l6 6 6-6"/></svg>
  ),
  chevronRight: (s = 14, c = 'currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M9 6l6 6-6 6"/></svg>
  ),
};

// Animated waveform bars — used as a now-playing motion accent
function Waveform({ bars = 28, height = 44, color = '#fff', opacity = 0.9, animate = true }) {
  const seedHeights = React.useMemo(
    () => Array.from({ length: bars }, (_, i) => 0.25 + 0.75 * Math.abs(Math.sin((i + 1) * 1.7))),
    [bars]
  );
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 3, height, width: '100%' }}>
      {seedHeights.map((h, i) => (
        <div
          key={i}
          style={{
            flex: 1,
            height: `${h * 100}%`,
            background: color,
            opacity,
            borderRadius: 2,
            animation: animate ? `vb-bar ${0.9 + (i % 5) * 0.18}s ease-in-out ${i * 0.04}s infinite alternate` : undefined,
            transformOrigin: 'center',
          }}
        />
      ))}
    </div>
  );
}

// One-time waveform keyframes
if (typeof document !== 'undefined' && !document.getElementById('vb-keyframes')) {
  const s = document.createElement('style');
  s.id = 'vb-keyframes';
  s.textContent = `
    @keyframes vb-bar { 0% { transform: scaleY(0.45);} 100% { transform: scaleY(1);} }
    @keyframes vb-pulse { 0%, 100% { opacity: 0.5; transform: scale(1);} 50% { opacity: 1; transform: scale(1.04);} }
    @keyframes vb-shimmer { 0% { background-position: -200% 0;} 100% { background-position: 200% 0;} }
  `;
  document.head.appendChild(s);
}

Object.assign(window, { SHOWS, SHOW_BY_ID, EPISODES, FallbackArt, Icon, Waveform });
