// Direction A — Refined Dark
// Same visual DNA as the current app, but tightened: warmer near-black,
// better hierarchy, accent that comes from the show, generous spacing.

const A = {
  bg: '#0B0B0E',         // warmer near-black (current is flat #000)
  surface: '#15161A',    // panels
  surfaceHi: '#1C1E24',  // pressed/raised
  hairline: 'rgba(255,255,255,0.07)',
  text: '#F2F2F3',
  textDim: 'rgba(242,242,243,0.62)',
  textMuted: 'rgba(242,242,243,0.42)',
  accent: 'oklch(0.72 0.16 240)',   // softer blue
  font: '"Inter", -apple-system, system-ui, sans-serif',
};

function A_Library({ accent = A.accent }) {
  const eps = window.EPISODES.slice(0, 6);
  return (
    <div style={{ background: A.bg, minHeight: '100%', color: A.text, fontFamily: A.font, paddingBottom: 96 }}>
      {/* Top bar — pill chips */}
      <div style={{ padding: '64px 20px 0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <button style={{
          background: A.surface, color: A.text, border: 'none',
          height: 34, padding: '0 16px', borderRadius: 999, fontSize: 15, fontWeight: 500, fontFamily: A.font,
        }}>Edit</button>
        <div style={{ display: 'flex', gap: 8 }}>
          <button style={iconBtnA}>{window.Icon.search(18, A.text)}</button>
          <button style={iconBtnA}>{window.Icon.plus(18, A.text)}</button>
        </div>
      </div>

      {/* Title + count */}
      <div style={{ padding: '20px 20px 6px' }}>
        <div style={{ fontSize: 12, fontWeight: 600, color: accent, letterSpacing: '0.14em', textTransform: 'uppercase', marginBottom: 8 }}>Library</div>
        <h1 style={{ fontSize: 38, fontWeight: 700, letterSpacing: '-0.025em', margin: 0, lineHeight: 1.05 }}>Vibecast</h1>
        <div style={{ marginTop: 6, fontSize: 13, color: A.textDim }}>{eps.length} episodes &middot; 4h 12m</div>
      </div>

      {/* Continue listening — featured card */}
      <div style={{ padding: '20px 20px 8px' }}>
        <div style={{ fontSize: 11, fontWeight: 600, color: A.textMuted, letterSpacing: '0.12em', textTransform: 'uppercase', marginBottom: 10 }}>Continue</div>
        <ContinueCardA ep={eps[4]} accent={accent} />
      </div>

      {/* Up Next list */}
      <div style={{ padding: '14px 20px 0' }}>
        <div style={{ fontSize: 11, fontWeight: 600, color: A.textMuted, letterSpacing: '0.12em', textTransform: 'uppercase', marginBottom: 6 }}>Up Next</div>
      </div>
      <div>
        {eps.slice(0, 4).map(ep => <EpisodeRowA key={ep.id} ep={ep} accent={accent} />)}
      </div>

      <MiniPlayerA ep={eps[4]} accent={accent} />
    </div>
  );
}

const iconBtnA = {
  width: 34, height: 34, borderRadius: 999, border: 'none',
  background: A.surface, color: A.text,
  display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
};

function ContinueCardA({ ep, accent }) {
  const show = window.SHOW_BY_ID[ep.show];
  const pct = ((ep.total - ep.mins) / ep.total) * 100;
  return (
    <div style={{
      background: A.surface, borderRadius: 18, padding: 14,
      display: 'flex', gap: 14, alignItems: 'center',
      boxShadow: '0 1px 0 rgba(255,255,255,0.04) inset',
    }}>
      <window.FallbackArt show={show} size={64} radius={12} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 11, color: accent, fontWeight: 600, letterSpacing: '0.06em' }}>{show.title.toUpperCase()}</div>
        <div style={{ fontSize: 15, fontWeight: 600, marginTop: 2, lineHeight: 1.3, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{ep.title}</div>
        {/* progress */}
        <div style={{ marginTop: 10, display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{ flex: 1, height: 3, background: 'rgba(255,255,255,0.08)', borderRadius: 99, overflow: 'hidden' }}>
            <div style={{ width: `${pct}%`, height: '100%', background: accent, borderRadius: 99 }} />
          </div>
          <div style={{ fontSize: 11, color: A.textDim, fontVariantNumeric: 'tabular-nums' }}>{ep.total - ep.mins}m left</div>
        </div>
      </div>
      <button style={{
        width: 44, height: 44, borderRadius: 999, border: 'none',
        background: '#fff', color: '#000',
        display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
        flexShrink: 0,
      }}>{window.Icon.play(16, '#000')}</button>
    </div>
  );
}

function EpisodeRowA({ ep, accent }) {
  const show = window.SHOW_BY_ID[ep.show];
  const left = ep.played ? 0 : ep.total - ep.mins;
  return (
    <div style={{
      display: 'flex', gap: 12, alignItems: 'center',
      padding: '12px 20px',
      borderTop: `1px solid ${A.hairline}`,
    }}>
      <window.FallbackArt show={show} size={44} radius={9} variant="duotone" />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <span style={{ fontSize: 11, color: A.textMuted }}>{ep.age}</span>
          {ep.played && <span style={{ color: A.textMuted, display: 'inline-flex' }}>{window.Icon.check(11, A.textMuted)}</span>}
        </div>
        <div style={{ fontSize: 14, fontWeight: 600, marginTop: 1, color: ep.played ? A.textDim : A.text, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{ep.title}</div>
        <div style={{ fontSize: 12, color: A.textMuted, marginTop: 1, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{ep.blurb}</div>
      </div>
      <PlayPucklA ep={ep} left={left} accent={accent} />
    </div>
  );
}

function PlayPucklA({ ep, left, accent }) {
  const inProgress = ep.mins > 0 && !ep.played;
  const pct = inProgress ? (ep.mins / ep.total) : 0;
  const r = 16, c = 2 * Math.PI * r;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4, width: 44 }}>
      <div style={{ position: 'relative', width: 36, height: 36 }}>
        <svg width="36" height="36" viewBox="0 0 36 36" style={{ position: 'absolute', inset: 0, transform: 'rotate(-90deg)' }}>
          <circle cx="18" cy="18" r={r} fill="none" stroke="rgba(255,255,255,0.1)" strokeWidth="1.5" />
          {inProgress && (
            <circle cx="18" cy="18" r={r} fill="none" stroke={accent} strokeWidth="1.5"
              strokeDasharray={c} strokeDashoffset={c * (1 - pct)} strokeLinecap="round" />
          )}
        </svg>
        <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          {ep.played ? window.Icon.resume(14, A.textDim) : window.Icon.play(13, A.text)}
        </div>
      </div>
      <div style={{ fontSize: 10, color: A.textMuted, fontVariantNumeric: 'tabular-nums' }}>
        {ep.played ? '0m' : `${left}m`}
      </div>
    </div>
  );
}

function MiniPlayerA({ ep, accent }) {
  const show = window.SHOW_BY_ID[ep.show];
  const pct = (ep.mins / ep.total) * 100;
  return (
    <div style={{
      position: 'absolute', left: 10, right: 10, bottom: 38,
      background: 'rgba(28,30,36,0.85)',
      backdropFilter: 'blur(20px) saturate(180%)',
      WebkitBackdropFilter: 'blur(20px) saturate(180%)',
      border: `1px solid ${A.hairline}`,
      borderRadius: 18, padding: 10,
      display: 'flex', gap: 10, alignItems: 'center',
      boxShadow: '0 8px 30px rgba(0,0,0,0.35)',
      overflow: 'hidden',
    }}>
      {/* progress sliver across the top */}
      <div style={{ position: 'absolute', left: 0, right: 0, top: 0, height: 2, background: 'rgba(255,255,255,0.06)' }}>
        <div style={{ width: `${pct}%`, height: '100%', background: accent }} />
      </div>
      <window.FallbackArt show={show} size={40} radius={8} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 13, fontWeight: 600, color: A.text, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{ep.title}</div>
        <div style={{ fontSize: 11, color: A.textDim, fontVariantNumeric: 'tabular-nums', marginTop: 1 }}>{show.title} &middot; {ep.total - ep.mins}m left</div>
      </div>
      <button style={{ width: 32, height: 32, border: 'none', background: 'transparent', color: A.text }}>{window.Icon.pause(18, A.text)}</button>
      <button style={{ width: 32, height: 32, border: 'none', background: 'transparent', color: A.text }}>{window.Icon.fwd30(22, A.text)}</button>
    </div>
  );
}

// ─── Show detail ────────────────────────────────────────────
function A_Show({ accent = A.accent }) {
  const show = window.SHOW_BY_ID['hard-fork'];
  const eps = window.EPISODES.filter(e => e.show === 'hard-fork').concat(window.EPISODES.slice(2));
  return (
    <div style={{ background: A.bg, minHeight: '100%', color: A.text, fontFamily: A.font, paddingBottom: 24 }}>
      {/* Sheet handle */}
      <div style={{ paddingTop: 56, display: 'flex', justifyContent: 'center' }}>
        <div style={{ width: 36, height: 4, borderRadius: 99, background: 'rgba(255,255,255,0.18)' }} />
      </div>
      {/* Hero */}
      <div style={{ padding: '20px 20px 0', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12 }}>
        <window.FallbackArt show={show} size={120} radius={20} />
        <div style={{ textAlign: 'center' }}>
          <div style={{ fontSize: 22, fontWeight: 700, letterSpacing: '-0.01em' }}>{show.title}</div>
          <div style={{ fontSize: 13, color: A.textDim, marginTop: 2 }}>{show.publisher}</div>
        </div>
        {/* Action row */}
        <div style={{ display: 'flex', gap: 10, marginTop: 6 }}>
          <button style={{
            background: accent, color: '#0B0B0E', border: 'none',
            padding: '10px 18px', borderRadius: 999, fontSize: 14, fontWeight: 600, fontFamily: A.font,
            display: 'inline-flex', alignItems: 'center', gap: 8,
          }}>{window.Icon.play(13, '#0B0B0E')} Play latest</button>
          <button style={{
            background: A.surface, color: A.text, border: 'none',
            padding: '10px 16px', borderRadius: 999, fontSize: 14, fontWeight: 500, fontFamily: A.font,
            display: 'inline-flex', alignItems: 'center', gap: 6,
          }}>{window.Icon.check(13, A.text)} Following</button>
          <button style={{ ...iconBtnA, width: 38, height: 38 }}>{window.Icon.more(18, A.text)}</button>
        </div>
      </div>
      {/* Tabs */}
      <div style={{ display: 'flex', gap: 24, padding: '24px 20px 4px', borderBottom: `1px solid ${A.hairline}` }}>
        {[['Episodes', true], ['About', false], ['Bookmarks', false]].map(([t, on]) => (
          <div key={t} style={{
            fontSize: 14, fontWeight: 600, paddingBottom: 10,
            color: on ? A.text : A.textMuted,
            borderBottom: on ? `2px solid ${accent}` : '2px solid transparent',
            marginBottom: -1,
          }}>{t}</div>
        ))}
      </div>
      {eps.slice(0, 7).map((ep, i) => <EpisodeRowA key={ep.id + 'a' + i} ep={ep} accent={accent} />)}
    </div>
  );
}

// ─── Now Playing ────────────────────────────────────────────
function A_NowPlaying({ accent = A.accent }) {
  const ep = window.EPISODES[0];
  const show = window.SHOW_BY_ID[ep.show];
  return (
    <div style={{ background: A.bg, minHeight: '100%', color: A.text, fontFamily: A.font, position: 'relative', overflow: 'hidden' }}>
      {/* Ambient glow from artwork */}
      <div style={{
        position: 'absolute', top: -120, left: '50%', transform: 'translateX(-50%)',
        width: 460, height: 460, borderRadius: '50%',
        background: `radial-gradient(circle, oklch(0.55 ${show.chroma} ${show.hue} / 0.45) 0%, transparent 65%)`,
        filter: 'blur(50px)', pointerEvents: 'none',
      }} />

      <div style={{ position: 'relative', paddingTop: 56, display: 'flex', justifyContent: 'center' }}>
        <div style={{ width: 36, height: 4, borderRadius: 99, background: 'rgba(255,255,255,0.18)' }} />
      </div>
      <div style={{ position: 'relative', padding: '12px 20px 0', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <button style={iconBtnA}>{window.Icon.chevronDown(18, A.text)}</button>
        <div style={{ fontSize: 11, color: A.textMuted, letterSpacing: '0.14em', textTransform: 'uppercase', fontWeight: 600 }}>Now Playing</div>
        <button style={iconBtnA}>{window.Icon.more(18, A.text)}</button>
      </div>

      {/* Artwork */}
      <div style={{ position: 'relative', display: 'flex', justifyContent: 'center', padding: '36px 20px 24px' }}>
        <window.FallbackArt show={show} size={290} radius={22}
          style={{ boxShadow: '0 30px 80px rgba(0,0,0,0.55), 0 0 0 1px rgba(255,255,255,0.05)' }}/>
      </div>

      {/* Title + show */}
      <div style={{ position: 'relative', padding: '0 24px', textAlign: 'center' }}>
        <div style={{ fontSize: 11, color: accent, fontWeight: 600, letterSpacing: '0.14em', textTransform: 'uppercase' }}>{show.title}</div>
        <div style={{ fontSize: 19, fontWeight: 700, marginTop: 6, letterSpacing: '-0.01em', textWrap: 'balance' }}>{ep.title}</div>
        <div style={{ fontSize: 12, color: A.textDim, marginTop: 4 }}>{show.publisher} &middot; Ep 142</div>
      </div>

      {/* Scrubber */}
      <div style={{ position: 'relative', padding: '24px 26px 8px' }}>
        <div style={{ height: 38, position: 'relative' }}>
          <window.Waveform bars={48} height={38} color={accent} opacity={0.35} animate={false} />
          {/* played overlay */}
          <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: '32%', overflow: 'hidden' }}>
            <window.Waveform bars={48} height={38} color={accent} opacity={1} />
          </div>
          {/* playhead */}
          <div style={{ position: 'absolute', left: '32%', top: -4, bottom: -4, width: 2, background: accent, borderRadius: 99 }} />
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8, fontSize: 11, color: A.textDim, fontVariantNumeric: 'tabular-nums' }}>
          <span>19:44</span><span>-42:16</span>
        </div>
      </div>

      {/* Transport */}
      <div style={{ position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 28, padding: '10px 0 18px' }}>
        <button style={transportBtn}>{window.Icon.back15(30, A.text)}</button>
        <button style={{
          width: 72, height: 72, borderRadius: 999, border: 'none', background: '#fff', color: '#000',
          display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
          boxShadow: '0 6px 20px rgba(0,0,0,0.4)',
        }}>{window.Icon.pause(28, '#000')}</button>
        <button style={transportBtn}>{window.Icon.fwd30(30, A.text)}</button>
      </div>

      {/* Bottom row */}
      <div style={{ position: 'relative', display: 'flex', justifyContent: 'space-around', padding: '8px 28px 24px', color: A.textDim }}>
        <button style={bottomBtn}>{window.Icon.speed(18, A.textDim)}<span style={{ fontSize: 10, marginTop: 3, fontWeight: 600 }}>1.2&times;</span></button>
        <button style={bottomBtn}>{window.Icon.sleep(18, A.textDim)}<span style={{ fontSize: 10, marginTop: 3 }}>Sleep</span></button>
        <button style={bottomBtn}>{window.Icon.airplay(18, A.textDim)}<span style={{ fontSize: 10, marginTop: 3 }}>AirPlay</span></button>
        <button style={bottomBtn}>{window.Icon.queue(18, A.textDim)}<span style={{ fontSize: 10, marginTop: 3 }}>Queue</span></button>
        <button style={bottomBtn}>{window.Icon.share(18, A.textDim)}<span style={{ fontSize: 10, marginTop: 3 }}>Share</span></button>
      </div>
    </div>
  );
}

const transportBtn = {
  width: 56, height: 56, border: 'none', background: 'transparent', color: A.text,
  display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
};
const bottomBtn = {
  background: 'transparent', border: 'none', color: 'inherit',
  display: 'inline-flex', flexDirection: 'column', alignItems: 'center',
};

Object.assign(window, { A_Library, A_Show, A_NowPlaying, A_TOKENS: A });
