// Vibes — playback experience.
// Row states: now-playing, up-next-1, up-next-N, played, paused.
// Plus vibe-aware mini player and queue sheet.

const PT = window.VIBE_TOKENS;

// Single source of truth for which row is "now playing", paused, etc.
// pos: index in the vibe order. status: 'played'|'now'|'paused'|'next'|'queued'
function rowStatus(pos, currentPos, paused) {
  if (pos < currentPos) return 'played';
  if (pos === currentPos) return paused ? 'paused' : 'now';
  if (pos === currentPos + 1) return 'next';
  return 'queued';
}

// Animated 3-bar waveform (small, inline)
function MiniBars({ color = '#fff', running = true, size = 16 }) {
  return (
    <div style={{ width: size, height: size, display: 'flex', gap: 1.5, alignItems: 'flex-end', justifyContent: 'center' }}>
      {[0.5, 0.9, 0.4, 0.75].map((h, i) => (
        <div key={i} style={{
          flex: 1, background: color, borderRadius: 1,
          height: `${h * 100}%`,
          animation: running ? `vb-bar ${0.6 + i * 0.1}s ease-in-out ${i * 0.05}s infinite alternate` : 'none',
          transformOrigin: 'bottom',
        }} />
      ))}
    </div>
  );
}

// Vibe playback row — tinted card with state-aware controls.
// Shared visual: vibe gradient background, position number, cover, title block, right-side state control.
function PlaybackRow({ pod, pos, vibe, status, progressPct = 0, onClick }) {
  const vibes = pod.vibes.map(v => window.VIBE_BY_ID[v]);
  const tintBg = vibes.length > 1
    ? `linear-gradient(105deg, ${vibes[0].chip} 0%, ${vibes[1].chip} 100%)`
    : vibes[0].chip;
  const ep = pod.latest;

  const isActive = status === 'now' || status === 'paused';
  const isPlayed = status === 'played';
  const isNext = status === 'next';

  return (
    <div onClick={onClick} style={{
      position: 'relative',
      display: 'flex', gap: 12, padding: 12, marginBottom: 8,
      background: tintBg,
      borderRadius: 14,
      border: isActive ? `2px solid ${vibe.color}` : `1px solid ${PT.hairline}`,
      boxShadow: isActive ? `0 8px 24px ${vibe.color}33` : 'none',
      opacity: isPlayed ? 0.55 : 1,
      cursor: 'pointer', transition: 'opacity .2s',
      overflow: 'hidden',
    }}>
      {/* Active progress sliver across the top */}
      {isActive && (
        <div style={{ position: 'absolute', left: 0, right: 0, top: 0, height: 3, background: 'rgba(0,0,0,0.08)' }}>
          <div style={{ width: `${progressPct}%`, height: '100%', background: vibe.color }} />
        </div>
      )}

      {/* Position number / next badge */}
      <div style={{
        width: 22, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
        flexShrink: 0,
      }}>
        {isActive ? (
          <div style={{
            width: 20, height: 20, borderRadius: 99, background: vibe.color,
            display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
          }}>
            {status === 'now'
              ? <MiniBars color="#fff" running size={10} />
              : <div style={{ display: 'flex', gap: 2 }}><span style={{ width: 2, height: 8, background: '#fff' }} /><span style={{ width: 2, height: 8, background: '#fff' }} /></div>
            }
          </div>
        ) : (
          <div style={{
            fontFamily: PT.mono, fontSize: 11, color: isPlayed ? PT.inkMuted : (isNext ? vibe.ink : PT.inkFaint),
            fontVariantNumeric: 'tabular-nums', fontWeight: isNext ? 700 : 500,
          }}>{String(pos + 1).padStart(2, '0')}</div>
        )}
      </div>

      {/* Cover */}
      <window.VibeCover pod={pod} size={56} />

      {/* Title block */}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{
          display: 'flex', alignItems: 'center', gap: 8,
          fontFamily: PT.mono, fontSize: 10, letterSpacing: '0.10em',
          color: isPlayed ? PT.inkMuted : PT.ink, textTransform: 'uppercase', fontWeight: 600,
        }}>
          <span>{pod.title}</span>
          {isNext && (
            <span style={{
              fontSize: 9, padding: '2px 6px', borderRadius: 99,
              background: vibe.color, color: '#fff', letterSpacing: '0.08em',
            }}>UP NEXT</span>
          )}
          {status === 'paused' && (
            <span style={{ fontSize: 9, color: vibe.ink, letterSpacing: '0.1em' }}>PAUSED</span>
          )}
          <span style={{ marginLeft: 'auto', display: 'inline-flex', gap: 4 }}>
            {vibes.map(v => <window.VibeDot key={v.id} vibe={v} size={7} />)}
          </span>
        </div>
        <div style={{
          fontFamily: PT.serif, fontSize: 16, fontWeight: 500,
          lineHeight: 1.22, marginTop: 3, color: PT.ink, letterSpacing: '-0.005em',
          display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden',
          textDecoration: isPlayed ? 'none' : 'none',
        }}>{ep.title}</div>
        <div style={{
          fontFamily: PT.mono, fontSize: 10, color: PT.inkMuted, letterSpacing: '0.08em',
          textTransform: 'uppercase', marginTop: 5, fontWeight: 600,
          display: 'flex', alignItems: 'center', gap: 8,
        }}>
          {isPlayed && <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>{window.Icon.check(11, PT.inkMuted)} PLAYED</span>}
          {!isPlayed && <span>{ep.total} MIN</span>}
          {isActive && <span style={{ color: vibe.ink }}>· {Math.round(progressPct * ep.total / 100)}M IN</span>}
        </div>
      </div>

      {/* Right-side control */}
      <div style={{ display: 'flex', alignItems: 'center', flexShrink: 0 }}>
        <RowControl status={status} vibe={vibe} />
      </div>
    </div>
  );
}

function RowControl({ status, vibe }) {
  const baseBtn = {
    width: 38, height: 38, borderRadius: 999, border: 'none', cursor: 'pointer',
    display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
  };
  if (status === 'now') {
    return (
      <button style={{ ...baseBtn, background: vibe.color, color: '#fff' }}>
        {window.Icon.pause(16, '#fff')}
      </button>
    );
  }
  if (status === 'paused') {
    return (
      <button style={{ ...baseBtn, background: vibe.color, color: '#fff' }}>
        {window.Icon.play(14, '#fff')}
      </button>
    );
  }
  if (status === 'played') {
    return (
      <button style={{ ...baseBtn, background: 'transparent', color: PT.inkMuted }} title="Replay">
        {window.Icon.resume(15, PT.inkMuted)}
      </button>
    );
  }
  // queued / next
  return (
    <button style={{ ...baseBtn, background: PT.paper, color: PT.ink, border: `1px solid ${PT.hairline}` }} title="Skip to this">
      {window.Icon.play(12, PT.ink)}
    </button>
  );
}

// ─── Vibe-aware mini player ────────────────────────────────
// Sits at the bottom while a vibe is playing. Color cue + queue context.
function VibeMiniPlayer({ pod, vibe, pos, total, paused, progressPct, onExpand }) {
  const ep = pod.latest;
  const upNextLabel = pos < total - 1 ? `Up next · ${pos + 1} of ${total}` : 'Last in vibe';
  return (
    <div onClick={onExpand} style={{
      position: 'absolute', left: 12, right: 12, bottom: 38,
      borderRadius: 16, padding: 10, paddingLeft: 14,
      background: PT.ink, color: PT.paper,
      display: 'flex', gap: 10, alignItems: 'center',
      boxShadow: `0 12px 32px rgba(0,0,0,0.22), 0 0 0 1px ${vibe.color}88`,
      overflow: 'hidden', cursor: 'pointer',
    }}>
      {/* Vibe-color stripe on the left edge */}
      <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: 4, background: vibe.color }} />
      {/* Progress sliver across the bottom */}
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, height: 2, background: 'rgba(255,255,255,0.10)' }}>
        <div style={{ width: `${progressPct}%`, height: '100%', background: vibe.color }} />
      </div>

      <window.VibeCover pod={pod} size={40} radius={4} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{
          display: 'flex', alignItems: 'center', gap: 6,
          fontFamily: PT.mono, fontSize: 9, letterSpacing: '0.12em', textTransform: 'uppercase',
          color: vibe.chip, fontWeight: 700,
        }}>
          <span style={{ width: 6, height: 6, borderRadius: 99, background: vibe.color }} />
          {vibe.name} · {pos + 1}/{total}
        </div>
        <div style={{
          fontFamily: PT.serif, fontSize: 14, fontWeight: 500,
          whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
          letterSpacing: '-0.01em', marginTop: 2,
        }}>{ep.title}</div>
      </div>

      <div style={{ display: 'flex', gap: 4 }}>
        <button style={miniBtn} onClick={e => e.stopPropagation()}>{window.Icon.back15(22, PT.paper)}</button>
        <button style={miniBtn} onClick={e => e.stopPropagation()}>
          {paused ? window.Icon.play(20, PT.paper) : window.Icon.pause(20, PT.paper)}
        </button>
        <button style={miniBtn} onClick={e => e.stopPropagation()}>{window.Icon.fwd30(22, PT.paper)}</button>
      </div>
    </div>
  );
}
const miniBtn = {
  width: 34, height: 34, border: 'none', background: 'transparent', color: PT.paper,
  display: 'inline-flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer',
};

Object.assign(window, { rowStatus, MiniBars, PlaybackRow, VibeMiniPlayer });
