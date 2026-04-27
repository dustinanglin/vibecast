// Row variants — different ways to render the "this podcast belongs to these vibes" affordance.
// Each variant is a complete <PodcastRow*> component you can swap in.

const T = window.VIBE_TOKENS;

// Shared: episode metadata block on the right (most-recent episode summary).
function EpisodeMeta({ pod, align = 'right' }) {
  const ep = pod.latest;
  const inProgress = ep.mins > 0;
  return (
    <div style={{ width: 76, textAlign: align, flexShrink: 0 }}>
      <div style={{
        fontFamily: T.mono, fontSize: 9, letterSpacing: '0.08em',
        color: T.inkMuted, textTransform: 'uppercase', fontWeight: 600,
      }}>{ep.age}</div>
      <div style={{ fontFamily: T.mono, fontSize: 11, color: T.ink, marginTop: 3, fontVariantNumeric: 'tabular-nums', letterSpacing: '0.02em' }}>
        {ep.total}m
      </div>
      {inProgress && (
        <div style={{ marginTop: 6, height: 2, background: T.hairline, borderRadius: 99 }}>
          <div style={{ width: `${(ep.mins / ep.total) * 100}%`, height: '100%', background: T.ink, borderRadius: 99 }} />
        </div>
      )}
    </div>
  );
}

// Shared: title block (show name, episode title, blurb)
function TitleBlock({ pod, idx }) {
  const ep = pod.latest;
  return (
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{
        display: 'flex', alignItems: 'center', gap: 8,
        fontFamily: T.mono, fontSize: 10, letterSpacing: '0.10em',
        color: T.inkMuted, textTransform: 'uppercase', fontWeight: 600,
      }}>
        {idx != null && <span style={{ color: T.inkFaint }}>{String(idx).padStart(2, '0')}</span>}
        <span style={{ color: T.ink }}>{pod.title}</span>
      </div>
      <div style={{
        fontFamily: T.serif, fontSize: 16, fontWeight: 500,
        lineHeight: 1.22, marginTop: 3, letterSpacing: '-0.005em',
        color: T.ink, overflow: 'hidden',
        display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical',
      }}>{ep.title}</div>
    </div>
  );
}

// ─── Variant 1: Left color stripe ────────────────────────────
// A vertical bar on the left of each row. If multi-vibe, stripe is split.
function PodcastRowStripe({ pod, idx, activeVibe }) {
  const vibes = pod.vibes.map(v => window.VIBE_BY_ID[v]);
  return (
    <div style={{
      display: 'flex', gap: 12, padding: '14px 18px 14px 14px',
      borderTop: `1px solid ${T.hairline}`, position: 'relative',
      background: activeVibe ? `linear-gradient(90deg, ${activeVibe.chip}99 0%, transparent 70%)` : 'transparent',
    }}>
      {/* split stripe */}
      <div style={{ display: 'flex', flexDirection: 'column', width: 4, borderRadius: 99, overflow: 'hidden', flexShrink: 0 }}>
        {vibes.map((v, i) => (
          <div key={v.id} style={{ flex: 1, background: v.color }} />
        ))}
      </div>
      <window.VibeCover pod={pod} size={48} />
      <TitleBlock pod={pod} idx={idx} />
      <EpisodeMeta pod={pod} />
    </div>
  );
}

// ─── Variant 2: Vibe chip row under title ───────────────────
function PodcastRowChips({ pod, idx, activeVibe }) {
  const vibes = pod.vibes.map(v => window.VIBE_BY_ID[v]);
  return (
    <div style={{
      display: 'flex', gap: 12, padding: '14px 18px',
      borderTop: `1px solid ${T.hairline}`,
    }}>
      <window.VibeCover pod={pod} size={56} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <TitleBlock pod={pod} idx={idx} />
        <div style={{ display: 'flex', gap: 5, marginTop: 8, flexWrap: 'wrap' }}>
          {vibes.map(v => (
            <window.VibeChip key={v.id} vibe={v} dense active={activeVibe && activeVibe.id === v.id} />
          ))}
        </div>
      </div>
      <EpisodeMeta pod={pod} />
    </div>
  );
}

// ─── Variant 3: Color dots inline with metadata ────────────
function PodcastRowDots({ pod, idx, activeVibe }) {
  const vibes = pod.vibes.map(v => window.VIBE_BY_ID[v]);
  return (
    <div style={{
      display: 'flex', gap: 12, padding: '14px 18px',
      borderTop: `1px solid ${T.hairline}`,
    }}>
      <window.VibeCover pod={pod} size={56} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{
          display: 'flex', alignItems: 'center', gap: 8,
          fontFamily: T.mono, fontSize: 10, letterSpacing: '0.10em',
          color: T.inkMuted, textTransform: 'uppercase', fontWeight: 600,
        }}>
          {idx != null && <span style={{ color: T.inkFaint }}>{String(idx).padStart(2, '0')}</span>}
          <span style={{ color: T.ink }}>{pod.title}</span>
          <span style={{ display: 'inline-flex', gap: 3, marginLeft: 'auto', paddingRight: 0 }}>
            {vibes.map(v => <window.VibeDot key={v.id} vibe={v} size={7} />)}
          </span>
        </div>
        <div style={{
          fontFamily: T.serif, fontSize: 16, fontWeight: 500,
          lineHeight: 1.22, marginTop: 3, letterSpacing: '-0.005em',
          color: T.ink, overflow: 'hidden',
          display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical',
        }}>{pod.latest.title}</div>
        <div style={{ fontFamily: T.mono, fontSize: 9, color: T.inkMuted, letterSpacing: '0.08em', marginTop: 6, textTransform: 'uppercase' }}>
          {vibes.map(v => v.name).join('  ·  ')}
        </div>
      </div>
      <EpisodeMeta pod={pod} />
    </div>
  );
}

// ─── Variant 4: Vibe-tinted card ─────────────────────────────
// Strongest visual: each row is a soft-tinted card matching its primary vibe.
// Multi-vibe shows get a gradient between the two.
function PodcastRowTint({ pod, idx, activeVibe }) {
  const vibes = pod.vibes.map(v => window.VIBE_BY_ID[v]);
  const bg = vibes.length > 1
    ? `linear-gradient(105deg, ${vibes[0].chip} 0%, ${vibes[1].chip} 100%)`
    : vibes[0].chip;
  return (
    <div style={{
      display: 'flex', gap: 12, padding: 12, marginBottom: 8,
      background: bg, borderRadius: 12,
      border: `1px solid ${T.hairline}`,
    }}>
      <window.VibeCover pod={pod} size={56} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontFamily: T.mono, fontSize: 10, letterSpacing: '0.10em', textTransform: 'uppercase', fontWeight: 600 }}>
          {idx != null && <span style={{ color: T.inkFaint }}>{String(idx).padStart(2, '0')}</span>}
          <span style={{ color: T.ink }}>{pod.title}</span>
          <span style={{ marginLeft: 'auto', display: 'inline-flex', gap: 4 }}>
            {vibes.map(v => <window.VibeDot key={v.id} vibe={v} size={8} />)}
          </span>
        </div>
        <div style={{
          fontFamily: T.serif, fontSize: 16, fontWeight: 500,
          lineHeight: 1.22, marginTop: 3, color: T.ink, letterSpacing: '-0.005em',
          display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden',
        }}>{pod.latest.title}</div>
      </div>
      <EpisodeMeta pod={pod} />
    </div>
  );
}

Object.assign(window, {
  PodcastRowStripe, PodcastRowChips, PodcastRowDots, PodcastRowTint,
});
