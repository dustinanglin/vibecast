// Logo + splash ideation marks for Vibecast.
// All marks composed of basic primitives: circles, rects, simple arcs.
// Five vibe hues come through where the mark is meant to "be" the vibe state.

const LT = window.VIBE_TOKENS || { ink: '#1A1714', paper: '#FBF7EE', bg: '#F4EFE6', serif: '"Fraunces", serif', sans: '"Inter", sans-serif', mono: '"JetBrains Mono", monospace' };
const VIBE_HUES = [
  { id: 'morning',  color: 'oklch(0.68 0.14 35)' },
  { id: 'around',   color: 'oklch(0.62 0.13 200)' },
  { id: 'workout',  color: 'oklch(0.60 0.16 145)' },
  { id: 'winddown', color: 'oklch(0.55 0.13 280)' },
  { id: 'plane',    color: 'oklch(0.55 0.13 245)' },
];

// Generic frame for showcasing a mark
function MarkFrame({ bg = LT.paper, label, sublabel, children, height = 260 }) {
  return (
    <div style={{ background: bg, borderRadius: 14, border: `1px solid rgba(26,23,20,0.08)`, padding: 24, height, display: 'flex', flexDirection: 'column', position: 'relative' }}>
      <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{children}</div>
      <div style={{ position: 'absolute', left: 16, bottom: 12, fontFamily: LT.mono, fontSize: 9, letterSpacing: '0.14em', color: 'rgba(26,23,20,0.40)', textTransform: 'uppercase', fontWeight: 600 }}>
        {label}{sublabel ? ` · ${sublabel}` : ''}
      </div>
    </div>
  );
}

// ─── 1. Wordmark studies ───────────────────────────────────
// Fraunces with personality. Custom dot, ligature-feeling tail, stacked.
function WordmarkStraight({ color = LT.ink, size = 56 }) {
  return (
    <span style={{ fontFamily: LT.serif, fontSize: size, fontWeight: 500, letterSpacing: '-0.035em', color, lineHeight: 1, fontStyle: 'normal' }}>
      Vibecast
    </span>
  );
}

function WordmarkAccentDot({ color = LT.ink, accent = VIBE_HUES[1].color, size = 56 }) {
  return (
    <span style={{ fontFamily: LT.serif, fontSize: size, fontWeight: 500, letterSpacing: '-0.035em', color, lineHeight: 1, display: 'inline-flex', alignItems: 'flex-end' }}>
      Vibecast
      <span style={{ width: size * 0.14, height: size * 0.14, borderRadius: 999, background: accent, marginLeft: size * 0.04, marginBottom: size * 0.07 }} />
    </span>
  );
}

function WordmarkItalic({ color = LT.ink, size = 56 }) {
  return (
    <span style={{ fontFamily: LT.serif, fontSize: size, fontWeight: 500, letterSpacing: '-0.025em', color, lineHeight: 1, fontStyle: 'italic' }}>
      vibecast
    </span>
  );
}

function WordmarkStacked({ color = LT.ink, size = 44 }) {
  return (
    <div style={{ display: 'inline-flex', flexDirection: 'column', alignItems: 'flex-start', lineHeight: 0.92 }}>
      <span style={{ fontFamily: LT.serif, fontSize: size, fontWeight: 500, letterSpacing: '-0.03em', color }}>vibe</span>
      <span style={{ fontFamily: LT.serif, fontSize: size, fontWeight: 500, letterSpacing: '-0.03em', color, fontStyle: 'italic' }}>cast.</span>
    </div>
  );
}

function WordmarkSlash({ color = LT.ink, accent = VIBE_HUES[1].color, size = 48 }) {
  return (
    <span style={{ fontFamily: LT.serif, fontSize: size, fontWeight: 500, letterSpacing: '-0.025em', color, lineHeight: 1, display: 'inline-flex', alignItems: 'baseline' }}>
      vibe
      <span style={{ display: 'inline-block', width: 2, height: size * 0.85, background: accent, transform: 'rotate(15deg)', margin: `0 ${size * 0.08}px`, alignSelf: 'center' }} />
      cast
    </span>
  );
}

// ─── 2. Symbolic marks ─────────────────────────────────────
// All composed of primitives: circles, rects, simple paths.

// Concentric arcs / soundwaves emanating
function MarkWaves({ size = 96, color = LT.ink, accent = VIBE_HUES[1].color }) {
  const cx = size / 2, cy = size / 2;
  const stroke = size * 0.06;
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
      <circle cx={cx} cy={cy} r={size * 0.10} fill={accent} />
      <circle cx={cx} cy={cy} r={size * 0.22} fill="none" stroke={color} strokeWidth={stroke} strokeLinecap="round" />
      <circle cx={cx} cy={cy} r={size * 0.34} fill="none" stroke={color} strokeWidth={stroke} strokeLinecap="round" strokeDasharray={`${size * 0.6} ${size * 0.5}`} strokeDashoffset={size * 0.15} />
      <circle cx={cx} cy={cy} r={size * 0.46} fill="none" stroke={color} strokeWidth={stroke} strokeLinecap="round" strokeDasharray={`${size * 0.45} ${size * 1.0}`} strokeDashoffset={size * 0.05} />
    </svg>
  );
}

// Stack of color bars — the vibes themselves as the mark
function MarkStack({ size = 96, hues = VIBE_HUES, gap = 0.06, radius = 0.10 }) {
  const barH = (size * (1 - (hues.length - 1) * gap)) / hues.length;
  const gapPx = size * gap;
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
      {hues.map((v, i) => (
        <rect key={v.id}
          x={size * 0.06} y={i * (barH + gapPx)}
          width={size * 0.88} height={barH}
          rx={size * radius} ry={size * radius}
          fill={v.color} />
      ))}
    </svg>
  );
}

// Cassette-y rectangle with two reels
function MarkCassette({ size = 96, color = LT.ink, accent = VIBE_HUES[1].color }) {
  const w = size, h = size * 0.66;
  const r = size * 0.10;
  return (
    <svg width={w} height={h} viewBox={`0 0 ${w} ${h}`} style={{ overflow: 'visible' }}>
      <rect x={1} y={1} width={w - 2} height={h - 2} rx={r} ry={r} fill="none" stroke={color} strokeWidth={size * 0.05} />
      <circle cx={w * 0.30} cy={h * 0.50} r={h * 0.18} fill="none" stroke={color} strokeWidth={size * 0.04} />
      <circle cx={w * 0.30} cy={h * 0.50} r={h * 0.06} fill={accent} />
      <circle cx={w * 0.70} cy={h * 0.50} r={h * 0.18} fill="none" stroke={color} strokeWidth={size * 0.04} />
      <circle cx={w * 0.70} cy={h * 0.50} r={h * 0.06} fill={accent} />
      <rect x={w * 0.10} y={h * 0.78} width={w * 0.80} height={h * 0.06} rx={2} fill={color} opacity={0.30} />
    </svg>
  );
}

// Letter-V monogram with sound bars inside the negative space
function MarkVMonogram({ size = 96, color = LT.ink, accent = VIBE_HUES[1].color }) {
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
      <path d={`M ${size * 0.10} ${size * 0.18} L ${size * 0.50} ${size * 0.86} L ${size * 0.90} ${size * 0.18}`}
        fill="none" stroke={color} strokeWidth={size * 0.10} strokeLinecap="round" strokeLinejoin="round" />
      {/* three vertical bars in the V's mouth */}
      <rect x={size * 0.36} y={size * 0.30} width={size * 0.06} height={size * 0.18} rx={size * 0.03} fill={accent} />
      <rect x={size * 0.47} y={size * 0.22} width={size * 0.06} height={size * 0.32} rx={size * 0.03} fill={accent} />
      <rect x={size * 0.58} y={size * 0.34} width={size * 0.06} height={size * 0.14} rx={size * 0.03} fill={accent} />
    </svg>
  );
}

// Disc / record with vibe-color label
function MarkDisc({ size = 96, color = LT.ink, accent = VIBE_HUES[1].color }) {
  const cx = size / 2, cy = size / 2;
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
      <circle cx={cx} cy={cy} r={size * 0.46} fill={color} />
      <circle cx={cx} cy={cy} r={size * 0.42} fill="none" stroke={LT.paper} strokeWidth={1} opacity={0.20} />
      <circle cx={cx} cy={cy} r={size * 0.36} fill="none" stroke={LT.paper} strokeWidth={1} opacity={0.20} />
      <circle cx={cx} cy={cy} r={size * 0.30} fill="none" stroke={LT.paper} strokeWidth={1} opacity={0.20} />
      <circle cx={cx} cy={cy} r={size * 0.22} fill={accent} />
      <circle cx={cx} cy={cy} r={size * 0.04} fill={LT.paper} />
    </svg>
  );
}

// Rounded square "tile" with V cut out — works as iOS app icon shape
function MarkAppIcon({ size = 120, bg = LT.ink, accent = VIBE_HUES[1].color }) {
  const r = size * 0.22; // iOS squircle-ish
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{ filter: 'drop-shadow(0 8px 20px rgba(0,0,0,0.18))' }}>
      <rect x={0} y={0} width={size} height={size} rx={r} ry={r} fill={bg} />
      {/* Bars rising — like a quiet equalizer */}
      <rect x={size * 0.22} y={size * 0.50} width={size * 0.10} height={size * 0.30} rx={size * 0.03} fill={LT.paper} />
      <rect x={size * 0.36} y={size * 0.36} width={size * 0.10} height={size * 0.44} rx={size * 0.03} fill={LT.paper} />
      <rect x={size * 0.50} y={size * 0.26} width={size * 0.10} height={size * 0.54} rx={size * 0.03} fill={LT.paper} />
      <rect x={size * 0.64} y={size * 0.40} width={size * 0.10} height={size * 0.40} rx={size * 0.03} fill={accent} />
    </svg>
  );
}

// Bookmark / ribbon — nods to "pinning" and editorial
function MarkBookmark({ size = 96, color = LT.ink, accent = VIBE_HUES[1].color }) {
  const w = size * 0.55, h = size * 0.92;
  const x = (size - w) / 2;
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
      <path d={`M ${x} ${size * 0.06} L ${x + w} ${size * 0.06} L ${x + w} ${size * 0.86} L ${x + w / 2} ${size * 0.66} L ${x} ${size * 0.86} Z`} fill={color} />
      <circle cx={size / 2} cy={size * 0.36} r={size * 0.10} fill={accent} />
    </svg>
  );
}

// Lockup helper — mark + wordmark
function Lockup({ Mark, vertical = false, gap = 18, accent = VIBE_HUES[1].color, color = LT.ink, size = 56, wordSize = 36 }) {
  return (
    <div style={{ display: 'inline-flex', flexDirection: vertical ? 'column' : 'row', alignItems: 'center', gap }}>
      <Mark size={size} color={color} accent={accent} />
      <span style={{ fontFamily: LT.serif, fontSize: wordSize, fontWeight: 500, letterSpacing: '-0.03em', color, lineHeight: 1 }}>
        Vibecast
      </span>
    </div>
  );
}

Object.assign(window, {
  VIBE_HUES, MarkFrame,
  WordmarkStraight, WordmarkAccentDot, WordmarkItalic, WordmarkStacked, WordmarkSlash,
  MarkWaves, MarkStack, MarkCassette, MarkVMonogram, MarkDisc, MarkAppIcon, MarkBookmark,
  Lockup,
});
