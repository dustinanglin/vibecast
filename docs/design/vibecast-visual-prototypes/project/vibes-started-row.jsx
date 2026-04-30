// Started (partially played) row state — addition to vibes-playback.jsx vocabulary.
// Standalone artboard so we can review side-by-side with the existing states.

const STT = window.VIBE_TOKENS;

function ProgressRing({ pct = 0, color, size = 22, ring = 2.2 }) {
  const r = (size - ring) / 2;
  const c = 2 * Math.PI * r;
  const off = c * (1 - Math.max(0, Math.min(1, pct / 100)));
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{ display: 'block' }}>
      <circle cx={size/2} cy={size/2} r={r} fill="none" stroke={color} strokeOpacity="0.22" strokeWidth={ring} />
      <circle cx={size/2} cy={size/2} r={r} fill="none" stroke={color} strokeWidth={ring} strokeLinecap="round"
              strokeDasharray={c} strokeDashoffset={off} transform={`rotate(-90 ${size/2} ${size/2})`} />
    </svg>
  );
}

// Started row — partially played, not currently the active row.
function StartedRow({ pod, pos, vibe, progressPct = 70, onClick }) {
  const vibes = pod.vibes.map(v => window.VIBE_BY_ID[v]);
  const tintBg = vibes.length > 1
    ? `linear-gradient(105deg, ${vibes[0].chip} 0%, ${vibes[1].chip} 100%)`
    : vibes[0].chip;
  const ep = pod.latest;
  const minLeft = Math.max(1, Math.round(ep.total * (1 - progressPct / 100)));

  return (
    <div onClick={onClick} style={{
      position: 'relative',
      display: 'flex', gap: 12, padding: 12, marginBottom: 8,
      background: tintBg, borderRadius: 14,
      border: `1px solid ${STT.hairline}`,
      cursor: 'pointer', overflow: 'hidden',
    }}>
      {/* Left slot — progress ring instead of position number */}
      <div style={{ width: 28, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
        <ProgressRing pct={progressPct} color={vibe.color} size={22} />
      </div>

      {/* Cover */}
      <window.VibeCover pod={pod} size={56} radius={4} />

      {/* Title block */}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{
          display: 'flex', alignItems: 'center', gap: 8,
          fontFamily: STT.mono, fontSize: 10, letterSpacing: '0.10em',
          color: STT.ink, textTransform: 'uppercase', fontWeight: 600,
        }}>
          <span>{pod.title}</span>
          <span style={{ color: vibe.ink, fontWeight: 700 }}>· {minLeft}M LEFT</span>
        </div>
        <div style={{
          fontFamily: STT.serif, fontSize: 15, fontWeight: 500,
          lineHeight: 1.22, marginTop: 3, color: STT.ink, letterSpacing: '-0.005em',
          display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden',
        }}>{ep.title}</div>
        <div style={{
          fontFamily: STT.mono, fontSize: 9, color: STT.inkMuted, letterSpacing: '0.06em',
          marginTop: 4, fontWeight: 600,
        }}>
          PAUSED AT {Math.round(ep.total * progressPct / 100)}M · {ep.total} MIN TOTAL
        </div>
      </div>

      {/* Right control — vibe-outlined resume button */}
      <div style={{ display: 'flex', alignItems: 'center' }}>
        <button style={{
          width: 38, height: 38, borderRadius: 999,
          background: 'transparent', border: `1.5px solid ${vibe.color}`,
          color: vibe.ink, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer',
        }} title="Resume from where you left off">
          {window.Icon.play(13, vibe.ink)}
        </button>
      </div>

      {/* Bottom progress sliver */}
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, height: 2, background: 'rgba(0,0,0,0.06)' }}>
        <div style={{ width: `${progressPct}%`, height: '100%', background: vibe.color, opacity: 0.65 }} />
      </div>
    </div>
  );
}

Object.assign(window, { StartedRow, ProgressRing });
