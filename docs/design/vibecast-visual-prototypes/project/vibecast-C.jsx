// Direction C — Expressive
// Bold display type, full-bleed artwork-driven color, big motion energy.
// Each show "owns" the screen via its hue.

const C = {
  bg: '#0A0A0B',
  surface: 'rgba(255,255,255,0.05)',
  surface2: 'rgba(255,255,255,0.08)',
  hairline: 'rgba(255,255,255,0.10)',
  text: '#FAFAFA',
  textDim: 'rgba(250,250,250,0.65)',
  textMuted: 'rgba(250,250,250,0.42)',
  font: '"Inter", -apple-system, system-ui, sans-serif',
  display: '"Inter", -apple-system, system-ui, sans-serif',
};

function showAccent(show, l = 0.72) {
  return `oklch(${l} ${show.chroma} ${show.hue})`;
}

function C_Library() {
  const eps = window.EPISODES.slice(0, 6);
  const featured = eps[4];
  const fShow = window.SHOW_BY_ID[featured.show];
  return (
    <div style={{ background: C.bg, minHeight: '100%', color: C.text, fontFamily: C.font, paddingBottom: 96, position: 'relative' }}>
      {/* Top */}
      <div style={{ padding: '60px 18px 0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div style={{ width: 36, height: 36, borderRadius: 10, background: showAccent(window.SHOWS[0], 0.6), display: 'inline-flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800, fontSize: 16 }}>V</div>
        <div style={{ display: 'flex', gap: 8 }}>
          <button style={iconBtnC}>{window.Icon.search(18, C.text)}</button>
          <button style={iconBtnC}>{window.Icon.plus(18, C.text)}</button>
        </div>
      </div>
      <div style={{ padding: '20px 18px 4px' }}>
        <h1 style={{
          fontSize: 56, fontWeight: 800, letterSpacing: '-0.045em',
          margin: 0, lineHeight: 0.92, textWrap: 'balance',
        }}>
          Today's<br/>queue.
        </h1>
        <div style={{ marginTop: 10, fontSize: 13, color: C.textDim, fontWeight: 500 }}>
          {eps.length} episodes &middot; about 4 hours
        </div>
      </div>

      {/* Hero */}
      <div style={{ padding: '20px 18px 4px' }}>
        <HeroCardC ep={featured} />
      </div>

      {/* Stack */}
      <div style={{ padding: '20px 18px 4px', display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
        <div style={{ fontSize: 14, fontWeight: 700, letterSpacing: '-0.01em' }}>Up next</div>
        <div style={{ fontSize: 12, color: C.textDim }}>Sort &middot; Newest</div>
      </div>
      <div style={{ padding: '0 12px', display: 'flex', flexDirection: 'column', gap: 8 }}>
        {eps.slice(0, 4).map(ep => <EpisodeRowC key={ep.id} ep={ep} />)}
      </div>

      <MiniPlayerC ep={featured} />
    </div>
  );
}

const iconBtnC = {
  width: 36, height: 36, borderRadius: 999, border: 'none',
  background: C.surface, color: C.text,
  display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
};

function HeroCardC({ ep }) {
  const show = window.SHOW_BY_ID[ep.show];
  const accent = showAccent(show, 0.62);
  const accentLite = showAccent(show, 0.78);
  const pct = ((ep.total - ep.mins) / ep.total) * 100;
  return (
    <div style={{
      borderRadius: 22, padding: 18, position: 'relative', overflow: 'hidden',
      background: `linear-gradient(135deg, ${accent} 0%, oklch(0.32 ${show.chroma * 0.8} ${(show.hue + 30) % 360}) 100%)`,
      minHeight: 200,
    }}>
      {/* texture / grain */}
      <div style={{ position: 'absolute', inset: 0, background: 'radial-gradient(circle at 80% 20%, rgba(255,255,255,0.18), transparent 50%)' }} />
      <div style={{ position: 'relative', display: 'flex', justifyContent: 'space-between' }}>
        <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '0.14em', textTransform: 'uppercase', color: 'rgba(255,255,255,0.85)' }}>
          Continue &middot; {ep.total - ep.mins}m left
        </div>
        <div style={{ fontSize: 11, fontWeight: 600, color: 'rgba(255,255,255,0.7)', display: 'inline-flex', alignItems: 'center', gap: 6 }}>
          <span style={{ width: 6, height: 6, borderRadius: 99, background: '#fff', animation: 'vb-pulse 1.6s ease-in-out infinite' }} />
          {show.title}
        </div>
      </div>
      <div style={{
        position: 'relative', marginTop: 22, fontSize: 28, fontWeight: 700,
        letterSpacing: '-0.025em', lineHeight: 1.05, textWrap: 'balance', color: '#fff',
      }}>{ep.title}</div>
      <div style={{ position: 'relative', marginTop: 14, height: 28 }}>
        <window.Waveform bars={42} height={28} color="rgba(255,255,255,0.35)" animate={false} />
        <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: `${pct}%`, overflow: 'hidden' }}>
          <window.Waveform bars={42} height={28} color="#fff" />
        </div>
      </div>
      <div style={{ position: 'relative', display: 'flex', alignItems: 'center', gap: 10, marginTop: 14 }}>
        <button style={{
          background: '#fff', color: '#000', border: 'none',
          padding: '10px 16px', borderRadius: 999, fontSize: 14, fontWeight: 700,
          display: 'inline-flex', alignItems: 'center', gap: 7, fontFamily: C.font,
        }}>{window.Icon.play(13, '#000')} Resume</button>
        <button style={{
          background: 'rgba(255,255,255,0.18)', color: '#fff', border: 'none',
          padding: '10px 14px', borderRadius: 999, fontSize: 13, fontWeight: 600, fontFamily: C.font,
          display: 'inline-flex', alignItems: 'center', gap: 6,
          backdropFilter: 'blur(10px)',
        }}>{window.Icon.queue(14, '#fff')} Queue</button>
      </div>
    </div>
  );
}

function EpisodeRowC({ ep }) {
  const show = window.SHOW_BY_ID[ep.show];
  const accent = showAccent(show, 0.7);
  const left = ep.played ? 0 : ep.total - ep.mins;
  const inProgress = ep.mins > 0 && !ep.played;
  return (
    <div style={{
      display: 'flex', gap: 12, alignItems: 'center', padding: 10,
      background: C.surface, borderRadius: 14,
      border: `1px solid ${C.hairline}`,
    }}>
      <div style={{ position: 'relative' }}>
        <window.FallbackArt show={show} size={56} radius={10} />
        {inProgress && (
          <div style={{
            position: 'absolute', inset: 0, borderRadius: 10,
            boxShadow: `inset 0 0 0 2px ${accent}`,
          }} />
        )}
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{ fontSize: 11, fontWeight: 700, color: accent, letterSpacing: '0.06em', textTransform: 'uppercase' }}>{show.title}</span>
          <span style={{ fontSize: 11, color: C.textMuted }}>&middot; {ep.age}</span>
        </div>
        <div style={{ fontSize: 14, fontWeight: 600, marginTop: 2, color: ep.played ? C.textDim : C.text, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', letterSpacing: '-0.005em' }}>{ep.title}</div>
        <div style={{ fontSize: 11, color: C.textMuted, marginTop: 2, fontVariantNumeric: 'tabular-nums' }}>
          {ep.played ? 'Played' : (inProgress ? `${left}m left` : `${ep.total} min`)}
        </div>
      </div>
      <button style={{
        width: 38, height: 38, borderRadius: 999, border: 'none',
        background: ep.played ? 'transparent' : '#fff', color: ep.played ? C.textDim : '#000',
        display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
      }}>{ep.played ? window.Icon.resume(15, C.textDim) : window.Icon.play(13, '#000')}</button>
    </div>
  );
}

function MiniPlayerC({ ep }) {
  const show = window.SHOW_BY_ID[ep.show];
  const accent = showAccent(show, 0.62);
  return (
    <div style={{
      position: 'absolute', left: 12, right: 12, bottom: 38,
      borderRadius: 18, padding: 10, overflow: 'hidden',
      background: 'rgba(255,255,255,0.06)',
      backdropFilter: 'blur(24px) saturate(180%)',
      WebkitBackdropFilter: 'blur(24px) saturate(180%)',
      border: `1px solid ${C.hairline}`,
      display: 'flex', gap: 10, alignItems: 'center',
    }}>
      {/* glow */}
      <div style={{ position: 'absolute', left: -30, top: -30, width: 100, height: 100, borderRadius: '50%', background: accent, filter: 'blur(40px)', opacity: 0.5 }} />
      <window.FallbackArt show={show} size={40} radius={8} style={{ position: 'relative' }} />
      <div style={{ flex: 1, minWidth: 0, position: 'relative' }}>
        <div style={{ fontSize: 13, fontWeight: 600, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{ep.title}</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 4 }}>
          <div style={{ width: 14, height: 10, display: 'flex', gap: 1.5, alignItems: 'flex-end' }}>
            {[0.5, 0.9, 0.4, 0.7].map((h, i) => (
              <div key={i} style={{ flex: 1, background: accent, borderRadius: 1, animation: `vb-bar ${0.6 + i * 0.1}s ease-in-out ${i * 0.05}s infinite alternate`, height: `${h * 100}%` }} />
            ))}
          </div>
          <span style={{ fontSize: 11, color: C.textDim }}>{show.title} &middot; {ep.total - ep.mins}m</span>
        </div>
      </div>
      <button style={{ width: 34, height: 34, border: 'none', background: 'transparent', color: C.text, position: 'relative' }}>{window.Icon.pause(20, C.text)}</button>
    </div>
  );
}

function C_Show() {
  const show = window.SHOW_BY_ID['hard-fork'];
  const eps = window.EPISODES.filter(e => e.show === 'hard-fork').concat(window.EPISODES.slice(2));
  const accent = showAccent(show, 0.62);
  const accentDeep = `oklch(0.28 ${show.chroma * 0.8} ${show.hue})`;
  return (
    <div style={{ background: C.bg, minHeight: '100%', color: C.text, fontFamily: C.font, paddingBottom: 24, position: 'relative', overflow: 'hidden' }}>
      {/* Color slab top */}
      <div style={{
        position: 'absolute', top: 0, left: 0, right: 0, height: 320,
        background: `linear-gradient(180deg, ${accent} 0%, ${accentDeep} 60%, ${C.bg} 100%)`,
      }} />
      <div style={{ position: 'relative', paddingTop: 56, display: 'flex', justifyContent: 'center' }}>
        <div style={{ width: 36, height: 4, borderRadius: 99, background: 'rgba(255,255,255,0.4)' }} />
      </div>
      <div style={{ position: 'relative', padding: '20px 20px 0', display: 'flex', alignItems: 'flex-end', gap: 14 }}>
        <window.FallbackArt show={show} size={100} radius={16} style={{ boxShadow: '0 18px 40px rgba(0,0,0,0.5)' }} />
        <div style={{ paddingBottom: 6 }}>
          <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '0.14em', textTransform: 'uppercase', opacity: 0.85 }}>Podcast</div>
          <div style={{ fontSize: 30, fontWeight: 800, letterSpacing: '-0.03em', lineHeight: 1, marginTop: 4 }}>{show.title}</div>
          <div style={{ fontSize: 12, opacity: 0.85, marginTop: 4 }}>{show.publisher} &middot; 142 eps</div>
        </div>
      </div>
      <div style={{ position: 'relative', padding: '24px 20px 8px', display: 'flex', gap: 10 }}>
        <button style={{
          flex: 1, background: '#fff', color: '#000', border: 'none',
          padding: '12px 14px', borderRadius: 999, fontSize: 14, fontWeight: 700, fontFamily: C.font,
          display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 8,
        }}>{window.Icon.play(13, '#000')} Play latest</button>
        <button style={{
          background: C.surface2, color: C.text, border: 'none',
          padding: '12px 16px', borderRadius: 999, fontSize: 14, fontWeight: 600, fontFamily: C.font,
          display: 'inline-flex', alignItems: 'center', gap: 7,
        }}>{window.Icon.check(13, C.text)} Following</button>
      </div>
      <div style={{ position: 'relative', padding: '4px 20px 12px', fontSize: 13, color: C.textDim, lineHeight: 1.45, textWrap: 'pretty' }}>
        Kevin Roose & Casey Newton dissect the people, power, and money shaping our future.
      </div>
      <div style={{ position: 'relative', display: 'flex', gap: 8, padding: '8px 20px 14px' }}>
        {['All', 'Unplayed', 'Downloaded', 'Saved'].map((t, i) => (
          <div key={t} style={{
            fontSize: 12, fontWeight: 600, padding: '6px 12px', borderRadius: 999,
            background: i === 0 ? '#fff' : C.surface, color: i === 0 ? '#000' : C.text,
          }}>{t}</div>
        ))}
      </div>
      <div style={{ padding: '0 12px', display: 'flex', flexDirection: 'column', gap: 8 }}>
        {eps.slice(0, 6).map((ep, i) => <EpisodeRowC key={ep.id + 'c' + i} ep={ep} />)}
      </div>
    </div>
  );
}

function C_NowPlaying() {
  const ep = window.EPISODES[0];
  const show = window.SHOW_BY_ID[ep.show];
  const accent = showAccent(show, 0.65);
  const accentDeep = `oklch(0.22 ${show.chroma * 0.8} ${show.hue})`;
  return (
    <div style={{ background: C.bg, minHeight: '100%', color: C.text, fontFamily: C.font, position: 'relative', overflow: 'hidden' }}>
      {/* Full bleed gradient */}
      <div style={{
        position: 'absolute', inset: 0,
        background: `radial-gradient(120% 80% at 50% 0%, ${accent} 0%, ${accentDeep} 40%, ${C.bg} 80%)`,
      }} />
      {/* Animated noise grain hint */}
      <div style={{
        position: 'absolute', inset: 0, opacity: 0.5,
        background: 'radial-gradient(circle at 30% 30%, rgba(255,255,255,0.08), transparent 40%)',
      }} />

      <div style={{ position: 'relative', paddingTop: 56, display: 'flex', justifyContent: 'center' }}>
        <div style={{ width: 36, height: 4, borderRadius: 99, background: 'rgba(255,255,255,0.4)' }} />
      </div>
      <div style={{ position: 'relative', padding: '14px 20px 0', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <button style={iconBtnC}>{window.Icon.chevronDown(18, C.text)}</button>
        <div style={{ display: 'flex', gap: 6 }}>
          <span style={{ width: 6, height: 6, borderRadius: 99, background: '#fff', alignSelf: 'center', animation: 'vb-pulse 1.4s ease-in-out infinite' }} />
          <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '0.18em', textTransform: 'uppercase' }}>Live &middot; Ep 142</div>
        </div>
        <button style={iconBtnC}>{window.Icon.more(18, C.text)}</button>
      </div>

      {/* Big artwork */}
      <div style={{ position: 'relative', padding: '40px 20px 20px', display: 'flex', justifyContent: 'center' }}>
        <div style={{ position: 'relative' }}>
          <window.FallbackArt show={show} size={300} radius={28}
            style={{ boxShadow: `0 30px 80px rgba(0,0,0,0.5), 0 0 80px ${accent}40` }}/>
          {/* spinner badge */}
          <div style={{
            position: 'absolute', bottom: -8, right: -8,
            width: 44, height: 44, borderRadius: 999,
            background: '#fff', color: '#000',
            display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: '0 6px 16px rgba(0,0,0,0.3)',
          }}>{window.Icon.pause(20, '#000')}</div>
        </div>
      </div>

      <div style={{ position: 'relative', padding: '0 24px', textAlign: 'left' }}>
        <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '0.14em', textTransform: 'uppercase', color: 'rgba(255,255,255,0.85)' }}>{show.title}</div>
        <div style={{ fontSize: 26, fontWeight: 800, marginTop: 6, letterSpacing: '-0.025em', lineHeight: 1.08, textWrap: 'balance' }}>{ep.title}</div>
      </div>

      {/* Animated waveform scrubber */}
      <div style={{ position: 'relative', padding: '24px 24px 4px' }}>
        <div style={{ position: 'relative', height: 50 }}>
          <window.Waveform bars={50} height={50} color="rgba(255,255,255,0.30)" animate={false} />
          <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: '32%', overflow: 'hidden' }}>
            <window.Waveform bars={50} height={50} color="#fff" />
          </div>
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 10, fontSize: 11, color: 'rgba(255,255,255,0.7)', fontVariantNumeric: 'tabular-nums', fontWeight: 600 }}>
          <span>19:44</span><span>-42:16</span>
        </div>
      </div>

      {/* Transport */}
      <div style={{ position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '8px 36px 14px' }}>
        <button style={{ ...transportBtnC, color: 'rgba(255,255,255,0.85)' }}>{window.Icon.back15(28, 'rgba(255,255,255,0.85)')}</button>
        <button style={{
          fontSize: 14, fontWeight: 800, padding: '10px 14px', borderRadius: 999,
          background: 'rgba(255,255,255,0.18)', color: '#fff', border: 'none', fontFamily: C.font,
          backdropFilter: 'blur(10px)',
        }}>1.2&times;</button>
        <button style={{ ...transportBtnC, color: 'rgba(255,255,255,0.85)' }}>{window.Icon.fwd30(28, 'rgba(255,255,255,0.85)')}</button>
      </div>

      <div style={{ position: 'relative', display: 'flex', justifyContent: 'space-around', padding: '6px 28px 30px', color: 'rgba(255,255,255,0.7)' }}>
        <button style={bottomBtnC}>{window.Icon.sleep(18, 'rgba(255,255,255,0.7)')}<span style={{ fontSize: 10, marginTop: 4 }}>Sleep</span></button>
        <button style={bottomBtnC}>{window.Icon.airplay(18, 'rgba(255,255,255,0.7)')}<span style={{ fontSize: 10, marginTop: 4 }}>AirPlay</span></button>
        <button style={bottomBtnC}>{window.Icon.queue(18, 'rgba(255,255,255,0.7)')}<span style={{ fontSize: 10, marginTop: 4 }}>Queue</span></button>
        <button style={bottomBtnC}>{window.Icon.share(18, 'rgba(255,255,255,0.7)')}<span style={{ fontSize: 10, marginTop: 4 }}>Share</span></button>
      </div>
    </div>
  );
}

const transportBtnC = {
  width: 56, height: 56, border: 'none', background: 'transparent',
  display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
};
const bottomBtnC = {
  background: 'transparent', border: 'none', color: 'inherit',
  display: 'inline-flex', flexDirection: 'column', alignItems: 'center',
};

Object.assign(window, { C_Library, C_Show, C_NowPlaying, C_TOKENS: C });
