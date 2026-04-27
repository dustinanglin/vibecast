// Start Vibing — full screens (in-progress, queue sheet, now playing, paused, complete).

const SVT = window.VIBE_TOKENS;

function VibingScreen({ vibeId, currentPos = 1, paused = false, progress = 38, label }) {
  const vibe = window.VIBE_BY_ID[vibeId];
  const podcasts = window.VIBE_ORDER[vibeId].map(id => window.PODCAST_BY_ID[id]);
  const current = podcasts[currentPos];
  return (
    <div style={{ background: SVT.bg, minHeight: '100%', color: SVT.ink, fontFamily: SVT.sans, paddingBottom: 110, position: 'relative' }}>
      {/* Vibe color band */}
      <div style={{
        position: 'absolute', top: 0, left: 0, right: 0, height: 240,
        background: `linear-gradient(180deg, ${vibe.chip} 0%, ${SVT.bg} 100%)`,
      }} />
      {/* Header */}
      <div style={{ position: 'relative', padding: '60px 22px 14px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div style={{
            display: 'inline-flex', alignItems: 'center', gap: 8,
            fontFamily: SVT.mono, fontSize: 10, letterSpacing: '0.18em',
            textTransform: 'uppercase', color: vibe.ink, fontWeight: 700,
          }}>
            <span style={{ width: 6, height: 6, borderRadius: 99, background: vibe.color, animation: paused ? 'none' : 'vb-pulse 1.6s ease-in-out infinite' }} />
            {paused ? 'PAUSED' : 'VIBING'}
          </div>
          <button style={{
            width: 36, height: 36, borderRadius: 999, border: `1px solid ${SVT.hairline}`,
            background: SVT.paper, color: SVT.ink, cursor: 'pointer',
            display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
          }}>{window.Icon.more(17, SVT.ink)}</button>
        </div>
        <h1 style={{
          fontFamily: SVT.serif, fontSize: 42, fontWeight: 500,
          letterSpacing: '-0.025em', margin: '10px 0 4px', lineHeight: 1.05,
        }}>{vibe.name}</h1>
        <div style={{ fontFamily: SVT.serif, fontStyle: 'italic', fontSize: 14, color: SVT.inkDim }}>
          {currentPos + 1} of {podcasts.length} · about {Math.round(podcasts.slice(currentPos).reduce((a, p) => a + p.latest.total, 0) / 60 * 10) / 10}h left
        </div>

        {label && (
          <div style={{
            marginTop: 12, padding: '6px 10px', display: 'inline-flex',
            background: SVT.paper, border: `1px dashed ${SVT.inkFaint}`, borderRadius: 6,
            fontFamily: SVT.mono, fontSize: 9, letterSpacing: '0.12em',
            color: SVT.inkMuted, textTransform: 'uppercase', fontWeight: 600,
          }}>{label}</div>
        )}
      </div>

      {/* Section eyebrow */}
      <div style={{ position: 'relative', padding: '4px 22px 8px', display: 'flex', alignItems: 'center', gap: 10 }}>
        <div style={{
          fontFamily: SVT.mono, fontSize: 10, letterSpacing: '0.18em', textTransform: 'uppercase',
          color: SVT.inkDim, fontWeight: 600,
        }}>QUEUE</div>
        <div style={{ flex: 1, height: 1, background: SVT.hairline }} />
        <div style={{ fontFamily: SVT.mono, fontSize: 10, letterSpacing: '0.06em', color: SVT.inkMuted }}>EDIT</div>
      </div>

      {/* Rows */}
      <div style={{ position: 'relative', padding: '0 16px' }}>
        {podcasts.map((pod, i) => {
          const status = window.rowStatus(i, currentPos, paused);
          return (
            <window.PlaybackRow
              key={pod.id}
              pod={pod}
              pos={i}
              vibe={vibe}
              status={status}
              progressPct={status === 'now' || status === 'paused' ? progress : 0}
            />
          );
        })}
      </div>

      <window.VibeMiniPlayer
        pod={current} vibe={vibe} pos={currentPos} total={podcasts.length}
        paused={paused} progressPct={progress}
      />
    </div>
  );
}

// Vibe Now Playing — full-screen player with vibe context footer
function VibingNowPlaying({ vibeId, currentPos = 1 }) {
  const vibe = window.VIBE_BY_ID[vibeId];
  const podcasts = window.VIBE_ORDER[vibeId].map(id => window.PODCAST_BY_ID[id]);
  const pod = podcasts[currentPos];
  const next = podcasts[currentPos + 1];
  const ep = pod.latest;
  return (
    <div style={{ background: SVT.paper, minHeight: '100%', color: SVT.ink, fontFamily: SVT.sans, position: 'relative', overflow: 'hidden', paddingBottom: 0 }}>
      {/* vibe wash */}
      <div style={{
        position: 'absolute', top: 0, left: 0, right: 0, height: 320,
        background: `linear-gradient(180deg, ${vibe.chip} 0%, ${SVT.paper} 100%)`,
      }} />
      <div style={{ position: 'relative', paddingTop: 56, display: 'flex', justifyContent: 'center' }}>
        <div style={{ width: 36, height: 4, borderRadius: 99, background: 'rgba(26,23,20,0.20)' }} />
      </div>
      <div style={{ position: 'relative', padding: '12px 22px 0', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <button style={hdrBtn}>{window.Icon.chevronDown(18, SVT.ink)}</button>
        <div style={{
          display: 'inline-flex', alignItems: 'center', gap: 8,
          fontFamily: SVT.mono, fontSize: 10, letterSpacing: '0.16em',
          textTransform: 'uppercase', color: vibe.ink, fontWeight: 700,
        }}>
          <span style={{ width: 6, height: 6, borderRadius: 99, background: vibe.color, animation: 'vb-pulse 1.6s ease-in-out infinite' }} />
          Vibing · {vibe.name}
        </div>
        <button style={hdrBtn}>{window.Icon.more(17, SVT.ink)}</button>
      </div>

      {/* Editorial title spread */}
      <div style={{ position: 'relative', padding: '32px 28px 8px' }}>
        <div style={{ fontFamily: SVT.mono, fontSize: 10, color: vibe.ink, letterSpacing: '0.16em', textTransform: 'uppercase', fontWeight: 700 }}>
          {pod.title} · {currentPos + 1} of {podcasts.length}
        </div>
        <h2 style={{
          fontFamily: SVT.serif, fontSize: 30, fontWeight: 500,
          lineHeight: 1.05, letterSpacing: '-0.025em', margin: '14px 0 12px',
          textWrap: 'balance',
        }}>{ep.title}</h2>
        <div style={{ fontFamily: SVT.serif, fontStyle: 'italic', fontSize: 14, color: SVT.inkDim, lineHeight: 1.45 }}>
          {ep.blurb}
        </div>
      </div>

      <div style={{ position: 'relative', padding: '12px 28px 0', display: 'flex', alignItems: 'center', gap: 14 }}>
        <window.VibeCover pod={pod} size={64} radius={4} />
        <div style={{ flex: 1 }}>
          <div style={{ fontFamily: SVT.mono, fontSize: 10, color: SVT.inkMuted, letterSpacing: '0.10em', textTransform: 'uppercase' }}>FROM</div>
          <div style={{ fontFamily: SVT.serif, fontSize: 14, marginTop: 2 }}>{pod.publisher}</div>
        </div>
      </div>

      {/* Scrubber */}
      <div style={{ position: 'relative', padding: '24px 28px 4px' }}>
        <div style={{ position: 'relative', height: 4, background: 'rgba(26,23,20,0.10)', borderRadius: 99 }}>
          <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: '38%', background: vibe.color, borderRadius: 99 }} />
          <div style={{ position: 'absolute', left: '38%', top: '50%', transform: 'translate(-50%, -50%)', width: 14, height: 14, borderRadius: 99, background: vibe.color, border: `2px solid ${SVT.paper}`, boxShadow: '0 1px 3px rgba(0,0,0,0.2)' }} />
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 10, fontFamily: SVT.mono, fontSize: 11, color: SVT.inkMuted, letterSpacing: '0.06em' }}>
          <span>23:32</span><span>-{ep.total - 23}:00</span>
        </div>
      </div>

      {/* Transport */}
      <div style={{ position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 26, padding: '10px 0 6px' }}>
        <button style={tBtn}>{window.Icon.back15(28, SVT.ink)}</button>
        <button style={{
          width: 70, height: 70, borderRadius: 999, border: 'none',
          background: vibe.color, color: '#fff',
          display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
          boxShadow: `0 6px 20px ${vibe.color}55`, cursor: 'pointer',
        }}>{window.Icon.pause(28, '#fff')}</button>
        <button style={tBtn}>{window.Icon.fwd30(28, SVT.ink)}</button>
      </div>

      {/* Up next ribbon */}
      {next && (
        <div style={{
          position: 'relative', margin: '24px 16px 16px', borderRadius: 14,
          background: SVT.paper, border: `1px solid ${SVT.hairline}`, padding: '12px',
          display: 'flex', alignItems: 'center', gap: 12,
        }}>
          <div style={{
            fontFamily: SVT.mono, fontSize: 9, padding: '2px 6px', borderRadius: 99,
            background: vibe.color, color: '#fff', letterSpacing: '0.08em', fontWeight: 700,
          }}>UP NEXT</div>
          <window.VibeCover pod={next} size={36} radius={4} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontFamily: SVT.mono, fontSize: 10, letterSpacing: '0.08em', textTransform: 'uppercase', color: SVT.inkMuted, fontWeight: 600 }}>
              {next.title}
            </div>
            <div style={{
              fontFamily: SVT.serif, fontSize: 13, fontWeight: 500, marginTop: 2,
              whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
            }}>{next.latest.title}</div>
          </div>
          <button style={{
            width: 34, height: 34, borderRadius: 999, border: `1px solid ${SVT.hairline}`,
            background: 'transparent', color: SVT.ink, cursor: 'pointer',
            display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
          }}>{window.Icon.fwd30(18, SVT.ink)}</button>
        </div>
      )}
    </div>
  );
}

const hdrBtn = {
  width: 36, height: 36, borderRadius: 999, border: `1px solid ${SVT.hairline}`,
  background: SVT.paper, color: SVT.ink, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer',
};
const tBtn = {
  width: 56, height: 56, border: 'none', background: 'transparent', color: SVT.ink,
  display: 'inline-flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer',
};

// Vibe complete (every show played)
function VibingCompleteScreen({ vibeId }) {
  const vibe = window.VIBE_BY_ID[vibeId];
  const podcasts = window.VIBE_ORDER[vibeId].map(id => window.PODCAST_BY_ID[id]);
  return (
    <div style={{ background: SVT.bg, minHeight: '100%', color: SVT.ink, fontFamily: SVT.sans, position: 'relative', paddingBottom: 24 }}>
      <div style={{
        position: 'absolute', top: 0, left: 0, right: 0, height: 240,
        background: `linear-gradient(180deg, ${vibe.chip} 0%, ${SVT.bg} 100%)`,
      }} />
      <div style={{ position: 'relative', padding: '60px 22px 14px' }}>
        <div style={{
          display: 'inline-flex', alignItems: 'center', gap: 8,
          fontFamily: SVT.mono, fontSize: 10, letterSpacing: '0.18em',
          textTransform: 'uppercase', color: vibe.ink, fontWeight: 700, marginBottom: 10,
        }}>
          <span style={{ width: 6, height: 6, borderRadius: 99, background: vibe.color }} />
          VIBE COMPLETE
        </div>
        <h1 style={{ fontFamily: SVT.serif, fontSize: 38, fontWeight: 500, letterSpacing: '-0.025em', margin: '0 0 6px', lineHeight: 1.05 }}>
          That was a good vibe.
        </h1>
        <div style={{ fontFamily: SVT.serif, fontStyle: 'italic', fontSize: 14, color: SVT.inkDim }}>
          You finished {podcasts.length} shows · {Math.round(podcasts.reduce((a, p) => a + p.latest.total, 0) / 60 * 10) / 10}h.
        </div>
        <div style={{ display: 'flex', gap: 10, marginTop: 18 }}>
          <button style={{
            background: vibe.color, color: '#fff', border: 'none',
            padding: '10px 16px', borderRadius: 999, fontSize: 14, fontWeight: 600,
            display: 'inline-flex', alignItems: 'center', gap: 8, cursor: 'pointer',
          }}>{window.Icon.resume(13, '#fff')} Restart</button>
          <button style={{
            background: SVT.paper, color: SVT.ink, border: `1px solid ${SVT.hairline}`,
            padding: '10px 16px', borderRadius: 999, fontSize: 14, fontWeight: 500, cursor: 'pointer',
          }}>Pick another vibe</button>
        </div>
      </div>

      <div style={{ position: 'relative', padding: '12px 22px 8px' }}>
        <div style={{ fontFamily: SVT.mono, fontSize: 10, letterSpacing: '0.18em', textTransform: 'uppercase', color: SVT.inkDim, fontWeight: 600 }}>
          PLAYED
        </div>
      </div>
      <div style={{ position: 'relative', padding: '0 16px' }}>
        {podcasts.map((pod, i) => (
          <window.PlaybackRow key={pod.id} pod={pod} pos={i} vibe={vibe} status="played" />
        ))}
      </div>
    </div>
  );
}

Object.assign(window, { VibingScreen, VibingNowPlaying, VibingCompleteScreen });
