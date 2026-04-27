// Round 2 ideation — focused on:
//   1. App icon variants (V-letterform + big-dot-with-glyph)
//   2. Splash variants combining accent-dot wordmark with soft color bands

const LT2 = window.VIBE_TOKENS;
const HUES = window.VIBE_HUES;

// ─── V-letterform app icons ────────────────────────────────

// V01 — Serif V, capital, paper on ink. The wordmark's letterform, monumentalized.
function IconSerifV({ size = 120, bg = LT2.ink, fg = LT2.paper, accent = HUES[1].color }) {
  const r = size * 0.22;
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{ filter: 'drop-shadow(0 8px 20px rgba(0,0,0,0.18))' }}>
      <rect width={size} height={size} rx={r} ry={r} fill={bg} />
      <text x="50%" y="74%" textAnchor="middle" fontFamily='"Fraunces", serif' fontWeight="500" fontSize={size * 0.78} fill={fg} style={{ letterSpacing: '-0.04em' }}>V</text>
      <circle cx={size * 0.78} cy={size * 0.70} r={size * 0.07} fill={accent} />
    </svg>
  );
}

// V02 — Italic lowercase 'v', paper bg, ink letter, inline accent dot
function IconItalicV({ size = 120, bg = LT2.paper, fg = LT2.ink, accent = HUES[1].color }) {
  const r = size * 0.22;
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{ filter: 'drop-shadow(0 8px 20px rgba(0,0,0,0.10))' }}>
      <rect width={size} height={size} rx={r} ry={r} fill={bg} stroke="rgba(0,0,0,0.06)" />
      <text x="46%" y="76%" textAnchor="middle" fontFamily='"Fraunces", serif' fontStyle="italic" fontWeight="500" fontSize={size * 0.92} fill={fg} style={{ letterSpacing: '-0.05em' }}>v</text>
      <circle cx={size * 0.78} cy={size * 0.66} r={size * 0.06} fill={accent} />
    </svg>
  );
}

// V03 — V with vibe-color "ear" — the V's right stem extends into a colored cap
function IconVEar({ size = 120, bg = LT2.ink, fg = LT2.paper, accent = HUES[1].color }) {
  const r = size * 0.22;
  const sw = size * 0.13; // stroke width
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{ filter: 'drop-shadow(0 8px 20px rgba(0,0,0,0.18))' }}>
      <rect width={size} height={size} rx={r} ry={r} fill={bg} />
      {/* Left stroke (paper) */}
      <path d={`M ${size * 0.20} ${size * 0.26} L ${size * 0.50} ${size * 0.78}`} stroke={fg} strokeWidth={sw} strokeLinecap="round" />
      {/* Right stroke (paper) */}
      <path d={`M ${size * 0.80} ${size * 0.26} L ${size * 0.50} ${size * 0.78}`} stroke={fg} strokeWidth={sw} strokeLinecap="round" />
      {/* Accent cap on the right stroke top */}
      <circle cx={size * 0.80} cy={size * 0.26} r={size * 0.10} fill={accent} />
    </svg>
  );
}

// V04 — Bracketed [V] — editorial / metadata feel
function IconBracketV({ size = 120, bg = LT2.paper, fg = LT2.ink, accent = HUES[1].color }) {
  const r = size * 0.22;
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{ filter: 'drop-shadow(0 8px 20px rgba(0,0,0,0.10))' }}>
      <rect width={size} height={size} rx={r} ry={r} fill={bg} stroke="rgba(0,0,0,0.06)" />
      <text x="50%" y="68%" textAnchor="middle" fontFamily='"Fraunces", serif' fontWeight="500" fontSize={size * 0.50} fill={fg} style={{ letterSpacing: '-0.02em' }}>
        [v]
      </text>
      <circle cx={size * 0.50} cy={size * 0.82} r={size * 0.05} fill={accent} />
    </svg>
  );
}

// V05 — V from the slash wordmark variant (vibe / cast → just the slash + V)
function IconSlashV({ size = 120, bg = LT2.ink, fg = LT2.paper, accent = HUES[1].color }) {
  const r = size * 0.22;
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{ filter: 'drop-shadow(0 8px 20px rgba(0,0,0,0.18))' }}>
      <rect width={size} height={size} rx={r} ry={r} fill={bg} />
      <text x="38%" y="74%" textAnchor="middle" fontFamily='"Fraunces", serif' fontWeight="500" fontSize={size * 0.70} fill={fg} style={{ letterSpacing: '-0.04em' }}>v</text>
      <line x1={size * 0.55} y1={size * 0.78} x2={size * 0.78} y2={size * 0.22} stroke={accent} strokeWidth={size * 0.06} strokeLinecap="round" />
    </svg>
  );
}

// ─── Big-dot / glyph app icons ─────────────────────────────

// D01 — Just the dot. Massive, vibe-colored, paper bg. Bold confidence.
function IconBigDot({ size = 120, bg = LT2.paper, accent = HUES[1].color }) {
  const r = size * 0.22;
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{ filter: 'drop-shadow(0 8px 20px rgba(0,0,0,0.10))' }}>
      <rect width={size} height={size} rx={r} ry={r} fill={bg} stroke="rgba(0,0,0,0.06)" />
      <circle cx={size * 0.5} cy={size * 0.5} r={size * 0.28} fill={accent} />
    </svg>
  );
}

// D02 — Dot + tiny serif V inside. Reads as "vibe" at a glance.
function IconDotV({ size = 120, bg = LT2.paper, accent = HUES[1].color, fg = LT2.paper }) {
  const r = size * 0.22;
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{ filter: 'drop-shadow(0 8px 20px rgba(0,0,0,0.10))' }}>
      <rect width={size} height={size} rx={r} ry={r} fill={bg} stroke="rgba(0,0,0,0.06)" />
      <circle cx={size * 0.5} cy={size * 0.5} r={size * 0.32} fill={accent} />
      <text x="50%" y="63%" textAnchor="middle" fontFamily='"Fraunces", serif' fontWeight="500" fontSize={size * 0.42} fill={fg} style={{ letterSpacing: '-0.04em' }}>v</text>
    </svg>
  );
}

// D03 — Dot bottom-right with tiny serif "vc" stacked on paper. Quiet.
function IconDotCorner({ size = 120, bg = LT2.paper, accent = HUES[1].color, fg = LT2.ink }) {
  const r = size * 0.22;
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{ filter: 'drop-shadow(0 8px 20px rgba(0,0,0,0.10))' }}>
      <rect width={size} height={size} rx={r} ry={r} fill={bg} stroke="rgba(0,0,0,0.06)" />
      <text x={size * 0.18} y={size * 0.62} fontFamily='"Fraunces", serif' fontWeight="500" fontSize={size * 0.36} fill={fg} style={{ letterSpacing: '-0.03em' }}>vibe</text>
      <text x={size * 0.18} y={size * 0.86} fontFamily='"Fraunces", serif' fontStyle="italic" fontWeight="500" fontSize={size * 0.26} fill={fg} style={{ letterSpacing: '-0.02em' }}>cast</text>
      <circle cx={size * 0.80} cy={size * 0.80} r={size * 0.08} fill={accent} />
    </svg>
  );
}

// D04 — Dot eclipsing a smaller dark dot. Two tones, vibe over ink.
function IconEclipse({ size = 120, bg = LT2.paper, accent = HUES[1].color, fg = LT2.ink }) {
  const r = size * 0.22;
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{ filter: 'drop-shadow(0 8px 20px rgba(0,0,0,0.10))' }}>
      <rect width={size} height={size} rx={r} ry={r} fill={bg} stroke="rgba(0,0,0,0.06)" />
      <circle cx={size * 0.42} cy={size * 0.50} r={size * 0.26} fill={fg} />
      <circle cx={size * 0.58} cy={size * 0.50} r={size * 0.26} fill={accent} />
    </svg>
  );
}

// D05 — Dot on ink with paper "halo" arcs (audio waves emanating, but quietly)
function IconDotHalo({ size = 120, bg = LT2.ink, accent = HUES[1].color, fg = LT2.paper }) {
  const r = size * 0.22;
  const cx = size * 0.5, cy = size * 0.5;
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{ filter: 'drop-shadow(0 8px 20px rgba(0,0,0,0.18))' }}>
      <rect width={size} height={size} rx={r} ry={r} fill={bg} />
      <circle cx={cx} cy={cy} r={size * 0.40} fill="none" stroke={fg} strokeWidth={size * 0.012} opacity={0.30} />
      <circle cx={cx} cy={cy} r={size * 0.32} fill="none" stroke={fg} strokeWidth={size * 0.014} opacity={0.50} />
      <circle cx={cx} cy={cy} r={size * 0.20} fill={accent} />
    </svg>
  );
}

// D06 — Big serif period (.) — punctuation as the icon. The dot IS the brand.
function IconPeriod({ size = 120, bg = LT2.paper, accent = HUES[1].color, fg = LT2.ink }) {
  const r = size * 0.22;
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{ filter: 'drop-shadow(0 8px 20px rgba(0,0,0,0.10))' }}>
      <rect width={size} height={size} rx={r} ry={r} fill={bg} stroke="rgba(0,0,0,0.06)" />
      <text x="50%" y="78%" textAnchor="middle" fontFamily='"Fraunces", serif' fontWeight="500" fontSize={size * 0.62} fill={fg} style={{ letterSpacing: '-0.04em' }}>v</text>
      <circle cx={size * 0.72} cy={size * 0.70} r={size * 0.075} fill={accent} />
    </svg>
  );
}

// D07 — Dot + paper waveform glyph (3 tiny dots like Morse / spectogram)
function IconDotMorse({ size = 120, bg = LT2.paper, accent = HUES[1].color, fg = LT2.ink }) {
  const r = size * 0.22;
  const cy = size * 0.5;
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{ filter: 'drop-shadow(0 8px 20px rgba(0,0,0,0.10))' }}>
      <rect width={size} height={size} rx={r} ry={r} fill={bg} stroke="rgba(0,0,0,0.06)" />
      <circle cx={size * 0.30} cy={cy} r={size * 0.05} fill={fg} opacity={0.30} />
      <circle cx={size * 0.42} cy={cy} r={size * 0.07} fill={fg} opacity={0.55} />
      <circle cx={size * 0.56} cy={cy} r={size * 0.10} fill={fg} opacity={0.85} />
      <circle cx={size * 0.74} cy={cy} r={size * 0.14} fill={accent} />
    </svg>
  );
}

// ─── Splash variants combining accent-dot + color bands ─────

// SP1 — Soft bands at top/bottom horizons, wordmark centered. Quiet.
function SplashBandHorizon({ vibeIndex = 1 }) {
  const v = HUES[vibeIndex];
  return (
    <div style={{ background: LT2.bg, height: '100%', position: 'relative', overflow: 'hidden' }}>
      <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: '22%', background: v.color, opacity: 0.18 }} />
      <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, height: '22%', background: v.color, opacity: 0.12 }} />
      <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <window.WordmarkAccentDot color={LT2.ink} accent={v.color} size={62} />
      </div>
      <div style={{ position: 'absolute', bottom: 36, left: 0, right: 0, textAlign: 'center', fontFamily: LT2.serif, fontStyle: 'italic', fontSize: 13, color: 'rgba(26,23,20,0.55)' }}>
        Listen with intent.
      </div>
    </div>
  );
}

// SP2 — Single soft band as a stripe behind the wordmark
function SplashBandStripe({ vibeIndex = 0 }) {
  const v = HUES[vibeIndex];
  return (
    <div style={{ background: LT2.bg, height: '100%', position: 'relative', overflow: 'hidden' }}>
      <div style={{ position: 'absolute', left: 0, right: 0, top: '46%', height: '20%', background: v.color, opacity: 0.22 }} />
      <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <window.WordmarkAccentDot color={LT2.ink} accent={v.color} size={64} />
      </div>
      <div style={{ position: 'absolute', bottom: 36, left: 0, right: 0, textAlign: 'center', fontFamily: LT2.mono, fontSize: 9, letterSpacing: '0.20em', color: 'rgba(26,23,20,0.45)', textTransform: 'uppercase', fontWeight: 600 }}>
        FIVE VIBES · ONE PLAYER
      </div>
    </div>
  );
}

// SP3 — Five thin bands stacked at top, wordmark below (the vibe spectrum)
function SplashBandSpectrum() {
  return (
    <div style={{ background: LT2.bg, height: '100%', position: 'relative', overflow: 'hidden' }}>
      <div style={{ position: 'absolute', top: 0, left: 0, right: 0, display: 'flex', flexDirection: 'column' }}>
        {HUES.map((v, i) => (
          <div key={v.id} style={{ height: 7, background: v.color, opacity: 0.85 }} />
        ))}
      </div>
      <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <window.WordmarkAccentDot color={LT2.ink} accent={HUES[1].color} size={64} />
      </div>
      <div style={{ position: 'absolute', bottom: 36, left: 0, right: 0, textAlign: 'center', fontFamily: LT2.serif, fontStyle: 'italic', fontSize: 13, color: 'rgba(26,23,20,0.55)' }}>
        Five vibes. One player.
      </div>
    </div>
  );
}

// SP4 — Single accent band sweeping diagonal behind wordmark, very soft
function SplashBandDiagonal({ vibeIndex = 2 }) {
  const v = HUES[vibeIndex];
  return (
    <div style={{ background: LT2.bg, height: '100%', position: 'relative', overflow: 'hidden' }}>
      <div style={{
        position: 'absolute', left: '-20%', right: '-20%', top: '40%', height: '24%',
        background: `linear-gradient(90deg, transparent 0%, ${v.color} 50%, transparent 100%)`,
        opacity: 0.32, transform: 'rotate(-6deg)',
      }} />
      <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <window.WordmarkAccentDot color={LT2.ink} accent={v.color} size={64} />
      </div>
    </div>
  );
}

// SP5 — Bottom band only — a horizon, dot color picks up the band
function SplashBandBottom({ vibeIndex = 3 }) {
  const v = HUES[vibeIndex];
  return (
    <div style={{ background: LT2.bg, height: '100%', position: 'relative', overflow: 'hidden' }}>
      <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, height: '38%', background: v.color, opacity: 0.20 }} />
      <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, height: 2, background: v.color, opacity: 0.6 }} />
      <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', paddingBottom: '8%' }}>
        <window.WordmarkAccentDot color={LT2.ink} accent={v.color} size={64} />
      </div>
      <div style={{ position: 'absolute', bottom: 28, left: 0, right: 0, textAlign: 'center', fontFamily: LT2.serif, fontStyle: 'italic', fontSize: 13, color: 'rgba(26,23,20,0.65)' }}>
        Listen with intent.
      </div>
    </div>
  );
}

// SP6 — Vertical bands at the side — quieter version of color bleed
function SplashBandSide({ vibeIndex = 4 }) {
  const v = HUES[vibeIndex];
  return (
    <div style={{ background: LT2.bg, height: '100%', position: 'relative', overflow: 'hidden' }}>
      <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: '14%', background: v.color, opacity: 0.85 }} />
      <div style={{ position: 'absolute', left: '14%', top: 0, bottom: 0, width: '6%', background: v.color, opacity: 0.32 }} />
      <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', paddingLeft: '12%' }}>
        <window.WordmarkAccentDot color={LT2.ink} accent={v.color} size={56} />
      </div>
    </div>
  );
}

Object.assign(window, {
  IconSerifV, IconItalicV, IconVEar, IconBracketV, IconSlashV,
  IconBigDot, IconDotV, IconDotCorner, IconEclipse, IconDotHalo, IconPeriod, IconDotMorse,
  SplashBandHorizon, SplashBandStripe, SplashBandSpectrum, SplashBandDiagonal, SplashBandBottom, SplashBandSide,
});
