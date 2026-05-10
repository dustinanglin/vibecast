// Vibes — entry-point explorations + management destination.
// Question: from the home page, how do you (a) get to a list of all your vibes,
// (b) create a new vibe, and (c) edit/delete an existing one?

const VTE = window.VIBE_TOKENS;

// ────────────────────────────────────────────────────────────
// Shared bits
// ────────────────────────────────────────────────────────────
const iconBtnE = {
  width: 36, height: 36, borderRadius: 999, border: `1px solid ${VTE.hairline}`,
  background: VTE.paper, color: VTE.ink,
  display: 'inline-flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer'
};

function GridIcon({ size = 17, color = VTE.ink }) {
  // 2x2 rounded squares — reads as "all vibes / collection"
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="1.8" strokeLinejoin="round">
      <rect x="4" y="4" width="7" height="7" rx="1.5" />
      <rect x="13" y="4" width="7" height="7" rx="1.5" />
      <rect x="4" y="13" width="7" height="7" rx="1.5" />
      <rect x="13" y="13" width="7" height="7" rx="1.5" />
    </svg>);

}

function StackIcon({ size = 17, color = VTE.ink }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 8l8-4 8 4-8 4-8-4z" />
      <path d="M4 13l8 4 8-4" />
      <path d="M4 17l8 4 8-4" />
    </svg>);

}

function CheckIcon({ size = 14, color = '#fff' }) {
  return <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"><path d="M5 12l5 5L20 7" /></svg>;
}

function MasthedRow({ children, withVibesIcon, withStackIcon }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
      <div style={{ fontFamily: VTE.mono, fontSize: 10, letterSpacing: '0.18em', textTransform: 'uppercase', color: VTE.inkMuted, fontWeight: 600 }}>
        VOL. 12 &middot; APR 24
      </div>
      <div style={{ display: 'flex', gap: 8 }}>
        {children}
        {withVibesIcon &&
        <button style={iconBtnE} aria-label="Vibes"><GridIcon /></button>
        }
        {withStackIcon &&
        <button style={iconBtnE} aria-label="Vibes"><StackIcon /></button>
        }
        <button style={iconBtnE}>{window.Icon.search(17, VTE.ink)}</button>
      </div>
    </div>);

}

// ────────────────────────────────────────────────────────────
// HOME — entry-point variants
// Each shows a slightly different way to surface the "all my vibes" door.
// ────────────────────────────────────────────────────────────

function HomeWithIcon({ variant = 'grid', highlight = true }) {
  // Variant A — a grid (or stack) icon button, top right
  return (
    <Home label={variant === 'grid' ? 'A · GRID ICON IN HEADER' : 'A2 · STACK ICON IN HEADER'}>
      <Masthead>
        {/* highlight ring around the vibes icon to show what we mean */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <Volstamp />
          <div style={{ display: 'flex', gap: 8, position: 'relative' }}>
            <button style={iconBtnE}>{window.Icon.search(17, VTE.ink)}</button>
            <div style={{ position: 'relative' }}>
              <button style={{
                ...iconBtnE,
                ...(highlight ? { background: VTE.ink, color: VTE.paper, borderColor: VTE.ink } : {})
              }} aria-label="Vibes">
                {variant === 'stack' ?
                <StackIcon color={highlight ? VTE.paper : VTE.ink} /> :
                <GridIcon color={highlight ? VTE.paper : VTE.ink} />}
              </button>
              {highlight &&
              <CalloutLabel>Vibes</CalloutLabel>
              }
            </div>
            <button style={iconBtnE}>{window.Icon.plus(17, VTE.ink)}</button>
          </div>
        </div>
        <Wordmark />
      </Masthead>
      <PlainList />
    </Home>);

}

function HomeWithManagePill() {
  // Variant B — last pill is "Manage" at the end of the filter row.
  return (
    <Home label="B · 'MANAGE' AT END OF FILTER ROW">
      <Masthead>
        <MasthedRow />
        <Wordmark />
      </Masthead>
      <FilterBarWithManage highlight />
      <PlainList offset />
    </Home>);

}

function HomeWithShelf() {
  // Variant C — a small "Your vibes" shelf above the show list.
  // Cards: a card per vibe + "+ New" card. Tap a card → filter; tap header link → gallery.
  return (
    <Home label="C · 'YOUR VIBES' SHELF" hideFilterBar>
      <Masthead>
        <MasthedRow />
        <Wordmark />
      </Masthead>

      <div style={{ padding: '8px 22px 6px', display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
        <div style={{ fontFamily: VTE.mono, fontSize: 10, letterSpacing: '0.18em', textTransform: 'uppercase', color: VTE.inkDim, fontWeight: 700 }}>
          YOUR VIBES
        </div>
        <button style={{
          background: 'transparent', border: 'none', padding: 0, cursor: 'pointer',
          fontFamily: VTE.serif, fontStyle: 'italic', fontSize: 13, color: VTE.ink, textDecoration: 'underline', textUnderlineOffset: 3, textDecorationColor: VTE.inkFaint
        }}>See all</button>
      </div>
      <div style={{ display: 'flex', gap: 10, overflow: 'auto', padding: '4px 22px 14px' }}>
        {window.VIBES.map((v) =>
        <VibeMiniCard key={v.id} vibe={v} />
        )}
        <NewVibeMiniCard />
      </div>

      <div style={{ padding: '4px 22px 8px', display: 'flex', alignItems: 'center', gap: 10 }}>
        <div style={{ fontFamily: VTE.mono, fontSize: 10, letterSpacing: '0.18em', textTransform: 'uppercase', color: VTE.inkDim, fontWeight: 600 }}>
          ALL SHOWS · MOST RECENT
        </div>
        <div style={{ flex: 1, height: 1, background: VTE.hairline }} />
      </div>
      <PlainList />
    </Home>);

}

function HomeWithLongPress() {
  // Variant D — long press a vibe pill reveals an action sheet.
  return (
    <Home label="D · LONG-PRESS A PILL" overlay={<LongPressSheet />}>
      <Masthead>
        <MasthedRow />
        <Wordmark />
      </Masthead>
      <FilterBarWithManage pressedId="around" />
      <PlainList offset />
    </Home>);

}

// ────────────────────────────────────────────────────────────
// Home shell (consistent across variants)
// ────────────────────────────────────────────────────────────
function Home({ children, label, overlay, hideFilterBar }) {
  return (
    <div style={{ background: VTE.bg, minHeight: '100%', color: VTE.ink, fontFamily: VTE.sans, paddingBottom: 100, position: 'relative' }}>
      {children}
      {label &&
      <div style={{
        position: 'absolute', left: 22, top: 50, padding: '4px 8px',
        background: VTE.ink, color: VTE.paper,
        fontFamily: VTE.mono, fontSize: 9, letterSpacing: '0.14em', textTransform: 'uppercase', fontWeight: 700,
        borderRadius: 4
      }}>{label}</div>
      }
      {overlay}
    </div>);

}

function Masthead({ children }) {
  return <div style={{ padding: '60px 22px 14px' }}>{children}</div>;
}

function Volstamp() {
  return (
    <div style={{ fontFamily: VTE.mono, fontSize: 10, letterSpacing: '0.18em', textTransform: 'uppercase', color: VTE.inkMuted, fontWeight: 600 }}>
      VOL. 12 &middot; APR 24
    </div>);

}
function Wordmark() {
  return (
    <>
      <h1 style={{ fontFamily: VTE.serif, fontSize: 50, fontWeight: 500, letterSpacing: '-0.025em', margin: '10px 0 4px', lineHeight: 1 }}>Vibecast</h1>
      <div style={{ fontFamily: VTE.serif, fontStyle: 'italic', fontSize: 14, color: VTE.inkDim }}>Your shows, in your order</div>
    </>);

}

function CalloutLabel({ children }) {
  return (
    <div style={{
      position: 'absolute', top: 'calc(100% + 8px)', right: 0, whiteSpace: 'nowrap',
      padding: '4px 8px', borderRadius: 4,
      background: VTE.ink, color: VTE.paper,
      fontFamily: VTE.mono, fontSize: 9, letterSpacing: '0.14em', textTransform: 'uppercase', fontWeight: 700
    }}>
      <div style={{ position: 'absolute', top: -4, right: 14, width: 8, height: 8, background: VTE.ink, transform: 'rotate(45deg)' }} />
      {children}
    </div>);

}

// ────────────────────────────────────────────────────────────
// Plain list of shows (used as "rest of the screen" filler so
// each variant looks like a real home, not just a header)
// ────────────────────────────────────────────────────────────
function PlainList({ offset = false }) {
  const podcasts = window.ALL_ORDER.slice(0, 5).map((id) => window.PODCAST_BY_ID[id]);
  return (
    <div style={{ marginTop: offset ? 4 : 8 }}>
      {podcasts.map((pod, i) =>
      <div key={pod.id} style={{ display: 'flex', gap: 12, padding: '12px 22px', alignItems: 'center', borderTop: i === 0 ? 'none' : `1px solid ${VTE.hairline}` }}>
          <window.VibeCover pod={pod} size={48} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontFamily: VTE.serif, fontSize: 16, fontWeight: 500, letterSpacing: '-0.005em', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
              {pod.title}
            </div>
            <div style={{ fontFamily: VTE.sans, fontSize: 13, color: VTE.inkDim, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', marginTop: 2 }}>
              {pod.latest.title}
            </div>
            <div style={{ display: 'flex', gap: 6, marginTop: 6 }}>
              {pod.vibes.slice(0, 2).map((vid) => {
              const v = window.VIBE_BY_ID[vid];
              return <window.VibeDot key={vid} vibe={v} />;
            })}
              <span style={{ fontFamily: VTE.mono, fontSize: 9, color: VTE.inkMuted, letterSpacing: '0.08em', textTransform: 'uppercase', fontWeight: 600 }}>
                {pod.latest.age} · {pod.latest.total}M
              </span>
            </div>
          </div>
        </div>
      )}
    </div>);

}

// ────────────────────────────────────────────────────────────
// Filter pill row with optional "Manage" trailing pill
// ────────────────────────────────────────────────────────────
function FilterBarWithManage({ highlight = false, pressedId = null }) {
  return (
    <div style={{
      padding: '12px 18px 10px', display: 'flex', gap: 6,
      background: `linear-gradient(180deg, ${VTE.bg} 80%, ${VTE.bg}00 100%)`
    }}>
      <div style={{ display: 'flex', gap: 6, overflow: 'hidden', flex: 1, paddingRight: 4 }}>
        <Pill label="All vibes" />
        {window.VIBES.slice(0, 4).map((v) =>
        <Pill key={v.id} vibe={v} label={v.name} pressed={pressedId === v.id} />
        )}
        <ManagePill highlight={highlight} />
      </div>
    </div>);

}

function Pill({ vibe, label, active, pressed }) {
  return (
    <button style={{
      flexShrink: 0, height: 32, padding: '0 12px',
      borderRadius: 999, border: 'none', cursor: 'pointer',
      background: active ? vibe ? vibe.color : VTE.ink : VTE.paper,
      color: active ? '#fff' : VTE.ink,
      boxShadow: pressed ?
      `inset 0 0 0 1.5px ${VTE.ink}, 0 0 0 4px ${VTE.ink}1a` :
      `inset 0 0 0 1px ${VTE.hairline}`,
      fontFamily: VTE.sans, fontSize: 13, fontWeight: 600,
      display: 'inline-flex', alignItems: 'center', gap: 7,
      transform: pressed ? 'scale(0.97)' : 'none'
    }}>
      {vibe && <span style={{ width: 8, height: 8, borderRadius: 99, background: active ? '#fff' : vibe.color }} />}
      {label}
    </button>);

}

function ManagePill({ highlight }) {
  return (
    <button style={{
      flexShrink: 0, height: 32, padding: '0 12px',
      borderRadius: 999, border: 'none', cursor: 'pointer',
      background: highlight ? VTE.ink : 'transparent',
      color: highlight ? VTE.paper : VTE.ink,
      boxShadow: highlight ? 'none' : `inset 0 0 0 1px ${VTE.inkFaint}`,
      borderStyle: highlight ? 'solid' : 'dashed',
      fontFamily: VTE.sans, fontSize: 13, fontWeight: 600,
      display: 'inline-flex', alignItems: 'center', gap: 6
    }}>
      <span style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center', width: 14, height: 14 }}>
        <GridIcon size={12} color={highlight ? VTE.paper : VTE.ink} />
      </span>
      Manage
    </button>);

}

// ────────────────────────────────────────────────────────────
// Long-press action sheet
// ────────────────────────────────────────────────────────────
function LongPressSheet() {
  return (
    <div style={{
      position: 'absolute', left: 0, right: 0, top: 0, bottom: 0,
      background: 'rgba(26,23,20,0.32)',
      display: 'flex', flexDirection: 'column', justifyContent: 'flex-end',
      padding: 14
    }}>
      <div style={{
        background: VTE.paper, borderRadius: 14,
        boxShadow: '0 24px 60px rgba(0,0,0,0.18)',
        overflow: 'hidden'
      }}>
        <SheetRow icon={window.Icon.play(16, VTE.ink)} label="Start the vibe" />
        <SheetRow icon={<GridIcon size={16} />} label="Edit vibe…" sub="Rename, recolor, reorder shows" />
        <SheetRow icon={window.Icon.plus(16, VTE.ink)} label="Add show to this vibe" />
        <SheetRow icon={<TrashIcon />} label="Delete vibe" danger />
      </div>
      <div style={{ height: 8 }} />
      <div style={{
        background: VTE.paper, borderRadius: 14, padding: 14, textAlign: 'center',
        fontFamily: VTE.sans, fontSize: 15, fontWeight: 600, color: VTE.ink
      }}>Cancel</div>
    </div>);

}

function SheetRow({ icon, label, sub, danger }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 14, padding: '14px 16px',
      borderTop: `1px solid ${VTE.hairline}`,
      color: danger ? '#B5371E' : VTE.ink
    }}>
      <div style={{ width: 22, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{icon}</div>
      <div style={{ flex: 1 }}>
        <div style={{ fontFamily: VTE.sans, fontSize: 15, fontWeight: 500 }}>{label}</div>
        {sub && <div style={{ fontFamily: VTE.serif, fontStyle: 'italic', fontSize: 12, color: VTE.inkDim, marginTop: 1 }}>{sub}</div>}
      </div>
    </div>);

}

function TrashIcon({ size = 16, color = '#B5371E' }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <path d="M5 7h14M9 7V5a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2M7 7l1 12a2 2 0 0 0 2 2h4a2 2 0 0 0 2-2l1-12" />
    </svg>);

}

// ────────────────────────────────────────────────────────────
// Mini vibe card — used in shelf
// ────────────────────────────────────────────────────────────
function VibeMiniCard({ vibe }) {
  const podcasts = window.VIBE_ORDER[vibe.id].map((id) => window.PODCAST_BY_ID[id]);
  return (
    <div style={{
      flexShrink: 0, width: 144, padding: 12, borderRadius: 14,
      background: vibe.chip, border: `1px solid ${VTE.hairline}`,
      display: 'flex', flexDirection: 'column', gap: 8
    }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <span style={{ width: 14, height: 14, borderRadius: 99, background: vibe.color }} />
        <span style={{ fontFamily: VTE.mono, fontSize: 9, color: vibe.ink, letterSpacing: '0.08em', fontWeight: 700, textTransform: 'uppercase' }}>
          {podcasts.length}
        </span>
      </div>
      <div style={{ fontFamily: VTE.serif, fontSize: 16, fontWeight: 500, letterSpacing: '-0.01em', color: vibe.ink, lineHeight: 1.15 }}>
        {vibe.name}
      </div>
      <div style={{ display: 'flex' }}>
        {podcasts.slice(0, 3).map((p, i) =>
        <div key={p.id} style={{ marginLeft: i === 0 ? 0 : -8, borderRadius: 4, border: `2px solid ${vibe.chip}` }}>
            <window.VibeCover pod={p} size={22} radius={3} />
          </div>
        )}
      </div>
    </div>);

}

function NewVibeMiniCard() {
  return (
    <div style={{
      flexShrink: 0, width: 144, padding: 12, borderRadius: 14,
      background: VTE.paper, border: `1px dashed ${VTE.inkFaint}`,
      display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 8,
      color: VTE.inkDim
    }}>
      {window.Icon.plus(20, VTE.inkDim)}
      <div style={{ fontFamily: VTE.sans, fontSize: 13, fontWeight: 500 }}>New vibe</div>
    </div>);

}

// ────────────────────────────────────────────────────────────
// VIBES GALLERY — destination from any of the entry points
// All your vibes, plus "+ Create" tile. Tap a card → filter.
// "Edit" reveals reorder + rename per card.
// ────────────────────────────────────────────────────────────
function VibesGalleryScreen({ editing = false }) {
  return (
    <div style={{ background: VTE.bg, minHeight: '100%', color: VTE.ink, fontFamily: VTE.sans, paddingBottom: 100, position: 'relative' }}>
      <div style={{ padding: '60px 22px 14px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <button style={{ ...iconBtnE, paddingLeft: 12, paddingRight: 14, width: 'auto' }}>
            <span style={{ fontSize: 13, fontWeight: 600 }}>Done</span>
          </button>
          <div style={{ fontFamily: VTE.mono, fontSize: 10, letterSpacing: '0.18em', textTransform: 'uppercase', color: VTE.inkMuted, fontWeight: 700 }}>VIBES</div>
          <button style={{ ...iconBtnE, paddingLeft: 12, paddingRight: 14, width: 'auto' }}>
            <span style={{ fontSize: 13, fontWeight: 600 }}>{editing ? 'Done' : 'Edit'}</span>
          </button>
        </div>
        <h1 style={{ fontFamily: VTE.serif, fontSize: 40, fontWeight: 500, letterSpacing: '-0.025em', margin: '14px 0 4px', lineHeight: 1.05 }}>
          Your vibes
        </h1>
        <div style={{ fontFamily: VTE.serif, fontStyle: 'italic', fontSize: 14, color: VTE.inkDim }}>
          Five collections. Tap one to filter your home page; long-press to edit.
        </div>
      </div>

      <div style={{ padding: '4px 18px 18px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
        {window.VIBES.map((v) =>
        <GalleryVibeCard key={v.id} vibe={v} editing={editing} />
        )}
        <CreateVibeCard />
      </div>
    </div>);

}

function GalleryVibeCard({ vibe, editing }) {
  const podcasts = window.VIBE_ORDER[vibe.id].map((id) => window.PODCAST_BY_ID[id]);
  const totalMin = podcasts.reduce((a, p) => a + p.latest.total, 0);
  return (
    <div style={{
      background: vibe.chip, borderRadius: 16, padding: 14,
      border: `1px solid ${VTE.hairline}`,
      minHeight: 158, display: 'flex', flexDirection: 'column', position: 'relative'
    }}>
      {editing &&
      <div style={{
        position: 'absolute', top: -6, left: -6,
        width: 22, height: 22, borderRadius: 99, background: '#B5371E',
        color: '#fff', display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
        fontSize: 16, fontWeight: 600, lineHeight: 1, paddingBottom: 2,
        boxShadow: '0 2px 6px rgba(0,0,0,0.2)'
      }}>−</div>
      }
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
        <span style={{ width: 18, height: 18, borderRadius: 99, background: vibe.color, boxShadow: 'inset 0 0 0 2px rgba(255,255,255,0.4)' }} />
        <div style={{ fontFamily: VTE.mono, fontSize: 9, color: vibe.ink, letterSpacing: '0.08em', textTransform: 'uppercase', fontWeight: 700 }}>
          {podcasts.length} · {Math.round(totalMin / 60 * 10) / 10}H
        </div>
      </div>
      <div style={{ flex: 1 }} />
      <div style={{ fontFamily: VTE.serif, fontSize: 19, fontWeight: 500, letterSpacing: '-0.01em', color: vibe.ink, lineHeight: 1.1 }}>
        {vibe.name}
      </div>
      <div style={{ marginTop: 8, display: 'flex' }}>
        {podcasts.slice(0, 4).map((p, i) =>
        <div key={p.id} style={{ marginLeft: i === 0 ? 0 : -8, borderRadius: 4, border: `2px solid ${vibe.chip}` }}>
            <window.VibeCover pod={p} size={26} radius={3} />
          </div>
        )}
        {podcasts.length > 4 &&
        <div style={{ marginLeft: -8, width: 26, height: 26, borderRadius: 4, background: 'rgba(0,0,0,0.06)', border: `2px solid ${vibe.chip}`, fontFamily: VTE.mono, fontSize: 9, color: vibe.ink, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700 }}>+{podcasts.length - 4}</div>
        }
      </div>
      {editing &&
      <div style={{
        position: 'absolute', right: 8, bottom: 8,
        width: 24, height: 24, color: vibe.ink, display: 'inline-flex', alignItems: 'center', justifyContent: 'center'
      }}>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
            <path d="M4 8h16M4 16h16" />
          </svg>
        </div>
      }
    </div>);

}

function CreateVibeCard() {
  return (
    <div style={{
      background: VTE.paper, border: `1px dashed ${VTE.inkFaint}`, borderRadius: 16, padding: 14,
      display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 10,
      minHeight: 158, color: VTE.inkDim
    }}>
      <div style={{ width: 36, height: 36, borderRadius: 999, background: VTE.bg, display: 'inline-flex', alignItems: 'center', justifyContent: 'center' }}>
        {window.Icon.plus(20, VTE.ink)}
      </div>
      <div style={{ fontFamily: VTE.serif, fontSize: 17, fontWeight: 500, color: VTE.ink, letterSpacing: '-0.01em' }}>New vibe</div>
      <div style={{ fontFamily: VTE.serif, fontStyle: 'italic', fontSize: 12, color: VTE.inkMuted, textAlign: 'center', lineHeight: 1.3 }}>
        Name it, pick a color,<br />add some shows.
      </div>
    </div>);

}

// ────────────────────────────────────────────────────────────
// CREATE VIBE — bottom sheet (name + curated palette + initial shows)
// ────────────────────────────────────────────────────────────
const PALETTE = [
{ color: 'oklch(0.68 0.14 35)', ink: 'oklch(0.32 0.10 35)' }, // amber
{ color: 'oklch(0.62 0.13 18)', ink: 'oklch(0.30 0.10 18)' }, // brick
{ color: 'oklch(0.62 0.16 145)', ink: 'oklch(0.30 0.10 145)' }, // green
{ color: 'oklch(0.60 0.13 200)', ink: 'oklch(0.32 0.10 200)' }, // teal
{ color: 'oklch(0.55 0.13 245)', ink: 'oklch(0.30 0.10 245)' }, // blue
{ color: 'oklch(0.55 0.13 280)', ink: 'oklch(0.30 0.10 280)' }, // violet
{ color: 'oklch(0.58 0.16 350)', ink: 'oklch(0.30 0.10 350)' }, // pink
{ color: 'oklch(0.45 0.04 60)', ink: 'oklch(0.25 0.04 60)' } // graphite
];

function CreateVibeSheet({ selectedHueIdx = 4, name = 'Long drive' }) {
  const sel = PALETTE[selectedHueIdx];
  return (
    <div style={{ background: VTE.bg, minHeight: '100%', color: VTE.ink, fontFamily: VTE.sans, paddingBottom: 24, position: 'relative' }}>
      {/* Drag handle */}
      <div style={{ paddingTop: 56, display: 'flex', justifyContent: 'center' }}>
        <div style={{ width: 36, height: 4, borderRadius: 99, background: 'rgba(26,23,20,0.20)' }} />
      </div>
      <div style={{ padding: '20px 22px 6px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <button style={{ background: 'transparent', border: 'none', fontSize: 14, color: VTE.inkDim, fontFamily: VTE.sans, padding: 0 }}>Cancel</button>
        <div style={{ fontFamily: VTE.mono, fontSize: 10, letterSpacing: '0.18em', textTransform: 'uppercase', color: VTE.inkMuted, fontWeight: 700 }}>NEW VIBE</div>
        <button style={{
          background: sel.color, border: 'none', color: '#fff', fontWeight: 600, fontSize: 14,
          padding: '6px 14px', borderRadius: 999, fontFamily: VTE.sans
        }}>Create</button>
      </div>

      {/* Name field — preview as serif */}
      <div style={{ padding: '14px 22px 4px' }}>
        <div style={{
          padding: '14px 16px', borderRadius: 14, background: VTE.paper, border: `1px solid ${VTE.hairline}`,
          display: 'flex', alignItems: 'center', gap: 12
        }}>
          <span style={{ width: 14, height: 14, borderRadius: 99, background: sel.color, flexShrink: 0 }} />
          <input
            type="text" defaultValue={name}
            style={{
              flex: 1, border: 'none', background: 'transparent', outline: 'none',
              fontFamily: VTE.serif, fontSize: 22, fontWeight: 500, letterSpacing: '-0.015em', color: VTE.ink
            }} />
          <span style={{ fontFamily: VTE.mono, fontSize: 9, color: VTE.inkMuted, letterSpacing: '0.08em', fontWeight: 700, textTransform: 'uppercase' }}>
            {name.length}/24
          </span>
        </div>
      </div>

      {/* Palette */}
      <div style={{ padding: '18px 22px 4px' }}>
        <div style={{ fontFamily: VTE.mono, fontSize: 10, letterSpacing: '0.18em', textTransform: 'uppercase', color: VTE.inkMuted, fontWeight: 700, marginBottom: 12 }}>
          COLOR
        </div>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10 }}>
          {PALETTE.map((p, i) =>
          <div key={i} style={{
            width: 38, height: 38, borderRadius: 99, background: p.color,
            boxShadow: i === selectedHueIdx ? `0 0 0 2px ${VTE.bg}, 0 0 0 4px ${VTE.ink}` : `inset 0 0 0 1px rgba(0,0,0,0.10)`,
            cursor: 'pointer', position: 'relative',
            display: 'inline-flex', alignItems: 'center', justifyContent: 'center'
          }}>
              {i === selectedHueIdx && <CheckIcon size={16} color="#fff" />}
            </div>
          )}
        </div>
      </div>

      {/* Add shows */}
      <div style={{ padding: '22px 22px 4px' }}>
        <div style={{ fontFamily: VTE.mono, fontSize: 10, letterSpacing: '0.18em', textTransform: 'uppercase', color: VTE.inkMuted, fontWeight: 700, marginBottom: 4 }}>
          SHOWS
        </div>
        <div style={{ fontFamily: VTE.serif, fontStyle: 'italic', fontSize: 13, color: VTE.inkDim, marginBottom: 10 }}>Pick the shows that belong to this vibe. You can reorder later.

        </div>
      </div>
      {window.PODCASTS.slice(0, 5).map((pod, i) => {
        const checked = i === 0 || i === 2 || i === 4;
        return (
          <div key={pod.id} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 22px', borderTop: `1px solid ${VTE.hairline}` }}>
            <window.VibeCover pod={pod} size={40} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontFamily: VTE.serif, fontSize: 15, fontWeight: 500, letterSpacing: '-0.005em' }}>{pod.title}</div>
              <div style={{ fontFamily: VTE.mono, fontSize: 10, color: VTE.inkMuted, letterSpacing: '0.08em', textTransform: 'uppercase', marginTop: 2 }}>{pod.publisher}</div>
            </div>
            <div style={{
              width: 26, height: 26, borderRadius: 99,
              background: checked ? sel.color : 'transparent',
              boxShadow: checked ? 'none' : `inset 0 0 0 1.5px ${VTE.inkFaint}`,
              display: 'inline-flex', alignItems: 'center', justifyContent: 'center'
            }}>
              {checked && <CheckIcon size={14} color="#fff" />}
            </div>
          </div>);

      })}
    </div>);

}

Object.assign(window, {
  HomeWithIcon, HomeWithManagePill, HomeWithShelf, HomeWithLongPress,
  VibesGalleryScreen, CreateVibeSheet
});