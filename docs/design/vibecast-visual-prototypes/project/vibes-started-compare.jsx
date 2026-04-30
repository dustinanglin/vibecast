// Started-row comparison: loud (current) vs quiet (proposed).
// Side-by-side mock so we can pick one.

const SCT = window.VIBE_TOKENS;

function PRing({ pct = 0, color, size = 22, ring = 2.2, mute = false }) {
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

// LOUD — current treatment: ring + bottom sliver + bold ep title + tinted chip + outlined resume button
function StartedRowLoud({ pod, vibe, progressPct = 36 }) {
  const vibes = pod.vibes.map(v => window.VIBE_BY_ID[v]);
  const tintBg = vibes.length > 1 ? `linear-gradient(105deg, ${vibes[0].chip} 0%, ${vibes[1].chip} 100%)` : vibes[0].chip;
  const ep = pod.latest;
  const minLeft = Math.max(1, Math.round(ep.total * (1 - progressPct / 100)));
  return (
    <div style={{
      position: 'relative', display: 'flex', gap: 12, padding: 12, marginBottom: 8,
      background: tintBg, borderRadius: 14, border: `1px solid ${SCT.hairline}`, overflow: 'hidden',
    }}>
      <div style={{ width: 28, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
        <PRing pct={progressPct} color={vibe.color} size={22} />
      </div>
      <window.VibeCover pod={pod} size={56} radius={4} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontFamily: SCT.mono, fontSize: 10, letterSpacing: '0.10em', color: SCT.ink, textTransform: 'uppercase', fontWeight: 600 }}>
          <span>{pod.title}</span>
          <span style={{ color: vibe.ink, fontWeight: 700 }}>· {minLeft}M LEFT</span>
        </div>
        <div style={{ fontFamily: SCT.serif, fontSize: 15, fontWeight: 500, lineHeight: 1.22, marginTop: 3, color: SCT.ink, letterSpacing: '-0.005em', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>{ep.title}</div>
        <div style={{ fontFamily: SCT.mono, fontSize: 9, color: SCT.inkMuted, letterSpacing: '0.06em', marginTop: 4, fontWeight: 600 }}>PAUSED AT {Math.round(ep.total * progressPct / 100)}M · {ep.total} MIN TOTAL</div>
      </div>
      <div style={{ display: 'flex', alignItems: 'center' }}>
        <button style={{ width: 38, height: 38, borderRadius: 999, background: 'transparent', border: `1.5px solid ${vibe.color}`, color: vibe.ink, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
          {window.Icon.play(13, vibe.ink)}
        </button>
      </div>
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, height: 2, background: 'rgba(0,0,0,0.06)' }}>
        <div style={{ width: `${progressPct}%`, height: '100%', background: vibe.color, opacity: 0.65 }} />
      </div>
    </div>
  );
}

// QUIET — proposed: position number stays in left slot, tiny ring inline with eyebrow,
// no bottom sliver, italic title at 72%, eyebrow carries the signal.
function StartedRowQuiet({ pod, pos, vibe, progressPct = 36 }) {
  const vibes = pod.vibes.map(v => window.VIBE_BY_ID[v]);
  const tintBg = vibes.length > 1 ? `linear-gradient(105deg, ${vibes[0].chip} 0%, ${vibes[1].chip} 100%)` : vibes[0].chip;
  const ep = pod.latest;
  const minLeft = Math.max(1, Math.round(ep.total * (1 - progressPct / 100)));
  return (
    <div style={{
      display: 'flex', gap: 12, padding: 12, marginBottom: 8,
      background: tintBg, borderRadius: 14, border: `1px solid ${SCT.hairline}`,
    }}>
      <div style={{ width: 28, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
        fontFamily: SCT.mono, fontSize: 12, fontWeight: 600, color: 'rgba(0,0,0,0.40)', letterSpacing: '0.04em' }}>
        {String(pos).padStart(2, '0')}
      </div>
      <window.VibeCover pod={pod} size={56} radius={4} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontFamily: SCT.mono, fontSize: 10, letterSpacing: '0.10em', color: SCT.ink, textTransform: 'uppercase', fontWeight: 600 }}>
          <PRing pct={progressPct} color={vibe.color} size={11} ring={1.6} mute />
          <span style={{ color: vibe.ink, fontWeight: 700 }}>{minLeft}M LEFT</span>
          <span style={{ color: 'rgba(0,0,0,0.40)' }}>· {pod.title}</span>
        </div>
        <div style={{ fontFamily: SCT.serif, fontSize: 15, fontWeight: 500, fontStyle: 'italic', lineHeight: 1.22, marginTop: 3, color: 'rgba(26,23,20,0.72)', letterSpacing: '-0.005em', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>{ep.title}</div>
      </div>
      <div style={{ display: 'flex', alignItems: 'center' }}>
        <button style={{ width: 38, height: 38, borderRadius: 999, background: SCT.paper, border: `1px solid ${SCT.hairline}`, color: SCT.ink, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
          {window.Icon.play(13, SCT.ink)}
        </button>
      </div>
    </div>
  );
}

// A faux unplayed row & played row to give context (so we can see hierarchy)
function NeighborRow({ pod, pos, kind = 'unplayed' }) {
  const vibes = pod.vibes.map(v => window.VIBE_BY_ID[v]);
  const tintBg = vibes.length > 1 ? `linear-gradient(105deg, ${vibes[0].chip} 0%, ${vibes[1].chip} 100%)` : vibes[0].chip;
  const ep = pod.latest;
  const muted = kind === 'played';
  return (
    <div style={{ display: 'flex', gap: 12, padding: 12, marginBottom: 8, background: tintBg, borderRadius: 14, border: `1px solid ${SCT.hairline}`, opacity: muted ? 0.55 : 1 }}>
      <div style={{ width: 28, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
        fontFamily: SCT.mono, fontSize: 12, fontWeight: 600, color: 'rgba(0,0,0,0.40)', letterSpacing: '0.04em' }}>
        {muted ? '✓' : String(pos).padStart(2, '0')}
      </div>
      <window.VibeCover pod={pod} size={56} radius={4} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontFamily: SCT.mono, fontSize: 10, letterSpacing: '0.10em', color: SCT.ink, textTransform: 'uppercase', fontWeight: 600 }}>
          {pod.title}{muted ? ' · ✓ PLAYED' : ` · LATEST · ${ep.total} MIN`}
        </div>
        <div style={{ fontFamily: SCT.serif, fontSize: 15, fontWeight: 500, lineHeight: 1.22, marginTop: 3, color: SCT.ink, letterSpacing: '-0.005em', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>{ep.title}</div>
      </div>
      <div style={{ display: 'flex', alignItems: 'center' }}>
        <button style={{ width: 38, height: 38, borderRadius: 999, background: muted ? 'transparent' : SCT.paper, border: `1px solid ${SCT.hairline}`, display: 'inline-flex', alignItems: 'center', justifyContent: 'center' }}>
          {muted ? window.Icon.replay?.(13, SCT.ink) || window.Icon.play(13, SCT.ink) : window.Icon.play(13, SCT.ink)}
        </button>
      </div>
    </div>
  );
}

Object.assign(window, { StartedRowLoud, StartedRowQuiet, NeighborRow: NeighborRow });
