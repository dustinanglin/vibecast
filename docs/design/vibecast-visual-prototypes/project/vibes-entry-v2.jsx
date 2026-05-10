// Vibes — entry v2: keeping pills + grid icon, swipe header to switch vibes,
// "Your vibes" reorder/manage, add-show-to-vibe (from vibe screen + podcast detail).

const VT2 = window.VIBE_TOKENS;

const iconBtn2 = {
  width: 36, height: 36, borderRadius: 999, border: `1px solid ${VT2.hairline}`,
  background: VT2.paper, color: VT2.ink,
  display: 'inline-flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer',
};

function StackIcon2({ size = 17, color = VT2.ink }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 8l8-4 8 4-8 4-8-4z" />
      <path d="M4 13l8 4 8-4" />
      <path d="M4 17l8 4 8-4" />
    </svg>
  );
}

function PencilIcon({ size = 14, color = VT2.inkDim }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <path d="M14 4l6 6-11 11H3v-6L14 4z" />
      <path d="M13 5l6 6" />
    </svg>
  );
}

function ChevronLeft({ size = 17, color = VT2.ink }) {
  return <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M15 6l-6 6 6 6"/></svg>;
}
function DragIcon({ color = VT2.inkFaint }) {
  return (
    <svg width={18} height={18} viewBox="0 0 24 24" fill={color}>
      <circle cx="9" cy="6" r="1.5" /><circle cx="15" cy="6" r="1.5" />
      <circle cx="9" cy="12" r="1.5" /><circle cx="15" cy="12" r="1.5" />
      <circle cx="9" cy="18" r="1.5" /><circle cx="15" cy="18" r="1.5" />
    </svg>
  );
}

// ────────────────────────────────────────────────────────────
// HOME — final entry pattern: grid icon + pills + swipeable header
// ────────────────────────────────────────────────────────────
function HomeFinal({ activeId = null, label }) {
  const active = activeId ? window.VIBE_BY_ID[activeId] : null;
  const podcasts = activeId
    ? window.VIBE_ORDER[activeId].map(id => window.PODCAST_BY_ID[id])
    : window.ALL_ORDER.slice(0, 5).map(id => window.PODCAST_BY_ID[id]);
  return (
    <div style={{ background: VT2.bg, minHeight: '100%', color: VT2.ink, fontFamily: VT2.sans, paddingBottom: 100, position: 'relative' }}>
      {active && (
        <div style={{
          position: 'absolute', top: 0, left: 0, right: 0, height: 240,
          background: `linear-gradient(180deg, ${active.chip} 0%, ${VT2.bg} 100%)`,
        }} />
      )}
      <div style={{ position: 'relative', padding: '60px 22px 14px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div style={{ fontFamily: VT2.mono, fontSize: 10, letterSpacing: '0.18em', textTransform: 'uppercase', color: active ? active.ink : VT2.inkMuted, fontWeight: 700, display: 'inline-flex', alignItems: 'center', gap: 8 }}>
            {active && <span style={{ width: 8, height: 8, borderRadius: 99, background: active.color }} />}
            {active ? 'VIBE · APR 24' : 'VOL. 12 · APR 24'}
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <button style={iconBtn2}>{window.Icon.search(17, VT2.ink)}</button>
            <button style={{ ...iconBtn2, background: VT2.ink, color: VT2.paper, borderColor: VT2.ink }}><StackIcon2 color={VT2.paper} /></button>
          </div>
        </div>

        {/* Swipeable title */}
        <div style={{ position: 'relative', marginTop: 10 }}>
          <h1 style={{
            fontFamily: VT2.serif, fontSize: 50, fontWeight: 500,
            letterSpacing: '-0.025em', margin: 0, lineHeight: 1,
            color: active ? active.ink : VT2.ink,
          }}>{active ? active.name : 'Vibecast'}</h1>
          <div style={{ fontFamily: VT2.serif, fontStyle: 'italic', fontSize: 14, color: VT2.inkDim, marginTop: 4 }}>
            {active
              ? `${podcasts.length} shows, in order. About ${Math.round(podcasts.reduce((a, p) => a + p.latest.total, 0) / 60 * 10) / 10}h queued.`
              : 'Your shows, in your order'}
          </div>

          {/* Swipe-dot indicator under title — shows where you are in the carousel */}
          <SwipeDots activeId={activeId} />
        </div>

        {active && (
          <div style={{ display: 'flex', gap: 10, marginTop: 14 }}>
            <button style={{ background: active.color, color: '#fff', border: 'none', padding: '10px 16px', borderRadius: 999, fontSize: 14, fontWeight: 600, display: 'inline-flex', alignItems: 'center', gap: 8, fontFamily: VT2.sans }}>
              {window.Icon.play(13, '#fff')} Start the vibe
            </button>
          </div>
        )}
      </div>

      <FilterBar2 activeId={activeId} />
      <SectionLabel2 active={active} podcasts={podcasts} />
      <Rows2 podcasts={podcasts} />

      {label && <PageLabel>{label}</PageLabel>}
    </div>
  );
}

function PageLabel({ children }) {
  return (
    <div style={{
      position: 'absolute', left: 22, top: 50, padding: '4px 8px',
      background: VT2.ink, color: VT2.paper,
      fontFamily: VT2.mono, fontSize: 9, letterSpacing: '0.14em', textTransform: 'uppercase', fontWeight: 700,
      borderRadius: 4, zIndex: 10,
    }}>{children}</div>
  );
}

function SwipeDots({ activeId }) {
  // Dots: All + each vibe — current one is filled with vibe color (or ink for All)
  const items = [{ id: null, color: VT2.ink }, ...window.VIBES.map(v => ({ id: v.id, color: v.color }))];
  return (
    <div style={{ display: 'flex', gap: 5, marginTop: 10, alignItems: 'center' }}>
      {items.map((it, i) => {
        const on = it.id === activeId;
        return (
          <span key={i} style={{
            width: on ? 16 : 5, height: 5, borderRadius: 99,
            background: on ? it.color : VT2.inkFaint,
            transition: 'all .2s',
          }} />
        );
      })}
      <span style={{ fontFamily: VT2.mono, fontSize: 9, color: VT2.inkMuted, letterSpacing: '0.12em', fontWeight: 600, textTransform: 'uppercase', marginLeft: 6 }}>
        Swipe →
      </span>
    </div>
  );
}

// ────────────────────────────────────────────────────────────
// SWIPING — a frozen mid-gesture state showing two titles bleeding past each other
// ────────────────────────────────────────────────────────────
function HomeSwiping() {
  const fromVibe = window.VIBE_BY_ID['around'];
  const toVibe   = window.VIBE_BY_ID['workout'];
  const offset = 110; // px, how far through the swipe we are (~1/3)
  const podcasts = window.VIBE_ORDER['around'].map(id => window.PODCAST_BY_ID[id]);

  return (
    <div style={{ background: VT2.bg, minHeight: '100%', color: VT2.ink, fontFamily: VT2.sans, paddingBottom: 100, position: 'relative', overflow: 'hidden' }}>
      {/* Two color bands cross-fading */}
      <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 240,
        background: `linear-gradient(180deg, ${fromVibe.chip} 0%, ${VT2.bg} 100%)`, opacity: 0.55 }} />
      <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 240,
        background: `linear-gradient(180deg, ${toVibe.chip} 0%, ${VT2.bg} 100%)`, opacity: 0.45 }} />

      <div style={{ position: 'relative', padding: '60px 22px 14px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div style={{ fontFamily: VT2.mono, fontSize: 10, letterSpacing: '0.18em', textTransform: 'uppercase', color: VT2.inkDim, fontWeight: 700 }}>
            VIBE · APR 24
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <button style={iconBtn2}>{window.Icon.search(17, VT2.ink)}</button>
            <button style={{ ...iconBtn2, background: VT2.ink, color: VT2.paper, borderColor: VT2.ink }}><StackIcon2 color={VT2.paper} /></button>
          </div>
        </div>

        {/* Two titles sliding past each other */}
        <div style={{ position: 'relative', marginTop: 10, height: 56, overflow: 'visible' }}>
          <h1 style={{
            fontFamily: VT2.serif, fontSize: 50, fontWeight: 500, letterSpacing: '-0.025em',
            margin: 0, lineHeight: 1, color: fromVibe.ink,
            position: 'absolute', left: 0, top: 0, transform: `translateX(${-offset}px)`, opacity: 0.55, whiteSpace: 'nowrap',
          }}>{fromVibe.name}</h1>
          <h1 style={{
            fontFamily: VT2.serif, fontSize: 50, fontWeight: 500, letterSpacing: '-0.025em',
            margin: 0, lineHeight: 1, color: toVibe.ink,
            position: 'absolute', left: 0, top: 0, transform: `translateX(${260 - offset}px)`, opacity: 0.85, whiteSpace: 'nowrap',
          }}>{toVibe.name}</h1>
        </div>

        <div style={{ fontFamily: VT2.serif, fontStyle: 'italic', fontSize: 14, color: VT2.inkDim, marginTop: 8 }}>
          Releasing now switches to <strong style={{ color: toVibe.ink, fontWeight: 600 }}>{toVibe.name}</strong>
        </div>

        {/* Dots — between two positions, with subtle motion */}
        <div style={{ display: 'flex', gap: 5, marginTop: 10, alignItems: 'center' }}>
          <span style={{ width: 5, height: 5, borderRadius: 99, background: VT2.inkFaint }} />
          <span style={{ width: 5, height: 5, borderRadius: 99, background: VT2.inkFaint }} />
          <span style={{ width: 11, height: 5, borderRadius: 99, background: fromVibe.color, opacity: 0.7 }} />
          <span style={{ width: 9, height: 5, borderRadius: 99, background: toVibe.color, opacity: 0.9 }} />
          <span style={{ width: 5, height: 5, borderRadius: 99, background: VT2.inkFaint }} />
          <span style={{ width: 5, height: 5, borderRadius: 99, background: VT2.inkFaint }} />
        </div>
      </div>

      <FilterBar2 activeId="around" pendingId="workout" />
      <SectionLabel2 active={fromVibe} podcasts={podcasts} />
      <Rows2 podcasts={podcasts} />

      <PageLabel>SWIPING · AROUND → WORKOUT</PageLabel>
    </div>
  );
}

function FilterBar2({ activeId, pendingId }) {
  return (
    <div style={{
      padding: '12px 18px 10px', display: 'flex', gap: 6,
      background: `linear-gradient(180deg, ${VT2.bg} 80%, ${VT2.bg}00 100%)`,
      position: 'relative',
    }}>
      <div style={{ display: 'flex', gap: 6, overflow: 'hidden', flex: 1 }}>
        <Pill2 label="All vibes" active={activeId === null} />
        {window.VIBES.slice(0, 4).map(v => (
          <Pill2 key={v.id} vibe={v} label={v.name} active={activeId === v.id} pending={pendingId === v.id} />
        ))}
      </div>
    </div>
  );
}

function Pill2({ vibe, label, active, pending }) {
  return (
    <button style={{
      flexShrink: 0, height: 32, padding: '0 12px',
      borderRadius: 999, border: 'none', cursor: 'pointer',
      background: active ? (vibe ? vibe.color : VT2.ink) : VT2.paper,
      color: active ? '#fff' : VT2.ink,
      boxShadow: pending
        ? `inset 0 0 0 1.5px ${vibe?.color || VT2.ink}, 0 0 0 4px ${vibe?.chip || VT2.hairline}`
        : `inset 0 0 0 1px ${VT2.hairline}`,
      fontFamily: VT2.sans, fontSize: 13, fontWeight: 600,
      display: 'inline-flex', alignItems: 'center', gap: 7,
    }}>
      {vibe && <span style={{ width: 8, height: 8, borderRadius: 99, background: active ? '#fff' : vibe.color }} />}
      {label}
    </button>
  );
}

function SectionLabel2({ active, podcasts }) {
  return (
    <div style={{ padding: '4px 22px 8px', display: 'flex', alignItems: 'center', gap: 10, position: 'relative' }}>
      <div style={{ fontFamily: VT2.mono, fontSize: 10, letterSpacing: '0.18em', textTransform: 'uppercase', color: VT2.inkDim, fontWeight: 600 }}>
        {active ? `${podcasts.length} SHOWS · IN ORDER` : `${podcasts.length} SHOWS · MOST RECENT`}
      </div>
      <div style={{ flex: 1, height: 1, background: VT2.hairline }} />
      <div style={{ fontFamily: VT2.mono, fontSize: 10, letterSpacing: '0.06em', color: VT2.inkMuted }}>EDIT ORDER</div>
    </div>
  );
}

function Rows2({ podcasts }) {
  return (
    <div style={{ position: 'relative' }}>
      {podcasts.slice(0, 5).map((pod, i) => (
        <div key={pod.id} style={{ display: 'flex', gap: 12, padding: '12px 22px', alignItems: 'center', borderTop: i === 0 ? 'none' : `1px solid ${VT2.hairline}` }}>
          <window.VibeCover pod={pod} size={48} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontFamily: VT2.serif, fontSize: 16, fontWeight: 500, letterSpacing: '-0.005em', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{pod.title}</div>
            <div style={{ fontFamily: VT2.sans, fontSize: 13, color: VT2.inkDim, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', marginTop: 2 }}>{pod.latest.title}</div>
            <div style={{ display: 'flex', gap: 6, marginTop: 6, alignItems: 'center' }}>
              {pod.vibes.slice(0, 2).map(vid => <window.VibeDot key={vid} vibe={window.VIBE_BY_ID[vid]} />)}
              <span style={{ fontFamily: VT2.mono, fontSize: 9, color: VT2.inkMuted, letterSpacing: '0.08em', textTransform: 'uppercase', fontWeight: 600 }}>
                {pod.latest.age} · {pod.latest.total}M
              </span>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}

// ────────────────────────────────────────────────────────────
// VIBE SCREEN with "Add a show to this vibe" affordance
// ────────────────────────────────────────────────────────────
function VibeScreenAddShow({ vibeId = 'workout' }) {
  const vibe = window.VIBE_BY_ID[vibeId];
  const podcasts = window.VIBE_ORDER[vibeId].map(id => window.PODCAST_BY_ID[id]);
  return (
    <div style={{ background: VT2.bg, minHeight: '100%', color: VT2.ink, fontFamily: VT2.sans, paddingBottom: 24, position: 'relative' }}>
      <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 240,
        background: `linear-gradient(180deg, ${vibe.chip} 0%, ${VT2.bg} 100%)` }} />

      <div style={{ position: 'relative', padding: '60px 22px 14px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div style={{ fontFamily: VT2.mono, fontSize: 10, letterSpacing: '0.18em', textTransform: 'uppercase', color: vibe.ink, fontWeight: 700, display: 'inline-flex', alignItems: 'center', gap: 8 }}>
            <span style={{ width: 8, height: 8, borderRadius: 99, background: vibe.color }} />
            VIBE · APR 24
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <button style={iconBtn2}>{window.Icon.search(17, VT2.ink)}</button>
            <button style={{ ...iconBtn2, background: VT2.ink, color: VT2.paper, borderColor: VT2.ink }}><StackIcon2 color={VT2.paper} /></button>
          </div>
        </div>
        <h1 style={{ fontFamily: VT2.serif, fontSize: 44, fontWeight: 500, letterSpacing: '-0.025em', margin: '12px 0 4px', lineHeight: 1.05, color: vibe.ink }}>
          {vibe.name}
        </h1>
        <div style={{ fontFamily: VT2.serif, fontStyle: 'italic', fontSize: 14, color: VT2.inkDim }}>
          {podcasts.length} shows, in order.
        </div>
        <SwipeDots activeId={vibeId} />
      </div>

      <FilterBar2 activeId={vibeId} />
      <SectionLabel2 active={vibe} podcasts={podcasts} />

      {podcasts.slice(0, 3).map((pod, i) => (
        <div key={pod.id} style={{ display: 'flex', gap: 12, padding: '12px 22px', alignItems: 'center', borderTop: i === 0 ? `1px solid ${VT2.hairline}` : `1px solid ${VT2.hairline}` }}>
          <span style={{ fontFamily: VT2.mono, fontSize: 11, color: VT2.inkMuted, fontVariantNumeric: 'tabular-nums', width: 18 }}>{String(i + 1).padStart(2, '0')}</span>
          <window.VibeCover pod={pod} size={44} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontFamily: VT2.serif, fontSize: 15, fontWeight: 500, letterSpacing: '-0.005em' }}>{pod.title}</div>
            <div style={{ fontFamily: VT2.sans, fontSize: 12, color: VT2.inkDim, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', marginTop: 2 }}>{pod.latest.title}</div>
          </div>
        </div>
      ))}

      {/* Add-show row — visually a dashed "ghost" row at the bottom of the list */}
      <button style={{
        display: 'flex', gap: 12, padding: '14px 22px', alignItems: 'center',
        width: '100%', borderTop: `1px solid ${VT2.hairline}`,
        background: 'transparent', cursor: 'pointer', textAlign: 'left',
        border: 'none', borderBottom: `1px solid ${VT2.hairline}`,
      }}>
        <span style={{ fontFamily: VT2.mono, fontSize: 11, color: VT2.inkMuted, fontVariantNumeric: 'tabular-nums', width: 18 }}>{String(podcasts.length + 1).padStart(2, '0')}</span>
        <div style={{
          width: 44, height: 44, borderRadius: 6, background: VT2.paper,
          border: `1px dashed ${vibe.color}`, color: vibe.ink,
          display: 'inline-flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
        }}>{window.Icon.plus(18, vibe.ink)}</div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontFamily: VT2.serif, fontSize: 15, fontWeight: 500, letterSpacing: '-0.005em', color: vibe.ink }}>Add a show to this vibe</div>
          <div style={{ fontFamily: VT2.serif, fontStyle: 'italic', fontSize: 12, color: VT2.inkDim, marginTop: 2 }}>Pick from your followed shows or browse new ones.</div>
        </div>
      </button>

      <PageLabel>ADD SHOW · INLINE AFFORDANCE</PageLabel>
    </div>
  );
}

// ────────────────────────────────────────────────────────────
// ADD-SHOW-TO-VIBE PICKER (sheet)
// ────────────────────────────────────────────────────────────
function AddShowSheet({ vibeId = 'workout' }) {
  const vibe = window.VIBE_BY_ID[vibeId];
  // For each show, decide: already in this vibe / available to add / suggested
  const allShows = window.PODCASTS;
  return (
    <div style={{ background: VT2.bg, minHeight: '100%', color: VT2.ink, fontFamily: VT2.sans, paddingBottom: 24 }}>
      <div style={{ paddingTop: 56, display: 'flex', justifyContent: 'center' }}>
        <div style={{ width: 36, height: 4, borderRadius: 99, background: 'rgba(26,23,20,0.20)' }} />
      </div>
      <div style={{ padding: '20px 22px 6px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <button style={{ background: 'transparent', border: 'none', fontSize: 14, color: VT2.inkDim, fontFamily: VT2.sans, padding: 0 }}>Cancel</button>
        <div style={{ fontFamily: VT2.mono, fontSize: 10, letterSpacing: '0.18em', textTransform: 'uppercase', color: vibe.ink, fontWeight: 700, display: 'inline-flex', alignItems: 'center', gap: 6 }}>
          <span style={{ width: 8, height: 8, borderRadius: 99, background: vibe.color }} />
          ADD TO {vibe.name.toUpperCase()}
        </div>
        <button style={{ background: vibe.color, border: 'none', color: '#fff', fontWeight: 600, fontSize: 14, padding: '6px 14px', borderRadius: 999, fontFamily: VT2.sans }}>Add (2)</button>
      </div>

      <div style={{ padding: '14px 22px 4px' }}>
        <div style={{
          padding: '10px 14px', borderRadius: 12, background: VT2.paper,
          border: `1px solid ${VT2.hairline}`, display: 'flex', alignItems: 'center', gap: 10,
        }}>
          {window.Icon.search(16, VT2.inkMuted)}
          <span style={{ fontFamily: VT2.sans, fontSize: 14, color: VT2.inkMuted }}>Search your shows</span>
        </div>
      </div>

      <div style={{ padding: '14px 22px 4px' }}>
        <div style={{ fontFamily: VT2.mono, fontSize: 10, letterSpacing: '0.18em', textTransform: 'uppercase', color: VT2.inkMuted, fontWeight: 700 }}>
          FROM YOUR LIBRARY · {allShows.length}
        </div>
      </div>

      {allShows.slice(0, 7).map((pod, i) => {
        const inVibe = pod.vibes.includes(vibeId);
        const willAdd = i === 1 || i === 4; // demo: two newly checked
        return (
          <div key={pod.id} style={{
            display: 'flex', alignItems: 'center', gap: 12, padding: '10px 22px',
            borderTop: `1px solid ${VT2.hairline}`,
            opacity: inVibe ? 0.55 : 1,
          }}>
            <window.VibeCover pod={pod} size={40} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontFamily: VT2.serif, fontSize: 15, fontWeight: 500, letterSpacing: '-0.005em' }}>{pod.title}</div>
              <div style={{ fontFamily: VT2.mono, fontSize: 10, color: VT2.inkMuted, letterSpacing: '0.08em', textTransform: 'uppercase', marginTop: 2, display: 'flex', gap: 6, alignItems: 'center' }}>
                {pod.publisher}
                {pod.vibes.length > 0 && (
                  <>
                    <span style={{ opacity: 0.4 }}>·</span>
                    {pod.vibes.map(vid => <window.VibeDot key={vid} vibe={window.VIBE_BY_ID[vid]} size={6} />)}
                  </>
                )}
              </div>
            </div>
            {inVibe ? (
              <span style={{ fontFamily: VT2.mono, fontSize: 9, color: vibe.ink, letterSpacing: '0.08em', textTransform: 'uppercase', fontWeight: 700, padding: '4px 8px', background: vibe.chip, borderRadius: 99 }}>
                ADDED
              </span>
            ) : (
              <div style={{
                width: 26, height: 26, borderRadius: 99,
                background: willAdd ? vibe.color : 'transparent',
                boxShadow: willAdd ? 'none' : `inset 0 0 0 1.5px ${VT2.inkFaint}`,
                display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
              }}>
                {willAdd && <svg width={14} height={14} viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"><path d="M5 12l5 5L20 7"/></svg>}
              </div>
            )}
          </div>
        );
      })}

      <PageLabel>ADD-SHOW SHEET</PageLabel>
    </div>
  );
}

// ────────────────────────────────────────────────────────────
// PODCAST DETAIL with vibe tagging
// ────────────────────────────────────────────────────────────
function PodcastDetailVibes({ podId = 'hard-fork' }) {
  const pod = window.PODCAST_BY_ID[podId];
  const inVibes = pod.vibes;
  return (
    <div style={{ background: VT2.bg, minHeight: '100%', color: VT2.ink, fontFamily: VT2.sans, paddingBottom: 24, position: 'relative' }}>
      <div style={{ padding: '60px 22px 14px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <button style={iconBtn2}><ChevronLeft /></button>
        <div style={{ fontFamily: VT2.mono, fontSize: 10, letterSpacing: '0.18em', textTransform: 'uppercase', color: VT2.inkMuted, fontWeight: 700 }}>SHOW</div>
        <button style={iconBtn2}>{window.Icon.more(17, VT2.ink)}</button>
      </div>

      <div style={{ padding: '8px 22px 18px', display: 'flex', alignItems: 'center', gap: 14 }}>
        <window.VibeCover pod={pod} size={88} radius={8} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontFamily: VT2.mono, fontSize: 9, color: VT2.inkMuted, letterSpacing: '0.12em', textTransform: 'uppercase', fontWeight: 700 }}>
            {pod.publisher}
          </div>
          <h1 style={{ fontFamily: VT2.serif, fontSize: 28, fontWeight: 500, letterSpacing: '-0.02em', margin: '4px 0 6px', lineHeight: 1.05 }}>
            {pod.title}
          </h1>
          <div style={{ fontFamily: VT2.serif, fontStyle: 'italic', fontSize: 13, color: VT2.inkDim }}>
            Following · 312 episodes
          </div>
        </div>
      </div>

      {/* Vibe tagging section */}
      <div style={{ padding: '6px 22px 4px', display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
        <div style={{ fontFamily: VT2.mono, fontSize: 10, letterSpacing: '0.18em', textTransform: 'uppercase', color: VT2.inkDim, fontWeight: 700 }}>
          IN YOUR VIBES
        </div>
        <div style={{ fontFamily: VT2.serif, fontStyle: 'italic', fontSize: 12, color: VT2.inkMuted }}>
          {inVibes.length} of {window.VIBES.length}
        </div>
      </div>

      <div style={{ padding: '8px 22px 16px', display: 'flex', flexWrap: 'wrap', gap: 8 }}>
        {window.VIBES.map(v => {
          const tagged = inVibes.includes(v.id);
          return (
            <button key={v.id} style={{
              padding: '8px 12px', borderRadius: 999, border: 'none', cursor: 'pointer',
              background: tagged ? v.color : VT2.paper,
              color: tagged ? '#fff' : VT2.ink,
              boxShadow: tagged ? 'none' : `inset 0 0 0 1px ${VT2.hairline}`,
              fontFamily: VT2.sans, fontSize: 13, fontWeight: 600,
              display: 'inline-flex', alignItems: 'center', gap: 7,
            }}>
              <span style={{ width: 8, height: 8, borderRadius: 99, background: tagged ? '#fff' : v.color }} />
              {v.name}
              {tagged && <svg width={12} height={12} viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round"><path d="M5 12l5 5L20 7"/></svg>}
            </button>
          );
        })}
        <button style={{
          padding: '8px 12px', borderRadius: 999, cursor: 'pointer',
          background: 'transparent', border: `1px dashed ${VT2.inkFaint}`, color: VT2.inkDim,
          fontFamily: VT2.sans, fontSize: 13, fontWeight: 500,
          display: 'inline-flex', alignItems: 'center', gap: 5,
        }}>
          {window.Icon.plus(12, VT2.inkDim)} New vibe
        </button>
      </div>

      <div style={{ padding: '6px 22px 6px' }}>
        <div style={{ fontFamily: VT2.serif, fontStyle: 'italic', fontSize: 13, color: VT2.inkDim }}>
          Tap a vibe to add or remove this show. {inVibes.length === 0 ? "Once it's in a vibe, new episodes will be queued there." : null}
        </div>
      </div>

      {/* A few episode rows below for context */}
      <div style={{ padding: '14px 22px 6px', borderTop: `1px solid ${VT2.hairline}`, marginTop: 10 }}>
        <div style={{ fontFamily: VT2.mono, fontSize: 10, letterSpacing: '0.18em', textTransform: 'uppercase', color: VT2.inkDim, fontWeight: 700 }}>RECENT EPISODES</div>
      </div>
      {[
        { title: pod.latest.title, age: pod.latest.age, mins: pod.latest.total },
        { title: 'Why Anthropic Is Betting on Constitutional AI', age: '5d ago', mins: 58 },
        { title: 'A Talk With Sundar', age: '1w ago', mins: 71 },
      ].map((ep, i) => (
        <div key={i} style={{ padding: '12px 22px', borderTop: i === 0 ? 'none' : `1px solid ${VT2.hairline}` }}>
          <div style={{ fontFamily: VT2.serif, fontSize: 15, fontWeight: 500, letterSpacing: '-0.005em', lineHeight: 1.3 }}>{ep.title}</div>
          <div style={{ fontFamily: VT2.mono, fontSize: 10, color: VT2.inkMuted, letterSpacing: '0.08em', textTransform: 'uppercase', marginTop: 4, fontWeight: 600 }}>
            {ep.age} · {ep.mins}M
          </div>
        </div>
      ))}

      <PageLabel>PODCAST DETAIL · TAG TO VIBES</PageLabel>
    </div>
  );
}

// ────────────────────────────────────────────────────────────
// YOUR VIBES — manage / reorder / delete / create
// (Reached by tapping the grid icon. Drag handles + delete buttons + add card.)
// ────────────────────────────────────────────────────────────
function YourVibesManage({ editing = false }) {
  return (
    <div style={{ background: VT2.bg, minHeight: '100%', color: VT2.ink, fontFamily: VT2.sans, paddingBottom: 100, position: 'relative' }}>
      <div style={{ padding: '60px 22px 8px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <button style={iconBtn2}><ChevronLeft /></button>
        <div style={{ fontFamily: VT2.mono, fontSize: 10, letterSpacing: '0.18em', textTransform: 'uppercase', color: VT2.inkMuted, fontWeight: 700 }}>MANAGE VIBES</div>
        <button style={{ ...iconBtn2, paddingLeft: 12, paddingRight: 14, width: 'auto' }}>
          <span style={{ fontSize: 13, fontWeight: 600 }}>{editing ? 'Done' : 'Edit'}</span>
        </button>
      </div>

      <div style={{ padding: '14px 22px 8px' }}>
        <h1 style={{ fontFamily: VT2.serif, fontSize: 38, fontWeight: 500, letterSpacing: '-0.025em', margin: 0, lineHeight: 1.05 }}>
          Manage vibes
        </h1>
        <div style={{ fontFamily: VT2.serif, fontStyle: 'italic', fontSize: 14, color: VT2.inkDim, marginTop: 4 }}>
          {editing
            ? 'Drag to reorder how they appear in your filter pills. Tap − to delete.'
            : 'Tap a vibe to rename or recolor. Tap Edit to reorder or delete.'}
        </div>
      </div>

      {/* List rows — easier to reorder than cards */}
      <div style={{ padding: '8px 0' }}>
        {window.VIBES.map((v, i) => (
          <ManageRow key={v.id} vibe={v} editing={editing} dragging={editing && i === 1} />
        ))}

        {/* Create new vibe — always present */}
        <div style={{
          margin: '10px 22px 0', padding: '14px 16px', borderRadius: 14,
          background: VT2.paper, border: `1px dashed ${VT2.inkFaint}`,
          display: 'flex', alignItems: 'center', gap: 12, color: VT2.ink,
        }}>
          <div style={{ width: 36, height: 36, borderRadius: 999, background: VT2.bg, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            {window.Icon.plus(18, VT2.ink)}
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontFamily: VT2.serif, fontSize: 16, fontWeight: 500, letterSpacing: '-0.01em' }}>New vibe</div>
            <div style={{ fontFamily: VT2.serif, fontStyle: 'italic', fontSize: 12, color: VT2.inkDim, marginTop: 2 }}>Name it, pick a color, add some shows.</div>
          </div>
        </div>
      </div>

      <PageLabel>{editing ? 'YOUR VIBES · EDIT/REORDER' : 'YOUR VIBES · DEFAULT'}</PageLabel>
    </div>
  );
}

function ManageRow({ vibe, editing, dragging }) {
  const podcasts = window.VIBE_ORDER[vibe.id].map(id => window.PODCAST_BY_ID[id]);
  return (
    <div style={{
      margin: '0 22px', padding: '12px 14px', borderRadius: 14,
      background: vibe.chip,
      border: `1px solid ${VT2.hairline}`,
      marginBottom: 8,
      display: 'flex', alignItems: 'center', gap: 10,
      transform: dragging ? 'scale(1.02) rotate(-0.4deg)' : 'none',
      boxShadow: dragging ? '0 12px 30px rgba(0,0,0,0.18)' : 'none',
      opacity: dragging ? 0.95 : 1,
      position: 'relative',
    }}>
      {editing && (
        <div style={{
          width: 22, height: 22, borderRadius: 99, background: '#B5371E',
          color: '#fff', display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
          fontSize: 16, fontWeight: 600, lineHeight: 1, paddingBottom: 2, flexShrink: 0,
          boxShadow: '0 1px 4px rgba(0,0,0,0.15)',
        }}>−</div>
      )}
      <div style={{
        width: 32, height: 32, borderRadius: 8, background: vibe.color,
        display: 'inline-flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
        boxShadow: 'inset 0 0 0 2px rgba(255,255,255,0.4)',
      }} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontFamily: VT2.serif, fontSize: 17, fontWeight: 500, letterSpacing: '-0.01em', color: vibe.ink }}>
          {vibe.name}
        </div>
        <div style={{ fontFamily: VT2.mono, fontSize: 10, color: vibe.ink, opacity: 0.7, letterSpacing: '0.08em', textTransform: 'uppercase', marginTop: 2, fontWeight: 600 }}>
          {podcasts.length} shows · {Math.round(podcasts.reduce((a, p) => a + p.latest.total, 0) / 60 * 10) / 10}H queued
        </div>
      </div>
      {!editing && (
        <>
          <div style={{ display: 'flex' }}>
            {podcasts.slice(0, 3).map((p, i) => (
              <div key={p.id} style={{ marginLeft: i === 0 ? 0 : -8, borderRadius: 4, border: `2px solid ${vibe.chip}` }}>
                <window.VibeCover pod={p} size={26} radius={3} />
              </div>
            ))}
          </div>
          <svg width={16} height={16} viewBox="0 0 24 24" fill="none" stroke={vibe.ink} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" style={{ opacity: 0.45, marginLeft: 4 }}><path d="M9 6l6 6-6 6" /></svg>
        </>
      )}
      {editing && (
        <div style={{ color: vibe.ink, opacity: 0.5 }}><DragIcon color="currentColor" /></div>
      )}
    </div>
  );
}

Object.assign(window, {
  HomeFinal, HomeSwiping, VibeScreenAddShow, AddShowSheet, PodcastDetailVibes, YourVibesManage,
});
