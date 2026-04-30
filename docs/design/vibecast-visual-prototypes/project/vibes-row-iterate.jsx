// Iteration on row vocabulary:
//  · Started rows — try Fraunces 300 (light), upright vs italic
//  · Unplayed rows — explore attractor treatments at the position slot

const RIT = window.VIBE_TOKENS;

function PRing({ pct = 0, color, size = 11, ring = 1.6, mute = true }) {
  const r = (size - ring) / 2;
  const c = 2 * Math.PI * r;
  const off = c * (1 - Math.max(0, Math.min(1, pct / 100)));
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{ display: 'block' }}>
      <circle cx={size/2} cy={size/2} r={r} fill="none" stroke={color} strokeOpacity={mute ? 0.18 : 0.22} strokeWidth={ring} />
      <circle cx={size/2} cy={size/2} r={r} fill="none" stroke={color} strokeWidth={ring} strokeLinecap="round"
              strokeDasharray={c} strokeDashoffset={off} transform={`rotate(-90 ${size/2} ${size/2})`} />
    </svg>
  );
}

function tintBg(pod) {
  const vibes = pod.vibes.map(v => window.VIBE_BY_ID[v]);
  return vibes.length > 1 ? `linear-gradient(105deg, ${vibes[0].chip} 0%, ${vibes[1].chip} 100%)` : vibes[0].chip;
}

// ── STARTED variants ─────────────────────────────────
function StartedLight({ pod, pos, vibe, progressPct = 36, italic = false }) {
  const ep = pod.latest;
  const minLeft = Math.max(1, Math.round(ep.total * (1 - progressPct / 100)));
  return (
    <div style={{ display: 'flex', gap: 12, padding: 12, marginBottom: 8, background: tintBg(pod), borderRadius: 14, border: `1px solid ${RIT.hairline}` }}>
      <div style={{ width: 28, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
        fontFamily: RIT.mono, fontSize: 12, fontWeight: 600, color: 'rgba(0,0,0,0.40)', letterSpacing: '0.04em' }}>
        {String(pos).padStart(2, '0')}
      </div>
      <window.VibeCover pod={pod} size={56} radius={4} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontFamily: RIT.mono, fontSize: 10, letterSpacing: '0.10em', color: RIT.ink, textTransform: 'uppercase', fontWeight: 600 }}>
          <PRing pct={progressPct} color={vibe.color} size={11} ring={1.6} mute />
          <span style={{ color: vibe.ink, fontWeight: 700 }}>{minLeft}M LEFT</span>
          <span style={{ color: 'rgba(0,0,0,0.40)' }}>· {pod.title}</span>
        </div>
        <div style={{
          fontFamily: RIT.serif, fontSize: 15,
          fontWeight: 300, fontStyle: italic ? 'italic' : 'normal',
          lineHeight: 1.22, marginTop: 3, color: 'rgba(26,23,20,0.78)', letterSpacing: '-0.005em',
          display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>{ep.title}</div>
      </div>
      <div style={{ display: 'flex', alignItems: 'center' }}>
        <button style={{ width: 38, height: 38, borderRadius: 999, background: RIT.paper, border: `1px solid ${RIT.hairline}`, color: RIT.ink, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
          {window.Icon.play(13, RIT.ink)}
        </button>
      </div>
    </div>
  );
}

// ── PLAYED row (reused) ──────────────────────────────
function PlayedRow({ pod }) {
  const ep = pod.latest;
  return (
    <div style={{ display: 'flex', gap: 12, padding: 12, marginBottom: 8, background: tintBg(pod), borderRadius: 14, border: `1px solid ${RIT.hairline}`, opacity: 0.55 }}>
      <div style={{ width: 28, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
        fontFamily: RIT.mono, fontSize: 12, fontWeight: 600, color: 'rgba(0,0,0,0.40)' }}>✓</div>
      <window.VibeCover pod={pod} size={56} radius={4} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontFamily: RIT.mono, fontSize: 10, letterSpacing: '0.10em', color: RIT.ink, textTransform: 'uppercase', fontWeight: 600 }}>
          {pod.title} · ✓ PLAYED
        </div>
        <div style={{ fontFamily: RIT.serif, fontSize: 15, fontWeight: 500, lineHeight: 1.22, marginTop: 3, color: RIT.ink, letterSpacing: '-0.005em', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>{ep.title}</div>
      </div>
      <div style={{ display: 'flex', alignItems: 'center' }}>
        <button style={{ width: 38, height: 38, borderRadius: 999, background: 'transparent', border: `1px solid ${RIT.hairline}`, display: 'inline-flex', alignItems: 'center', justifyContent: 'center' }}>
          {window.Icon.play(13, RIT.ink)}
        </button>
      </div>
    </div>
  );
}

// ── UNPLAYED variants — different attractors at the position slot ──
// A · Plain — current baseline. Position number, mono, muted.
function Unplayed_A({ pod, pos }) {
  const ep = pod.latest;
  return (
    <div style={{ display: 'flex', gap: 12, padding: 12, marginBottom: 8, background: tintBg(pod), borderRadius: 14, border: `1px solid ${RIT.hairline}` }}>
      <div style={{ width: 28, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
        fontFamily: RIT.mono, fontSize: 12, fontWeight: 600, color: 'rgba(0,0,0,0.40)', letterSpacing: '0.04em' }}>
        {String(pos).padStart(2, '0')}
      </div>
      <window.VibeCover pod={pod} size={56} radius={4} />
      <Body pod={pod} ep={ep} accent={null} />
      <PlayBtn />
    </div>
  );
}
// B · Vibe-colored dot above the position number
function Unplayed_B({ pod, pos, vibe }) {
  const ep = pod.latest;
  return (
    <div style={{ display: 'flex', gap: 12, padding: 12, marginBottom: 8, background: tintBg(pod), borderRadius: 14, border: `1px solid ${RIT.hairline}` }}>
      <div style={{ width: 28, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', flexShrink: 0, gap: 3 }}>
        <span style={{ width: 6, height: 6, borderRadius: 999, background: vibe.color, display: 'block' }} />
        <span style={{ fontFamily: RIT.mono, fontSize: 11, fontWeight: 600, color: 'rgba(0,0,0,0.55)', letterSpacing: '0.04em' }}>{String(pos).padStart(2, '0')}</span>
      </div>
      <window.VibeCover pod={pod} size={56} radius={4} />
      <Body pod={pod} ep={ep} accent={null} />
      <PlayBtn />
    </div>
  );
}
// C · Position number in vibe ink color (no extra glyph — just stronger)
function Unplayed_C({ pod, pos, vibe }) {
  const ep = pod.latest;
  return (
    <div style={{ display: 'flex', gap: 12, padding: 12, marginBottom: 8, background: tintBg(pod), borderRadius: 14, border: `1px solid ${RIT.hairline}` }}>
      <div style={{ width: 28, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
        fontFamily: RIT.mono, fontSize: 13, fontWeight: 700, color: vibe.ink, letterSpacing: '0.04em' }}>
        {String(pos).padStart(2, '0')}
      </div>
      <window.VibeCover pod={pod} size={56} radius={4} />
      <Body pod={pod} ep={ep} accent={null} />
      <PlayBtn />
    </div>
  );
}
// D · Subtle vibe-color sliver on the left edge of the whole row
function Unplayed_D({ pod, pos, vibe }) {
  const ep = pod.latest;
  return (
    <div style={{ position: 'relative', display: 'flex', gap: 12, padding: 12, marginBottom: 8, background: tintBg(pod), borderRadius: 14, border: `1px solid ${RIT.hairline}`, overflow: 'hidden' }}>
      <span style={{ position: 'absolute', left: 0, top: 8, bottom: 8, width: 3, background: vibe.color, borderRadius: 2 }} />
      <div style={{ width: 28, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
        fontFamily: RIT.mono, fontSize: 12, fontWeight: 600, color: 'rgba(0,0,0,0.55)', letterSpacing: '0.04em', paddingLeft: 4 }}>
        {String(pos).padStart(2, '0')}
      </div>
      <window.VibeCover pod={pod} size={56} radius={4} />
      <Body pod={pod} ep={ep} accent={null} />
      <PlayBtn />
    </div>
  );
}
// E · Tiny play triangle replaces position; number moves into eyebrow
function Unplayed_E({ pod, pos, vibe }) {
  const ep = pod.latest;
  return (
    <div style={{ display: 'flex', gap: 12, padding: 12, marginBottom: 8, background: tintBg(pod), borderRadius: 14, border: `1px solid ${RIT.hairline}` }}>
      <div style={{ width: 28, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
        <svg width="11" height="13" viewBox="0 0 11 13"><polygon points="0,0 11,6.5 0,13" fill={vibe.color} /></svg>
      </div>
      <window.VibeCover pod={pod} size={56} radius={4} />
      <Body pod={pod} ep={ep} accent={`${String(pos).padStart(2,'0')} · `} />
      <PlayBtn />
    </div>
  );
}
// F · Small vibe-colored "NEW" badge in eyebrow when episode is fresh (≤7d)
function Unplayed_F({ pod, pos, vibe, isFresh = true }) {
  const ep = pod.latest;
  return (
    <div style={{ display: 'flex', gap: 12, padding: 12, marginBottom: 8, background: tintBg(pod), borderRadius: 14, border: `1px solid ${RIT.hairline}` }}>
      <div style={{ width: 28, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
        fontFamily: RIT.mono, fontSize: 12, fontWeight: 600, color: 'rgba(0,0,0,0.40)', letterSpacing: '0.04em' }}>
        {String(pos).padStart(2, '0')}
      </div>
      <window.VibeCover pod={pod} size={56} radius={4} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontFamily: RIT.mono, fontSize: 10, letterSpacing: '0.10em', color: RIT.ink, textTransform: 'uppercase', fontWeight: 600 }}>
          <span>{pod.title}</span>
          {isFresh && <span style={{ background: vibe.color, color: '#fff', padding: '1px 6px', borderRadius: 99, fontSize: 8, letterSpacing: '0.10em', fontWeight: 700 }}>NEW</span>}
          <span style={{ color: 'rgba(0,0,0,0.40)' }}>· {ep.total}M</span>
        </div>
        <div style={{ fontFamily: RIT.serif, fontSize: 15, fontWeight: 500, lineHeight: 1.22, marginTop: 3, color: RIT.ink, letterSpacing: '-0.005em', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>{ep.title}</div>
      </div>
      <PlayBtn />
    </div>
  );
}

function Body({ pod, ep, accent }) {
  return (
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ fontFamily: RIT.mono, fontSize: 10, letterSpacing: '0.10em', color: RIT.ink, textTransform: 'uppercase', fontWeight: 600 }}>
        {accent || ''}{pod.title} · {ep.total}M
      </div>
      <div style={{ fontFamily: RIT.serif, fontSize: 15, fontWeight: 500, lineHeight: 1.22, marginTop: 3, color: RIT.ink, letterSpacing: '-0.005em', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>{ep.title}</div>
    </div>
  );
}
function PlayBtn() {
  return (
    <div style={{ display: 'flex', alignItems: 'center' }}>
      <button style={{ width: 38, height: 38, borderRadius: 999, background: RIT.paper, border: `1px solid ${RIT.hairline}`, display: 'inline-flex', alignItems: 'center', justifyContent: 'center' }}>
        {window.Icon.play(13, RIT.ink)}
      </button>
    </div>
  );
}

Object.assign(window, {
  StartedLight, PlayedRow,
  Unplayed_A, Unplayed_B, Unplayed_C, Unplayed_D, Unplayed_E, Unplayed_F,
});
