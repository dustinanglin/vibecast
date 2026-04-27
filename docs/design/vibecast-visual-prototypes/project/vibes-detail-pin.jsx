// Pinned-episode rows + podcast detail screen + on-a-plane vibe screen
// + pin action sheet + reorder mode + post-play expiration.

const PT2 = window.VIBE_TOKENS;

// Inline pin glyph (small "pinned tape" tag)
const PinIcon = (s = 12, c = 'currentColor') => (
  <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M9 2h6l-1 6 4 4v3H5v-3l4-4-1-6z" /><path d="M12 15v6" />
  </svg>
);

// Row variant for the pinned-vibe queue. Pinned items get a left-edge tape graphic +
// "PINNED" pill; show items get a "LATEST" eyebrow. Both use the existing PlaybackRow vocabulary.
function PinQueueRow({ item, vibe, status, progressPct = 0, onClick, dragHandle }) {
  const { pod, ep, pinned, pinnedAt } = window.resolveQueueItem(item);
  const vibes = pod.vibes.map(v => window.VIBE_BY_ID[v]).filter(Boolean);
  const tintBg = vibes.length > 1
    ? `linear-gradient(105deg, ${vibes[0].chip} 0%, ${vibes[1].chip} 100%)`
    : (vibes[0] || vibe).chip;

  const isActive = status === 'now' || status === 'paused';
  const isPlayed = status === 'played';
  const isNext = status === 'next';

  return (
    <div onClick={onClick} style={{
      position: 'relative', display: 'flex', gap: 12, padding: 12, marginBottom: 8,
      background: tintBg, borderRadius: 14,
      border: isActive ? `2px solid ${vibe.color}` : `1px solid ${PT2.hairline}`,
      boxShadow: isActive ? `0 8px 24px ${vibe.color}33` : 'none',
      opacity: isPlayed ? 0.55 : 1, cursor: 'pointer', overflow: 'hidden',
    }}>
      {/* left edge: pin "tape" or position number */}
      {pinned && !isPlayed && (
        <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: 3, background: vibe.color }} />
      )}

      {isActive && (
        <div style={{ position: 'absolute', left: 0, right: 0, top: 0, height: 3, background: 'rgba(0,0,0,0.08)' }}>
          <div style={{ width: `${progressPct}%`, height: '100%', background: vibe.color }} />
        </div>
      )}

      <div style={{ width: 22, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
        {dragHandle ? (
          <div style={{ color: PT2.inkMuted, fontFamily: PT2.mono, lineHeight: 1, fontSize: 14 }}>⋮⋮</div>
        ) : isActive ? (
          <div style={{ width: 20, height: 20, borderRadius: 99, background: vibe.color, display: 'inline-flex', alignItems: 'center', justifyContent: 'center' }}>
            {status === 'now' ? <window.MiniBars color="#fff" running size={10} /> : (
              <div style={{ display: 'flex', gap: 2 }}>
                <span style={{ width: 2, height: 8, background: '#fff' }} />
                <span style={{ width: 2, height: 8, background: '#fff' }} />
              </div>
            )}
          </div>
        ) : pinned ? (
          <div style={{ color: vibe.ink }}>{PinIcon(13, vibe.color)}</div>
        ) : (
          <div style={{
            fontFamily: PT2.mono, fontSize: 11, color: isPlayed ? PT2.inkMuted : (isNext ? vibe.ink : PT2.inkFaint),
            fontVariantNumeric: 'tabular-nums', fontWeight: isNext ? 700 : 500,
          }}>•</div>
        )}
      </div>

      <window.VibeCover pod={pod} size={56} />

      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{
          display: 'flex', alignItems: 'center', gap: 8,
          fontFamily: PT2.mono, fontSize: 10, letterSpacing: '0.10em',
          color: isPlayed ? PT2.inkMuted : PT2.ink, textTransform: 'uppercase', fontWeight: 600,
        }}>
          <span>{pod.title}</span>
          {pinned && !isPlayed && (
            <span style={{
              fontSize: 9, padding: '2px 6px', borderRadius: 99,
              background: vibe.color, color: '#fff', letterSpacing: '0.08em',
              display: 'inline-flex', alignItems: 'center', gap: 4,
            }}>{PinIcon(8, '#fff')} PINNED</span>
          )}
          {!pinned && !isPlayed && !isNext && !isActive && (
            <span style={{ fontSize: 9, color: PT2.inkMuted, letterSpacing: '0.08em' }}>LATEST</span>
          )}
          {isNext && (
            <span style={{ fontSize: 9, padding: '2px 6px', borderRadius: 99, background: vibe.color, color: '#fff', letterSpacing: '0.08em' }}>UP NEXT</span>
          )}
          <span style={{ marginLeft: 'auto' }}>
            <window.VibeDot vibe={vibe} size={7} />
          </span>
        </div>
        <div style={{
          fontFamily: PT2.serif, fontSize: 16, fontWeight: 500,
          lineHeight: 1.22, marginTop: 3, color: PT2.ink, letterSpacing: '-0.005em',
          display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden',
        }}>{ep.title}</div>
        <div style={{
          fontFamily: PT2.mono, fontSize: 10, color: PT2.inkMuted, letterSpacing: '0.08em',
          textTransform: 'uppercase', marginTop: 5, fontWeight: 600,
          display: 'flex', alignItems: 'center', gap: 8,
        }}>
          {isPlayed && <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>{window.Icon.check(11, PT2.inkMuted)} EXPIRED FROM VIBE</span>}
          {!isPlayed && <span>{ep.total} MIN</span>}
          {pinned && !isPlayed && <span>· PINNED {pinnedAt}</span>}
        </div>
      </div>

      <div style={{ display: 'flex', alignItems: 'center', flexShrink: 0 }}>
        <window.RowControl status={status} vibe={vibe} />
      </div>
    </div>
  );
}

// Need to expose RowControl from playback file. It's defined there, not exported.
// Re-implement here as a fallback.
if (!window.RowControl) {
  window.RowControl = function ({ status, vibe }) {
    const baseBtn = {
      width: 38, height: 38, borderRadius: 999, border: 'none', cursor: 'pointer',
      display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
    };
    if (status === 'now') return <button style={{ ...baseBtn, background: vibe.color, color: '#fff' }}>{window.Icon.pause(16, '#fff')}</button>;
    if (status === 'paused') return <button style={{ ...baseBtn, background: vibe.color, color: '#fff' }}>{window.Icon.play(14, '#fff')}</button>;
    if (status === 'played') return <button style={{ ...baseBtn, background: 'transparent', color: PT2.inkMuted }}>{window.Icon.resume(15, PT2.inkMuted)}</button>;
    return <button style={{ ...baseBtn, background: PT2.paper, color: PT2.ink, border: `1px solid ${PT2.hairline}` }}>{window.Icon.play(12, PT2.ink)}</button>;
  };
}

// ─── Podcast detail screen (back catalog) ──────────────────────
function PodcastDetailScreen({ podId, pinnedEpIds = [], highlightEpId }) {
  const pod = window.PODCAST_BY_ID[podId];
  const eps = window.BACK_CATALOG[podId] || [];
  const podVibes = pod.vibes.map(v => window.VIBE_BY_ID[v]).filter(Boolean);
  return (
    <div style={{ background: PT2.bg, minHeight: '100%', color: PT2.ink, fontFamily: PT2.sans, paddingBottom: 24 }}>
      {/* Hero */}
      <div style={{ position: 'relative', padding: '60px 22px 18px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <button style={hdrBtn2}>{window.Icon.chevronDown(18, PT2.ink)}</button>
          <button style={hdrBtn2}>{window.Icon.more(17, PT2.ink)}</button>
        </div>
        <div style={{ display: 'flex', gap: 16, alignItems: 'flex-start', marginTop: 14 }}>
          <window.VibeCover pod={pod} size={104} radius={6} />
          <div style={{ flex: 1, minWidth: 0, paddingTop: 4 }}>
            <div style={{ fontFamily: PT2.mono, fontSize: 10, letterSpacing: '0.14em', textTransform: 'uppercase', color: PT2.inkMuted, fontWeight: 600 }}>
              {pod.publisher}
            </div>
            <h2 style={{ fontFamily: PT2.serif, fontSize: 28, fontWeight: 500, letterSpacing: '-0.025em', margin: '4px 0 8px', lineHeight: 1.05 }}>{pod.title}</h2>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
              {podVibes.map(v => <window.VibeChip key={v.id} vibe={v} dense />)}
              {podVibes.length === 0 && (
                <span style={{ fontFamily: PT2.mono, fontSize: 9, color: PT2.inkMuted, letterSpacing: '0.08em' }}>NOT IN A VIBE</span>
              )}
            </div>
          </div>
        </div>

        <div style={{ display: 'flex', gap: 8, marginTop: 16 }}>
          <button style={{
            background: PT2.ink, color: PT2.paper, border: 'none', padding: '10px 16px', borderRadius: 999,
            fontSize: 14, fontWeight: 600, display: 'inline-flex', alignItems: 'center', gap: 8, cursor: 'pointer',
          }}>{window.Icon.play(13, PT2.paper)} Play latest</button>
          <button style={{
            background: PT2.paper, color: PT2.ink, border: `1px solid ${PT2.hairline}`,
            padding: '10px 14px', borderRadius: 999, fontSize: 14, fontWeight: 500, cursor: 'pointer',
            display: 'inline-flex', alignItems: 'center', gap: 6,
          }}>{PinIcon(13, PT2.ink)} Pin to vibe</button>
          <button style={{
            background: PT2.paper, color: PT2.ink, border: `1px solid ${PT2.hairline}`,
            width: 38, height: 38, borderRadius: 999, cursor: 'pointer',
            display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
          }}>{window.Icon.check(15, PT2.ink)}</button>
        </div>
      </div>

      {/* Episodes header */}
      <div style={{ padding: '8px 22px 8px', display: 'flex', alignItems: 'center', gap: 10 }}>
        <div style={{ fontFamily: PT2.mono, fontSize: 10, letterSpacing: '0.18em', textTransform: 'uppercase', color: PT2.inkDim, fontWeight: 600 }}>EPISODES</div>
        <div style={{ flex: 1, height: 1, background: PT2.hairline }} />
        <div style={{ fontFamily: PT2.mono, fontSize: 10, color: PT2.inkMuted, letterSpacing: '0.06em' }}>{eps.length}</div>
      </div>

      {/* Episode list */}
      <div style={{ padding: '0 16px' }}>
        {eps.map((ep, i) => {
          const pinned = pinnedEpIds.includes(ep.id);
          const highlighted = ep.id === highlightEpId;
          return (
            <div key={ep.id} style={{
              padding: 14, borderRadius: 12, marginBottom: 6,
              background: highlighted ? PT2.paper : 'transparent',
              border: highlighted ? `1px solid ${PT2.hairline}` : '1px solid transparent',
              borderBottom: highlighted ? `1px solid ${PT2.hairline}` : `1px solid ${PT2.hairline}`,
              opacity: ep.played ? 0.55 : 1,
              display: 'flex', gap: 12, alignItems: 'flex-start',
            }}>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{
                  display: 'flex', alignItems: 'center', gap: 8,
                  fontFamily: PT2.mono, fontSize: 10, color: PT2.inkMuted, letterSpacing: '0.10em',
                  textTransform: 'uppercase', fontWeight: 600,
                }}>
                  <span>{ep.age}</span>
                  {ep.played && <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3 }}>{window.Icon.check(10, PT2.inkMuted)} PLAYED</span>}
                  {pinned && !ep.played && (
                    <span style={{
                      fontSize: 9, padding: '1px 6px', borderRadius: 99,
                      background: window.PLANE_VIBE.color, color: '#fff', letterSpacing: '0.08em',
                      display: 'inline-flex', alignItems: 'center', gap: 4,
                    }}>{PinIcon(8, '#fff')} ON A PLANE</span>
                  )}
                </div>
                <div style={{
                  fontFamily: PT2.serif, fontSize: 16, fontWeight: 500, lineHeight: 1.22,
                  marginTop: 4, letterSpacing: '-0.005em',
                }}>{ep.title}</div>
                <div style={{
                  fontFamily: PT2.serif, fontStyle: 'italic', fontSize: 13, color: PT2.inkDim,
                  marginTop: 4, lineHeight: 1.45,
                  display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden',
                }}>{ep.blurb}</div>
                <div style={{ fontFamily: PT2.mono, fontSize: 10, color: PT2.inkMuted, letterSpacing: '0.06em', marginTop: 6 }}>
                  {ep.total} MIN
                </div>
              </div>
              <button style={{
                width: 38, height: 38, borderRadius: 999,
                background: PT2.paper, color: PT2.ink, border: `1px solid ${PT2.hairline}`, cursor: 'pointer',
                display: 'inline-flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
              }}>{window.Icon.play(12, PT2.ink)}</button>
              <button style={{
                width: 38, height: 38, borderRadius: 999,
                background: pinned ? window.PLANE_VIBE.color : 'transparent',
                color: pinned ? '#fff' : PT2.ink,
                border: pinned ? 'none' : `1px solid ${PT2.hairline}`, cursor: 'pointer',
                display: 'inline-flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
              }}>{PinIcon(13, pinned ? '#fff' : PT2.ink)}</button>
            </div>
          );
        })}
      </div>
    </div>
  );
}

const hdrBtn2 = {
  width: 36, height: 36, borderRadius: 999, border: `1px solid ${PT2.hairline}`,
  background: PT2.paper, color: PT2.ink, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer',
};

// ─── Pin sheet (action sheet shown when tapping pin) ────────────
function PinSheet({ podId, epId, anchorVibeId = 'plane' }) {
  const pod = window.PODCAST_BY_ID[podId];
  const ep = (window.BACK_CATALOG[podId] || []).find(e => e.id === epId);
  const vibes = window.VIBES;
  return (
    <div style={{ position: 'absolute', inset: 0, background: 'rgba(20,18,15,0.45)', display: 'flex', alignItems: 'flex-end', justifyContent: 'center' }}>
      <div style={{
        width: '100%', maxWidth: 480, background: PT2.bg,
        borderTopLeftRadius: 18, borderTopRightRadius: 18,
        padding: '14px 18px 28px',
        boxShadow: '0 -10px 40px rgba(0,0,0,0.25)',
      }}>
        <div style={{ display: 'flex', justifyContent: 'center', marginBottom: 12 }}>
          <div style={{ width: 36, height: 4, borderRadius: 99, background: PT2.inkFaint }} />
        </div>
        <div style={{ fontFamily: PT2.mono, fontSize: 10, letterSpacing: '0.14em', textTransform: 'uppercase', color: PT2.inkMuted, fontWeight: 600 }}>
          PIN EPISODE TO VIBE
        </div>
        <div style={{ fontFamily: PT2.serif, fontSize: 20, fontWeight: 500, letterSpacing: '-0.02em', marginTop: 4, lineHeight: 1.15 }}>{ep.title}</div>
        <div style={{ fontFamily: PT2.mono, fontSize: 10, color: PT2.inkMuted, letterSpacing: '0.10em', textTransform: 'uppercase', marginTop: 4 }}>{pod.title}</div>

        <div style={{ marginTop: 14 }}>
          {vibes.map(v => {
            const selected = v.id === anchorVibeId;
            return (
              <div key={v.id} style={{
                display: 'flex', alignItems: 'center', gap: 12, padding: '12px 12px',
                borderRadius: 12, marginBottom: 6,
                background: selected ? v.chip : 'transparent',
                border: selected ? `1px solid ${v.color}` : `1px solid ${PT2.hairline}`,
                cursor: 'pointer',
              }}>
                <span style={{ width: 10, height: 10, borderRadius: 99, background: v.color }} />
                <div style={{ flex: 1 }}>
                  <div style={{ fontFamily: PT2.serif, fontSize: 16, fontWeight: 500, color: PT2.ink }}>{v.name}</div>
                  <div style={{ fontFamily: PT2.mono, fontSize: 10, color: PT2.inkMuted, letterSpacing: '0.06em', marginTop: 2 }}>
                    {window.VIBE_ORDER[v.id]?.length || 0} SHOWS
                  </div>
                </div>
                <div style={{
                  width: 22, height: 22, borderRadius: 999,
                  background: selected ? v.color : 'transparent',
                  border: selected ? 'none' : `1.5px solid ${PT2.inkFaint}`,
                  display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
                }}>
                  {selected && window.Icon.check(13, '#fff')}
                </div>
              </div>
            );
          })}
        </div>

        <div style={{
          marginTop: 8, padding: 12, borderRadius: 10,
          background: PT2.paper, border: `1px solid ${PT2.hairline}`,
          fontFamily: PT2.serif, fontStyle: 'italic', fontSize: 13, color: PT2.inkDim, lineHeight: 1.45,
        }}>
          Pinned episodes appear in the vibe alongside your shows. They expire from the queue when played.
        </div>

        <button style={{
          marginTop: 14, width: '100%', padding: '13px 16px', borderRadius: 999,
          background: window.VIBE_BY_ID[anchorVibeId].color, color: '#fff', border: 'none',
          fontFamily: PT2.sans, fontSize: 15, fontWeight: 600, cursor: 'pointer',
          display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 8,
        }}>{PinIcon(14, '#fff')} Pin to {window.VIBE_BY_ID[anchorVibeId].name}</button>
      </div>
    </div>
  );
}

// ─── On-a-plane vibe screen (mixed pinned + show queue) ────────
function OnAPlaneScreen({ currentPos = 0, paused = false, progress = 18, label, reorder = false, postPlay = false }) {
  const vibe = window.PLANE_VIBE;
  // For the post-play state: pretend we played the first three pinned items, so they're gone.
  const queue = postPlay
    ? window.PLANE_QUEUE.filter(it => !(it.kind === 'episode' && (it.epId === 'bc-pirates-1' || it.epId === 'bc-pirates-2' || it.epId === 'bc-pirates-3')))
    : window.PLANE_QUEUE;
  const pinnedCount = queue.filter(i => i.kind === 'episode').length;
  const showCount = queue.filter(i => i.kind === 'show').length;
  const totalMin = queue.reduce((a, it) => a + window.resolveQueueItem(it).ep.total, 0);

  const current = queue[currentPos];
  const currentResolved = current ? window.resolveQueueItem(current) : null;

  return (
    <div style={{ background: PT2.bg, minHeight: '100%', color: PT2.ink, fontFamily: PT2.sans, paddingBottom: 110, position: 'relative' }}>
      <div style={{
        position: 'absolute', top: 0, left: 0, right: 0, height: 240,
        background: `linear-gradient(180deg, ${vibe.chip} 0%, ${PT2.bg} 100%)`,
      }} />
      <div style={{ position: 'relative', padding: '60px 22px 14px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div style={{
            display: 'inline-flex', alignItems: 'center', gap: 8,
            fontFamily: PT2.mono, fontSize: 10, letterSpacing: '0.18em',
            textTransform: 'uppercase', color: vibe.ink, fontWeight: 700,
          }}>
            <span style={{ width: 6, height: 6, borderRadius: 99, background: vibe.color }} />
            {postPlay ? 'AFTER LANDING' : (reorder ? 'REORDER' : 'VIBE')}
          </div>
          <button style={hdrBtn2}>{window.Icon.more(17, PT2.ink)}</button>
        </div>
        <h1 style={{ fontFamily: PT2.serif, fontSize: 40, fontWeight: 500, letterSpacing: '-0.025em', margin: '10px 0 4px', lineHeight: 1.05 }}>
          On a plane
        </h1>
        <div style={{ fontFamily: PT2.serif, fontStyle: 'italic', fontSize: 14, color: PT2.inkDim }}>
          {showCount} shows · {pinnedCount} pinned · {Math.round(totalMin / 60 * 10) / 10}h total
        </div>

        {label && (
          <div style={{
            marginTop: 12, padding: '6px 10px', display: 'inline-flex',
            background: PT2.paper, border: `1px dashed ${PT2.inkFaint}`, borderRadius: 6,
            fontFamily: PT2.mono, fontSize: 9, letterSpacing: '0.12em',
            color: PT2.inkMuted, textTransform: 'uppercase', fontWeight: 600,
          }}>{label}</div>
        )}
      </div>

      <div style={{ position: 'relative', padding: '4px 22px 8px', display: 'flex', alignItems: 'center', gap: 10 }}>
        <div style={{ fontFamily: PT2.mono, fontSize: 10, letterSpacing: '0.18em', textTransform: 'uppercase', color: PT2.inkDim, fontWeight: 600 }}>
          {reorder ? 'DRAG TO REORDER' : 'QUEUE'}
        </div>
        <div style={{ flex: 1, height: 1, background: PT2.hairline }} />
        <div style={{ fontFamily: PT2.mono, fontSize: 10, color: PT2.inkMuted, letterSpacing: '0.06em' }}>
          {reorder ? 'DONE' : 'EDIT'}
        </div>
      </div>

      <div style={{ position: 'relative', padding: '0 16px' }}>
        {queue.map((item, i) => {
          const status = window.rowStatus(i, currentPos, paused);
          return <PinQueueRow key={i} item={item} vibe={vibe} status={status} progressPct={status === 'now' || status === 'paused' ? progress : 0} dragHandle={reorder} />;
        })}

        {postPlay && (
          <div style={{
            marginTop: 4, padding: 14, borderRadius: 12,
            background: PT2.paper, border: `1px dashed ${PT2.inkFaint}`,
            fontFamily: PT2.serif, fontStyle: 'italic', fontSize: 13, color: PT2.inkDim, lineHeight: 1.45,
          }}>
            Three pinned Blank Check episodes expired from this vibe after playback. The vibe is back to its three subscribed shows.
          </div>
        )}
      </div>

      {currentResolved && !reorder && (
        <window.VibeMiniPlayer
          pod={currentResolved.pod} vibe={vibe} pos={currentPos} total={queue.length}
          paused={paused} progressPct={progress}
        />
      )}
    </div>
  );
}

Object.assign(window, { PinQueueRow, PodcastDetailScreen, PinSheet, OnAPlaneScreen, PinIcon });
