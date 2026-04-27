// Extra data for the podcast-detail + pinning exploration.
// Adds Blank Check (deep back catalog), an "On a plane" vibe,
// and a pinned-episode queue model.

const PLANE_PODS = [
  { id: 'blank-check',  title: 'Blank Check',           publisher: 'Wondery', hue: 24,  chroma: 0.16, vibes: ['plane'],
    latest: { title: 'Pirates of the Caribbean: At World\u2019s End', age: '3d ago', mins: 0, total: 142, blurb: 'The Mike & Griffin journey continues into the third Pirates film.' } },
  { id: 'rewatchables', title: 'The Rewatchables',      publisher: 'The Ringer', hue: 348, chroma: 0.16, vibes: ['plane', 'around'],
    latest: { title: 'Heat (1995)',                                age: '1w ago', mins: 0, total: 138, blurb: 'Bill, Sean, and Chris on the Michael Mann classic.' } },
  { id: 'conan',        title: 'Conan O\u2019Brien Needs a Friend', publisher: 'Team Coco', hue: 50, chroma: 0.16, vibes: ['plane'],
    latest: { title: 'Bill Hader',                                 age: '4d ago', mins: 0, total: 88,  blurb: 'Conan and Bill catch up about writing, Barry, and bad accents.' } },
];

// Back-catalog episodes for the podcasts we use in this exploration.
// Episodes are sorted newest -> oldest; mins=0 means unplayed (or partial via mins>0).
const BACK_CATALOG = {
  'blank-check': [
    { id: 'bc-pirates-3', title: 'Pirates of the Caribbean: At World\u2019s End', age: '3d ago',  total: 142, mins: 0, played: false, blurb: 'The Mike & Griffin journey continues into the third Pirates film.' },
    { id: 'bc-pirates-2', title: 'Pirates of the Caribbean: Dead Man\u2019s Chest', age: '1w ago', total: 128, mins: 0, played: false, blurb: 'Sequels, kraken, and Davy Jones.' },
    { id: 'bc-pirates-1', title: 'Pirates of the Caribbean: The Curse of the Black Pearl', age: '2w ago', total: 134, mins: 0, played: false, blurb: 'Where the Pirates miniseries began.' },
    { id: 'bc-shyamalan', title: 'Lady in the Water',         age: '3w ago', total: 156, mins: 0, played: true,  blurb: 'M. Night\u2019s most divisive miniseries entry.' },
    { id: 'bc-elf',       title: 'Elf (Holiday Special)',     age: '1mo ago', total: 96, mins: 0, played: true,  blurb: 'Holiday detour into the Will Ferrell canon.' },
    { id: 'bc-anchorman', title: 'Anchorman 2: The Legend Continues', age: '1mo ago', total: 121, mins: 0, played: true, blurb: 'Closing out the Adam McKay miniseries.' },
    { id: 'bc-anchor-1',  title: 'Anchorman: The Legend of Ron Burgundy', age: '2mo ago', total: 132, mins: 0, played: true, blurb: 'The Adam McKay miniseries kickoff.' },
  ],
  'rewatchables': [
    { id: 'rw-heat',      title: 'Heat (1995)',                age: '1w ago',  total: 138, mins: 0, played: false, blurb: 'Bill, Sean, and Chris on the Michael Mann classic.' },
    { id: 'rw-jaws',      title: 'Jaws',                       age: '2w ago',  total: 122, mins: 0, played: false, blurb: 'A summer essential rewatch.' },
    { id: 'rw-collateral',title: 'Collateral',                 age: '3w ago',  total: 118, mins: 0, played: true,  blurb: 'More Mann \u2014 LA at night, Cruise as villain.' },
    { id: 'rw-die-hard',  title: 'Die Hard',                   age: '1mo ago', total: 134, mins: 0, played: true,  blurb: 'A holiday classic.' },
    { id: 'rw-goodfellas',title: 'Goodfellas',                 age: '2mo ago', total: 145, mins: 0, played: true,  blurb: 'Scorsese essentials.' },
  ],
  'conan': [
    { id: 'co-hader',     title: 'Bill Hader',                 age: '4d ago',  total: 88,  mins: 0, played: false, blurb: 'Conan and Bill catch up about writing, Barry, and bad accents.' },
    { id: 'co-larry',     title: 'Larry David',                age: '2w ago',  total: 92,  mins: 0, played: false, blurb: 'Larry visits and complains about everything.' },
    { id: 'co-fey',       title: 'Tina Fey',                   age: '1mo ago', total: 84,  mins: 0, played: true,  blurb: 'On 30 Rock, SNL, and writing rooms.' },
    { id: 'co-rudd',      title: 'Paul Rudd',                  age: '2mo ago', total: 76,  mins: 0, played: true,  blurb: 'The annual Paul Rudd episode.' },
  ],
};

// The new vibe.
const PLANE_VIBE = {
  id: 'plane', name: 'On a plane', emoji: null,
  color: 'oklch(0.55 0.13 245)', chip: 'oklch(0.92 0.04 245)', ink: 'oklch(0.30 0.10 245)',
  icon: '✈',
};

// Vibe queue item kinds:
//   { kind: 'show',    podId }                                    \u2014 latest of show, refreshes over time
//   { kind: 'episode', podId, epId, pinnedAt }                    \u2014 specific pinned episode, expires when played
//
// On-a-plane queue example: 3 podcasts, plus 3 specific Blank Check episodes pinned
// (older Pirates films in order), and one specific Rewatchables episode pinned.
const PLANE_QUEUE = [
  { kind: 'episode', podId: 'blank-check',  epId: 'bc-pirates-1', pinnedAt: '2d ago' },
  { kind: 'episode', podId: 'blank-check',  epId: 'bc-pirates-2', pinnedAt: '2d ago' },
  { kind: 'episode', podId: 'blank-check',  epId: 'bc-pirates-3', pinnedAt: '2d ago' },
  { kind: 'episode', podId: 'rewatchables', epId: 'rw-jaws',      pinnedAt: '1d ago' },
  { kind: 'show',    podId: 'conan' },
  { kind: 'show',    podId: 'rewatchables' },
];

// Resolve a queue item to a concrete row payload: { pod, ep, pinned }
function resolveQueueItem(item) {
  const pod = window.PODCAST_BY_ID[item.podId];
  if (item.kind === 'episode') {
    const ep = (BACK_CATALOG[item.podId] || []).find(e => e.id === item.epId) || pod.latest;
    return { pod, ep, pinned: true, pinnedAt: item.pinnedAt };
  }
  return { pod, ep: pod.latest, pinned: false };
}

// Register everything.
(function () {
  // Append plane podcasts to the global PODCAST table.
  PLANE_PODS.forEach(p => {
    if (!window.PODCAST_BY_ID[p.id]) {
      window.PODCASTS.push(p);
      window.PODCAST_BY_ID[p.id] = p;
    }
  });
  // Append the plane vibe.
  if (!window.VIBE_BY_ID['plane']) {
    window.VIBES.push(PLANE_VIBE);
    window.VIBE_BY_ID['plane'] = PLANE_VIBE;
  }
  // Plane vibe order is just the show ids, for compatibility with the simpler views.
  window.VIBE_ORDER['plane'] = ['blank-check', 'rewatchables', 'conan'];
})();

Object.assign(window, { BACK_CATALOG, PLANE_QUEUE, PLANE_VIBE, resolveQueueItem });
