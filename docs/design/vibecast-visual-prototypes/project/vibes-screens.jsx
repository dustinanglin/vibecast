// Vibes — full screens (All Vibes, Filtered, Vibe Edit/Detail).
// Each screen takes a `Row` component prop so we can swap row treatments.

const VT = window.VIBE_TOKENS;

function VibeFilterBar({ active, onChange, sticky = true }) {
  return (
    <div style={{
      padding: '12px 18px 10px', display: 'flex', gap: 6, overflow: 'hidden',
      position: sticky ? 'sticky' : 'static', top: 0, zIndex: 5,
      background: `linear-gradient(180deg, ${VT.bg} 80%, ${VT.bg}00 100%)`,
    }}>
      <div style={{ display: 'flex', gap: 6, overflow: 'auto', flex: 1, paddingRight: 4 }}>
        <FilterPill active={active === null} label="All vibes" onClick={() => onChange(null)} />
        {window.VIBES.map(v => (
          <FilterPill key={v.id} vibe={v} active={active === v.id} label={v.name} onClick={() => onChange(v.id)} />
        ))}
      </div>
    </div>
  );
}

function FilterPill({ vibe, label, active, onClick }) {
  return (
    <button onClick={onClick} style={{
      flexShrink: 0, height: 32, padding: '0 12px',
      borderRadius: 999, border: 'none', cursor: 'pointer',
      background: active ? (vibe ? vibe.color : VT.ink) : VT.paper,
      color: active ? '#fff' : VT.ink,
      boxShadow: active ? 'none' : `inset 0 0 0 1px ${VT.hairline}`,
      fontFamily: VT.sans, fontSize: 13, fontWeight: 600,
      display: 'inline-flex', alignItems: 'center', gap: 7,
    }}>
      {vibe && <span style={{ width: 8, height: 8, borderRadius: 99, background: active ? '#fff' : vibe.color }} />}
      {label}
    </button>
  );
}

// ─── All Vibes view (default) ─────────────────────────────
function AllVibesScreen({ Row, label }) {
  const [active, setActive] = React.useState(null);
  const podcasts = active
    ? window.VIBE_ORDER[active].map(id => window.PODCAST_BY_ID[id])
    : window.ALL_ORDER.map(id => window.PODCAST_BY_ID[id]);
  const activeVibe = active ? window.VIBE_BY_ID[active] : null;
  return (
    <div style={{ background: VT.bg, minHeight: '100%', color: VT.ink, fontFamily: VT.sans, paddingBottom: 100 }}>
      {/* Masthead */}
      <div style={{ padding: '60px 22px 14px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div style={{ fontFamily: VT.mono, fontSize: 10, letterSpacing: '0.18em', textTransform: 'uppercase', color: VT.inkMuted, fontWeight: 600 }}>
            VOL. 12 &middot; APR 24
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <button style={iconBtn}>{window.Icon.search(17, VT.ink)}</button>
            <button style={iconBtn}>{window.Icon.plus(17, VT.ink)}</button>
          </div>
        </div>
        <h1 style={{
          fontFamily: VT.serif, fontSize: 50, fontWeight: 500,
          letterSpacing: '-0.025em', margin: '10px 0 4px', lineHeight: 1,
        }}>Vibecast</h1>
        <div style={{ fontFamily: VT.serif, fontStyle: 'italic', fontSize: 14, color: VT.inkDim }}>
          {activeVibe ? `Listening for ${activeVibe.name.toLowerCase()}` : 'Your shows, in your order'}
        </div>
        {label && (
          <div style={{ marginTop: 10, padding: '6px 10px', display: 'inline-flex',
            background: VT.paper, border: `1px dashed ${VT.inkFaint}`, borderRadius: 6,
            fontFamily: VT.mono, fontSize: 9, letterSpacing: '0.12em', color: VT.inkMuted, textTransform: 'uppercase', fontWeight: 600,
          }}>{label}</div>
        )}
      </div>
      <VibeFilterBar active={active} onChange={setActive} />
      {/* Section label */}
      <div style={{ padding: '4px 22px 8px', display: 'flex', alignItems: 'center', gap: 10 }}>
        <div style={{ fontFamily: VT.mono, fontSize: 10, letterSpacing: '0.18em', textTransform: 'uppercase', color: VT.inkDim, fontWeight: 600 }}>
          {activeVibe ? `${podcasts.length} shows · in order` : `${podcasts.length} shows · most recent`}
        </div>
        <div style={{ flex: 1, height: 1, background: VT.hairline }} />
        <div style={{ fontFamily: VT.mono, fontSize: 10, letterSpacing: '0.06em', color: VT.inkMuted }}>EDIT ORDER</div>
      </div>
      <div style={{ padding: Row === window.PodcastRowTint ? '0 16px' : '0' }}>
        {podcasts.map((pod, i) => (
          <Row key={pod.id} pod={pod} idx={i + 1} activeVibe={activeVibe} />
        ))}
      </div>
      <MiniPlayerB />
    </div>
  );
}

const iconBtn = {
  width: 36, height: 36, borderRadius: 999, border: `1px solid ${VT.hairline}`,
  background: VT.paper, color: VT.ink, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer',
};

function MiniPlayerB() {
  const pod = window.PODCAST_BY_ID['vergecast'];
  const ep = pod.latest;
  return (
    <div style={{
      position: 'absolute', left: 12, right: 12, bottom: 38,
      background: VT.ink, color: VT.paper, borderRadius: 14, padding: 10,
      display: 'flex', gap: 10, alignItems: 'center',
      boxShadow: '0 10px 30px rgba(0,0,0,0.18)',
      overflow: 'hidden',
    }}>
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, height: 2, background: 'rgba(255,255,255,0.08)' }}>
        <div style={{ width: '15%', height: '100%', background: VT.paper }} />
      </div>
      <window.VibeCover pod={pod} size={40} radius={4} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontFamily: VT.serif, fontSize: 14, fontWeight: 500, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', letterSpacing: '-0.01em' }}>{ep.title}</div>
        <div style={{ fontFamily: VT.mono, fontSize: 10, color: 'rgba(251,247,238,0.6)', letterSpacing: '0.08em', textTransform: 'uppercase', marginTop: 1 }}>
          {pod.title} · {ep.total - ep.mins}M
        </div>
      </div>
      <button style={{ width: 32, height: 32, border: 'none', background: 'transparent', color: VT.paper }}>{window.Icon.pause(18, VT.paper)}</button>
    </div>
  );
}

// ─── Filtered (Vibe-active) ────────────────────────────────
function VibeFilteredScreen({ vibeId, Row }) {
  const vibe = window.VIBE_BY_ID[vibeId];
  const podcasts = window.VIBE_ORDER[vibeId].map(id => window.PODCAST_BY_ID[id]);
  return (
    <div style={{ background: VT.bg, minHeight: '100%', color: VT.ink, fontFamily: VT.sans, paddingBottom: 100, position: 'relative' }}>
      {/* Tinted header band */}
      <div style={{
        position: 'absolute', top: 0, left: 0, right: 0, height: 220,
        background: `linear-gradient(180deg, ${vibe.chip} 0%, ${VT.bg} 100%)`,
        zIndex: 0,
      }} />
      <div style={{ position: 'relative', padding: '60px 22px 14px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div style={{ fontFamily: VT.mono, fontSize: 10, letterSpacing: '0.18em', textTransform: 'uppercase', color: vibe.ink, fontWeight: 700, display: 'inline-flex', alignItems: 'center', gap: 8 }}>
            <span style={{ width: 8, height: 8, borderRadius: 99, background: vibe.color }} />
            VIBE
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <button style={iconBtn}>{window.Icon.search(17, VT.ink)}</button>
            <button style={iconBtn}>{window.Icon.more(17, VT.ink)}</button>
          </div>
        </div>
        <h1 style={{
          fontFamily: VT.serif, fontSize: 44, fontWeight: 500,
          letterSpacing: '-0.025em', margin: '12px 0 4px', lineHeight: 1.05,
          color: VT.ink,
        }}>{vibe.name}</h1>
        <div style={{ fontFamily: VT.serif, fontStyle: 'italic', fontSize: 14, color: VT.inkDim }}>
          {podcasts.length} shows, in order. About {Math.round(podcasts.reduce((a, p) => a + p.latest.total, 0) / 60 * 10) / 10}h queued.
        </div>
        <div style={{ display: 'flex', gap: 10, marginTop: 14 }}>
          <button style={{
            background: vibe.color, color: '#fff', border: 'none',
            padding: '10px 16px', borderRadius: 999, fontSize: 14, fontWeight: 600,
            display: 'inline-flex', alignItems: 'center', gap: 8, fontFamily: VT.sans,
          }}>{window.Icon.play(13, '#fff')} Start the vibe</button>
          <button style={{
            background: VT.paper, color: VT.ink, border: `1px solid ${VT.hairline}`,
            padding: '10px 14px', borderRadius: 999, fontSize: 14, fontWeight: 500, fontFamily: VT.sans,
          }}>Edit order</button>
        </div>
      </div>
      <div style={{ position: 'relative' }}>
        <VibeFilterBar active={vibeId} onChange={() => {}} />
      </div>
      <div style={{ position: 'relative', padding: Row === window.PodcastRowTint ? '0 16px' : '0' }}>
        {podcasts.map((pod, i) => (
          <Row key={pod.id} pod={pod} idx={i + 1} activeVibe={vibe} />
        ))}
      </div>
      <MiniPlayerB />
    </div>
  );
}

// ─── Vibe edit (manual ordering) ───────────────────────────
function VibeEditScreen({ vibeId }) {
  const vibe = window.VIBE_BY_ID[vibeId];
  const podcasts = window.VIBE_ORDER[vibeId].map(id => window.PODCAST_BY_ID[id]);
  return (
    <div style={{ background: VT.bg, minHeight: '100%', color: VT.ink, fontFamily: VT.sans, paddingBottom: 24 }}>
      <div style={{ padding: '60px 22px 14px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', borderBottom: `1px solid ${VT.hairline}` }}>
        <button style={{ ...iconBtn, paddingLeft: 12, paddingRight: 14, width: 'auto' }}>
          <span style={{ fontSize: 13, fontWeight: 600, marginLeft: 4 }}>Done</span>
        </button>
        <div style={{ fontFamily: VT.serif, fontSize: 16, fontWeight: 500, display: 'inline-flex', alignItems: 'center', gap: 8 }}>
          <span style={{ width: 10, height: 10, borderRadius: 99, background: vibe.color }} />
          {vibe.name}
        </div>
        <button style={iconBtn}>{window.Icon.plus(17, VT.ink)}</button>
      </div>

      {/* Color picker */}
      <div style={{ padding: '18px 22px 8px' }}>
        <div style={{ fontFamily: VT.mono, fontSize: 10, letterSpacing: '0.18em', textTransform: 'uppercase', color: VT.inkMuted, fontWeight: 600, marginBottom: 10 }}>VIBE COLOR</div>
        <div style={{ display: 'flex', gap: 10 }}>
          {window.VIBES.map(v => (
            <div key={v.id} style={{
              width: 36, height: 36, borderRadius: 999, background: v.color,
              border: v.id === vibe.id ? `2px solid ${VT.ink}` : '2px solid transparent',
              boxShadow: v.id === vibe.id ? `0 0 0 2px ${VT.bg}` : 'none',
              cursor: 'pointer',
            }} />
          ))}
        </div>
      </div>

      {/* Reorderable list */}
      <div style={{ padding: '14px 22px 8px' }}>
        <div style={{ fontFamily: VT.mono, fontSize: 10, letterSpacing: '0.18em', textTransform: 'uppercase', color: VT.inkMuted, fontWeight: 600, marginBottom: 6 }}>
          ORDER &middot; {podcasts.length} SHOWS
        </div>
        <div style={{ fontFamily: VT.serif, fontStyle: 'italic', fontSize: 13, color: VT.inkDim, marginBottom: 4 }}>
          Drag to set the order you'll listen in.
        </div>
      </div>
      {podcasts.map((pod, i) => (
        <div key={pod.id} style={{
          display: 'flex', alignItems: 'center', gap: 12, padding: '12px 22px',
          borderTop: `1px solid ${VT.hairline}`,
          background: i === 0 ? VT.paper : 'transparent',
        }}>
          <div style={{ width: 18, color: VT.inkFaint, display: 'flex', flexDirection: 'column', gap: 2 }}>
            <span style={{ height: 2, background: 'currentColor', borderRadius: 99 }} />
            <span style={{ height: 2, background: 'currentColor', borderRadius: 99 }} />
            <span style={{ height: 2, background: 'currentColor', borderRadius: 99 }} />
          </div>
          <span style={{ fontFamily: VT.mono, fontSize: 11, color: VT.inkMuted, fontVariantNumeric: 'tabular-nums', width: 18 }}>{String(i + 1).padStart(2, '0')}</span>
          <window.VibeCover pod={pod} size={44} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontFamily: VT.serif, fontSize: 15, fontWeight: 500, letterSpacing: '-0.005em' }}>{pod.title}</div>
            <div style={{ fontFamily: VT.mono, fontSize: 10, color: VT.inkMuted, letterSpacing: '0.08em', textTransform: 'uppercase', marginTop: 2 }}>
              {pod.publisher}
            </div>
          </div>
          <button style={{ background: 'transparent', border: 'none', color: VT.inkMuted, fontSize: 18, fontWeight: 300, padding: 4 }}>−</button>
        </div>
      ))}

      <div style={{ padding: '20px 22px' }}>
        <button style={{
          width: '100%', padding: '12px 16px', borderRadius: 12,
          background: VT.paper, border: `1px dashed ${VT.inkFaint}`, color: VT.ink,
          fontFamily: VT.sans, fontSize: 14, fontWeight: 500,
          display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 8,
        }}>{window.Icon.plus(14, VT.ink)} Add a podcast to this vibe</button>
      </div>
    </div>
  );
}

// ─── Vibe picker (entry point — shown e.g. as a sheet) ──────
function VibePickerScreen() {
  return (
    <div style={{ background: VT.bg, minHeight: '100%', color: VT.ink, fontFamily: VT.sans, paddingBottom: 24 }}>
      <div style={{ paddingTop: 56, display: 'flex', justifyContent: 'center' }}>
        <div style={{ width: 36, height: 4, borderRadius: 99, background: 'rgba(26,23,20,0.20)' }} />
      </div>
      <div style={{ padding: '20px 22px 12px' }}>
        <div style={{ fontFamily: VT.mono, fontSize: 10, letterSpacing: '0.18em', textTransform: 'uppercase', color: VT.inkMuted, fontWeight: 600 }}>VIBES</div>
        <h2 style={{ fontFamily: VT.serif, fontSize: 32, fontWeight: 500, letterSpacing: '-0.025em', margin: '8px 0 4px', lineHeight: 1.05 }}>
          What's the vibe?
        </h2>
        <div style={{ fontFamily: VT.serif, fontStyle: 'italic', fontSize: 14, color: VT.inkDim }}>
          Pick a mood and we'll line up your shows in order.
        </div>
      </div>
      <div style={{ padding: '8px 22px 16px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
        {window.VIBES.map(v => {
          const podcasts = window.VIBE_ORDER[v.id].map(id => window.PODCAST_BY_ID[id]);
          const totalMin = podcasts.reduce((a, p) => a + p.latest.total, 0);
          return (
            <div key={v.id} style={{
              background: v.chip, borderRadius: 16, padding: 14,
              border: `1px solid ${VT.hairline}`,
              minHeight: 130, display: 'flex', flexDirection: 'column',
            }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                <div style={{ width: 28, height: 28, borderRadius: 999, background: v.color, color: '#fff', display: 'inline-flex', alignItems: 'center', justifyContent: 'center', fontSize: 14 }}>{v.icon}</div>
                <div style={{ fontFamily: VT.mono, fontSize: 9, color: v.ink, letterSpacing: '0.08em', textTransform: 'uppercase', fontWeight: 700 }}>
                  {podcasts.length} · {Math.round(totalMin / 60 * 10) / 10}H
                </div>
              </div>
              <div style={{ flex: 1 }} />
              <div style={{ fontFamily: VT.serif, fontSize: 19, fontWeight: 500, letterSpacing: '-0.01em', color: v.ink }}>
                {v.name}
              </div>
              <div style={{ marginTop: 6, display: 'flex', gap: -6 }}>
                {podcasts.slice(0, 3).map((p, i) => (
                  <div key={p.id} style={{ marginLeft: i === 0 ? 0 : -8, borderRadius: 4, border: `2px solid ${v.chip}` }}>
                    <window.VibeCover pod={p} size={26} radius={3} />
                  </div>
                ))}
                {podcasts.length > 3 && (
                  <div style={{ marginLeft: -8, width: 26, height: 26, borderRadius: 4, background: 'rgba(0,0,0,0.06)', border: `2px solid ${v.chip}`, fontFamily: VT.mono, fontSize: 9, color: v.ink, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700 }}>+{podcasts.length - 3}</div>
                )}
              </div>
            </div>
          );
        })}
        <div style={{
          background: VT.paper, border: `1px dashed ${VT.inkFaint}`, borderRadius: 16, padding: 14,
          display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 6,
          minHeight: 130, color: VT.inkDim,
        }}>
          {window.Icon.plus(20, VT.inkDim)}
          <div style={{ fontFamily: VT.sans, fontSize: 13, fontWeight: 500 }}>New vibe</div>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, {
  AllVibesScreen, VibeFilteredScreen, VibeEditScreen, VibePickerScreen,
});
