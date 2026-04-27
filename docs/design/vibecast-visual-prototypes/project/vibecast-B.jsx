// Direction B — Editorial
// Warm cream/paper feel, Fraunces serif for titles, mono accents for metadata.
// Light by default. Show artwork is a flat color block + numeric mark.

const B = {
  bg: '#F4EFE6',
  paper: '#FBF7EE',
  ink: '#1A1714',
  inkDim: 'rgba(26,23,20,0.62)',
  inkMuted: 'rgba(26,23,20,0.40)',
  hairline: 'rgba(26,23,20,0.10)',
  accent: 'oklch(0.55 0.16 30)',  // terracotta
  serif: '"Fraunces", "Times New Roman", Georgia, serif',
  sans: '"Inter", -apple-system, system-ui, sans-serif',
  mono: '"JetBrains Mono", "SF Mono", ui-monospace, monospace',
};

function B_Library({ accent = B.accent }) {
  const eps = window.EPISODES.slice(0, 6);
  return (
    <div style={{ background: B.bg, minHeight: '100%', color: B.ink, fontFamily: B.sans, paddingBottom: 96 }}>
      {/* masthead */}
      <div style={{ padding: '60px 22px 0', borderBottom: `1px solid ${B.hairline}` }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div style={{ fontSize: 10, fontFamily: B.mono, letterSpacing: '0.18em', textTransform: 'uppercase', color: B.inkMuted }}>VOL. 12 &middot; APR 24</div>
          <div style={{ display: 'flex', gap: 14 }}>
            <button style={iconBtnB}>{window.Icon.search(17, B.ink)}</button>
            <button style={iconBtnB}>{window.Icon.plus(17, B.ink)}</button>
          </div>
        </div>
        <h1 style={{
          fontFamily: B.serif, fontSize: 56, fontWeight: 500,
          letterSpacing: '-0.025em', margin: '12px 0 6px',
          fontVariationSettings: '"opsz" 144, "SOFT" 30',
        }}>Vibecast</h1>
        <div style={{ display: 'flex', justifyContent: 'space-between', paddingBottom: 14 }}>
          <div style={{ fontFamily: B.serif, fontStyle: 'italic', fontSize: 14, color: B.inkDim }}>Listening, in good order</div>
          <div style={{ fontFamily: B.mono, fontSize: 11, color: B.inkMuted, letterSpacing: '0.06em' }}>06 EPS &middot; 04:12:00</div>
        </div>
      </div>

      {/* Lead story */}
      <div style={{ padding: '20px 22px 4px' }}>
        <SectionLabelB>Today</SectionLabelB>
        <LeadCardB ep={eps[4]} accent={accent} />
      </div>

      <div style={{ padding: '20px 22px 4px' }}>
        <SectionLabelB>In your queue</SectionLabelB>
      </div>
      {eps.slice(0, 4).map((ep, i) => <EpisodeRowB key={ep.id} ep={ep} idx={i + 1} accent={accent} />)}

      <MiniPlayerB ep={eps[4]} accent={accent} />
    </div>
  );
}

const iconBtnB = {
  width: 36, height: 36, borderRadius: 999, border: `1px solid ${B.hairline}`,
  background: B.paper, color: B.ink, display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
};

function SectionLabelB({ children }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10, margin: '0 0 14px' }}>
      <div style={{ fontFamily: B.mono, fontSize: 10, letterSpacing: '0.18em', textTransform: 'uppercase', color: B.inkDim, fontWeight: 600 }}>{children}</div>
      <div style={{ flex: 1, height: 1, background: B.hairline }} />
    </div>
  );
}

function LeadCardB({ ep, accent }) {
  const show = window.SHOW_BY_ID[ep.show];
  const pct = ((ep.total - ep.mins) / ep.total) * 100;
  return (
    <div style={{ background: B.paper, border: `1px solid ${B.hairline}`, borderRadius: 14, padding: 16 }}>
      <div style={{ display: 'flex', gap: 14 }}>
        <window.FallbackArt show={show} size={82} radius={6} variant="flat" />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontFamily: B.mono, fontSize: 10, letterSpacing: '0.12em', textTransform: 'uppercase', color: accent, fontWeight: 600 }}>{show.title}</div>
          <div style={{ fontFamily: B.serif, fontSize: 19, fontWeight: 500, lineHeight: 1.2, marginTop: 4, letterSpacing: '-0.01em' }}>{ep.title}</div>
          <div style={{ fontSize: 12, color: B.inkDim, marginTop: 4, lineHeight: 1.4 }}>{ep.blurb}</div>
        </div>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginTop: 14 }}>
        <button style={{
          background: B.ink, color: B.paper, border: 'none',
          padding: '8px 14px', borderRadius: 999, fontSize: 13, fontWeight: 600,
          display: 'inline-flex', alignItems: 'center', gap: 7, fontFamily: B.sans,
        }}>{window.Icon.play(11, B.paper)} Resume</button>
        <div style={{ flex: 1, height: 2, background: B.hairline, borderRadius: 99 }}>
          <div style={{ width: `${pct}%`, height: '100%', background: accent, borderRadius: 99 }} />
        </div>
        <div style={{ fontFamily: B.mono, fontSize: 10, color: B.inkMuted, letterSpacing: '0.06em' }}>{ep.total - ep.mins}M LEFT</div>
      </div>
    </div>
  );
}

function EpisodeRowB({ ep, idx, accent }) {
  const show = window.SHOW_BY_ID[ep.show];
  const left = ep.played ? 0 : ep.total - ep.mins;
  return (
    <div style={{ display: 'flex', gap: 12, padding: '14px 22px', borderTop: `1px solid ${B.hairline}` }}>
      <div style={{ width: 24, fontFamily: B.mono, fontSize: 11, color: B.inkMuted, paddingTop: 2, fontVariantNumeric: 'tabular-nums' }}>
        {String(idx).padStart(2, '0')}
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontFamily: B.mono, fontSize: 10, letterSpacing: '0.1em', textTransform: 'uppercase', color: B.inkMuted }}>
          {show.title} &nbsp;&middot;&nbsp; {ep.age}
        </div>
        <div style={{ fontFamily: B.serif, fontSize: 16, fontWeight: 500, lineHeight: 1.25, marginTop: 2, color: ep.played ? B.inkDim : B.ink, letterSpacing: '-0.005em' }}>
          {ep.title}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 6 }}>
          <div style={{ fontFamily: B.mono, fontSize: 10, color: B.inkMuted, letterSpacing: '0.04em' }}>
            {ep.played ? 'PLAYED' : (ep.mins > 0 ? `${left}M LEFT` : `${ep.total} MIN`)}
          </div>
          {ep.mins > 0 && !ep.played && (
            <div style={{ flex: 1, maxWidth: 60, height: 2, background: B.hairline }}>
              <div style={{ width: `${(ep.mins / ep.total) * 100}%`, height: '100%', background: accent }} />
            </div>
          )}
        </div>
      </div>
      <button style={{
        width: 34, height: 34, borderRadius: 999, border: `1px solid ${B.hairline}`,
        background: B.paper, color: B.ink, alignSelf: 'flex-start', marginTop: 2,
        display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
      }}>{ep.played ? window.Icon.resume(13, B.inkDim) : window.Icon.play(11, B.ink)}</button>
    </div>
  );
}

function MiniPlayerB({ ep, accent }) {
  const show = window.SHOW_BY_ID[ep.show];
  return (
    <div style={{
      position: 'absolute', left: 12, right: 12, bottom: 38,
      background: B.ink, color: B.paper,
      borderRadius: 14, padding: 10,
      display: 'flex', gap: 10, alignItems: 'center',
      boxShadow: '0 10px 30px rgba(0,0,0,0.18)',
      overflow: 'hidden', position: 'absolute',
    }}>
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, height: 2, background: 'rgba(255,255,255,0.08)' }}>
        <div style={{ width: `${(ep.mins / ep.total) * 100}%`, height: '100%', background: accent }} />
      </div>
      <window.FallbackArt show={show} size={40} radius={4} variant="flat" />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontFamily: B.serif, fontSize: 14, fontWeight: 500, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', letterSpacing: '-0.01em' }}>{ep.title}</div>
        <div style={{ fontFamily: B.mono, fontSize: 10, color: 'rgba(251,247,238,0.6)', letterSpacing: '0.08em', textTransform: 'uppercase', marginTop: 1 }}>
          {show.title} &middot; {ep.total - ep.mins}M
        </div>
      </div>
      <button style={{ width: 32, height: 32, border: 'none', background: 'transparent', color: B.paper }}>{window.Icon.pause(18, B.paper)}</button>
    </div>
  );
}

function B_Show({ accent = B.accent }) {
  const show = window.SHOW_BY_ID['hard-fork'];
  const eps = window.EPISODES.filter(e => e.show === 'hard-fork').concat(window.EPISODES.slice(2));
  return (
    <div style={{ background: B.bg, minHeight: '100%', color: B.ink, fontFamily: B.sans, paddingBottom: 24 }}>
      <div style={{ paddingTop: 56, display: 'flex', justifyContent: 'center' }}>
        <div style={{ width: 36, height: 4, borderRadius: 99, background: 'rgba(26,23,20,0.20)' }} />
      </div>
      <div style={{ padding: '20px 22px 0' }}>
        <div style={{ fontFamily: B.mono, fontSize: 10, letterSpacing: '0.18em', textTransform: 'uppercase', color: B.inkMuted, fontWeight: 600 }}>SHOW</div>
        <div style={{ display: 'flex', gap: 14, alignItems: 'flex-end', marginTop: 10, paddingBottom: 16, borderBottom: `1px solid ${B.hairline}` }}>
          <window.FallbackArt show={show} size={88} radius={6} variant="flat" />
          <div style={{ flex: 1, minWidth: 0, paddingBottom: 4 }}>
            <h2 style={{ fontFamily: B.serif, fontSize: 30, fontWeight: 500, letterSpacing: '-0.02em', margin: 0, lineHeight: 1 }}>{show.title}</h2>
            <div style={{ fontFamily: B.serif, fontStyle: 'italic', fontSize: 13, color: B.inkDim, marginTop: 4 }}>by {show.publisher}</div>
          </div>
        </div>
      </div>
      <div style={{ padding: '14px 22px', display: 'flex', gap: 10 }}>
        <button style={{
          flex: 1, background: B.ink, color: B.paper, border: 'none',
          padding: '11px 14px', borderRadius: 999, fontSize: 14, fontWeight: 600,
          display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 8, fontFamily: B.sans,
        }}>{window.Icon.play(13, B.paper)} Play latest</button>
        <button style={{
          background: B.paper, color: B.ink, border: `1px solid ${B.hairline}`,
          padding: '11px 16px', borderRadius: 999, fontSize: 14, fontWeight: 500, fontFamily: B.sans,
          display: 'inline-flex', alignItems: 'center', gap: 7,
        }}>{window.Icon.check(13, B.ink)} Following</button>
      </div>
      <div style={{ padding: '8px 22px 0' }}>
        <SectionLabelB>Episodes &mdash; 142</SectionLabelB>
      </div>
      {eps.slice(0, 7).map((ep, i) => <EpisodeRowB key={ep.id + 'b' + i} ep={ep} idx={i + 1} accent={accent} />)}
    </div>
  );
}

function B_NowPlaying({ accent = B.accent }) {
  const ep = window.EPISODES[0];
  const show = window.SHOW_BY_ID[ep.show];
  const pct = 32;
  return (
    <div style={{ background: B.paper, minHeight: '100%', color: B.ink, fontFamily: B.sans, position: 'relative', overflow: 'hidden' }}>
      <div style={{ paddingTop: 56, display: 'flex', justifyContent: 'center' }}>
        <div style={{ width: 36, height: 4, borderRadius: 99, background: 'rgba(26,23,20,0.20)' }} />
      </div>
      <div style={{ padding: '12px 22px 0', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <button style={iconBtnB}>{window.Icon.chevronDown(18, B.ink)}</button>
        <div style={{ fontFamily: B.mono, fontSize: 10, color: B.inkMuted, letterSpacing: '0.18em', textTransform: 'uppercase', fontWeight: 600 }}>Issue 142 &middot; Now Playing</div>
        <button style={iconBtnB}>{window.Icon.more(17, B.ink)}</button>
      </div>

      {/* Editorial-style spread */}
      <div style={{ padding: '32px 28px 16px' }}>
        <div style={{ fontFamily: B.mono, fontSize: 10, color: accent, letterSpacing: '0.16em', textTransform: 'uppercase', fontWeight: 700 }}>
          {show.title} &nbsp;&middot;&nbsp; {ep.age}
        </div>
        <h2 style={{
          fontFamily: B.serif, fontSize: 32, fontWeight: 500,
          lineHeight: 1.05, letterSpacing: '-0.025em', margin: '14px 0 12px',
          textWrap: 'balance',
        }}>
          {ep.title}
        </h2>
        <div style={{ fontFamily: B.serif, fontStyle: 'italic', fontSize: 15, color: B.inkDim, lineHeight: 1.45 }}>
          {ep.blurb}
        </div>
      </div>

      <div style={{ padding: '8px 28px 0', display: 'flex', alignItems: 'center', gap: 14 }}>
        <window.FallbackArt show={show} size={64} radius={4} variant="flat" />
        <div style={{ flex: 1 }}>
          <div style={{ fontFamily: B.mono, fontSize: 10, color: B.inkMuted, letterSpacing: '0.1em' }}>HOSTED BY</div>
          <div style={{ fontFamily: B.serif, fontSize: 14, marginTop: 2 }}>Kevin Roose &middot; Casey Newton</div>
        </div>
      </div>

      {/* Scrubber */}
      <div style={{ padding: '28px 28px 6px' }}>
        <div style={{ position: 'relative', height: 4, background: 'rgba(26,23,20,0.10)', borderRadius: 99 }}>
          <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: `${pct}%`, background: B.ink, borderRadius: 99 }} />
          <div style={{ position: 'absolute', left: `${pct}%`, top: '50%', transform: 'translate(-50%, -50%)', width: 14, height: 14, borderRadius: 99, background: B.ink, border: `2px solid ${B.paper}`, boxShadow: '0 1px 3px rgba(0,0,0,0.2)' }} />
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 10, fontFamily: B.mono, fontSize: 11, color: B.inkMuted, letterSpacing: '0.06em' }}>
          <span>00:19:44</span><span>-00:42:16</span>
        </div>
      </div>

      {/* Transport */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 30, padding: '14px 0 10px' }}>
        <button style={{ ...transportBtnB }}>{window.Icon.back15(28, B.ink)}</button>
        <button style={{
          width: 70, height: 70, borderRadius: 999, border: 'none', background: B.ink, color: B.paper,
          display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
          boxShadow: '0 6px 16px rgba(0,0,0,0.2)',
        }}>{window.Icon.pause(28, B.paper)}</button>
        <button style={{ ...transportBtnB }}>{window.Icon.fwd30(28, B.ink)}</button>
      </div>

      {/* Speed pill row */}
      <div style={{ display: 'flex', justifyContent: 'center', gap: 8, paddingTop: 12 }}>
        {['0.8×', '1×', '1.2×', '1.5×', '2×'].map((s, i) => (
          <div key={s} style={{
            fontFamily: B.mono, fontSize: 11, fontWeight: 600,
            padding: '6px 10px', borderRadius: 999,
            background: i === 2 ? B.ink : 'transparent',
            color: i === 2 ? B.paper : B.inkDim,
            border: i === 2 ? 'none' : `1px solid ${B.hairline}`,
            letterSpacing: '0.04em',
          }}>{s}</div>
        ))}
      </div>

      <div style={{ display: 'flex', justifyContent: 'space-around', padding: '20px 28px 24px' }}>
        <button style={bottomBtnB}>{window.Icon.sleep(18, B.inkDim)}<span style={mb}>Sleep</span></button>
        <button style={bottomBtnB}>{window.Icon.airplay(18, B.inkDim)}<span style={mb}>AirPlay</span></button>
        <button style={bottomBtnB}>{window.Icon.queue(18, B.inkDim)}<span style={mb}>Queue</span></button>
        <button style={bottomBtnB}>{window.Icon.share(18, B.inkDim)}<span style={mb}>Share</span></button>
      </div>
    </div>
  );
}

const transportBtnB = {
  width: 56, height: 56, border: 'none', background: 'transparent', color: B.ink,
  display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
};
const bottomBtnB = {
  background: 'transparent', border: 'none',
  display: 'inline-flex', flexDirection: 'column', alignItems: 'center', color: B.inkDim,
};
const mb = { fontFamily: B.mono, fontSize: 9, marginTop: 4, letterSpacing: '0.1em', textTransform: 'uppercase' };

Object.assign(window, { B_Library, B_Show, B_NowPlaying, B_TOKENS: B });
