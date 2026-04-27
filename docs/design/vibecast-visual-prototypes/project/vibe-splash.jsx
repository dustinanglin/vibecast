// Splash screen treatments for Vibecast.
// Each treatment is a phone-sized full-bleed screen.

const ST = window.VIBE_TOKENS;

// Splash A — paper, centered wordmark with an accent dot.
function SplashWordmark({ accent }) {
  return (
    <div style={{ background: ST.bg, height: '100%', position: 'relative', overflow: 'hidden' }}>
      <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <window.WordmarkAccentDot color={ST.ink} accent={accent || window.VIBE_HUES[1].color} size={66} />
      </div>
      <div style={{ position: 'absolute', bottom: 36, left: 0, right: 0, textAlign: 'center', fontFamily: ST.serif, fontStyle: 'italic', fontSize: 14, color: 'rgba(26,23,20,0.55)' }}>
        Listen with intent.
      </div>
    </div>
  );
}

// Splash B — vibe stack as the mark, animated via CSS step-in feel
function SplashStack() {
  return (
    <div style={{ background: ST.bg, height: '100%', position: 'relative', overflow: 'hidden' }}>
      <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 18 }}>
        <window.MarkStack size={150} />
        <span style={{ fontFamily: ST.serif, fontSize: 36, fontWeight: 500, letterSpacing: '-0.03em', color: ST.ink }}>Vibecast</span>
      </div>
      <div style={{ position: 'absolute', bottom: 36, left: 0, right: 0, textAlign: 'center', fontFamily: ST.mono, fontSize: 10, letterSpacing: '0.18em', color: 'rgba(26,23,20,0.40)', textTransform: 'uppercase', fontWeight: 600 }}>
        FIVE VIBES · ONE PLAYER
      </div>
    </div>
  );
}

// Splash C — full-bleed accent color, mark in paper
function SplashColorBleed({ vibeIndex = 1 }) {
  const v = window.VIBE_HUES[vibeIndex];
  return (
    <div style={{ background: v.color, height: '100%', position: 'relative', overflow: 'hidden', color: ST.paper }}>
      <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 16 }}>
        <window.MarkWaves size={112} color={ST.paper} accent={ST.paper} />
        <span style={{ fontFamily: ST.serif, fontSize: 42, fontWeight: 500, letterSpacing: '-0.03em' }}>Vibecast</span>
      </div>
    </div>
  );
}

// Splash D — quiet, type-led, just the italic wordmark
function SplashItalic() {
  return (
    <div style={{ background: ST.paper, height: '100%', position: 'relative', overflow: 'hidden' }}>
      <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <window.WordmarkItalic color={ST.ink} size={78} />
      </div>
    </div>
  );
}

// Splash E — color cards radiating from center, mark on top
function SplashRadiate() {
  return (
    <div style={{ background: ST.bg, height: '100%', position: 'relative', overflow: 'hidden' }}>
      <div style={{ position: 'absolute', top: -60, left: -60, right: -60, bottom: -60, display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 0 }}>
        {window.VIBE_HUES.concat(window.VIBE_HUES).slice(0, 5).map((v, i) => (
          <div key={i} style={{ background: v.color, opacity: 0.12, transform: `translateY(${i * 12}px) rotate(${(i - 2) * 4}deg)` }} />
        ))}
      </div>
      <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 12 }}>
        <window.MarkAppIcon size={120} bg={ST.ink} accent={window.VIBE_HUES[0].color} />
        <span style={{ fontFamily: ST.serif, fontSize: 30, fontWeight: 500, letterSpacing: '-0.03em', color: ST.ink, marginTop: 8 }}>Vibecast</span>
      </div>
    </div>
  );
}

Object.assign(window, { SplashWordmark, SplashStack, SplashColorBleed, SplashItalic, SplashRadiate });
