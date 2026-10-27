// Procedural SVG cat portraits. mood: idle | happy | love | shock | sleepy | wow

let uid = 0;

function eyes(mood, color) {
  const L = 36, R = 64, Y = 58;
  switch (mood) {
    case 'happy':
      return `<path d="M${L - 7} ${Y + 2} Q${L} ${Y - 7} ${L + 7} ${Y + 2}" stroke="#2a1a1a" stroke-width="3.5" fill="none" stroke-linecap="round"/>
              <path d="M${R - 7} ${Y + 2} Q${R} ${Y - 7} ${R + 7} ${Y + 2}" stroke="#2a1a1a" stroke-width="3.5" fill="none" stroke-linecap="round"/>`;
    case 'love':
      return [L, R].map((x) => `<path d="M${x} ${Y + 6} l-7 -7 a4 4 0 0 1 7 -4 a4 4 0 0 1 7 4 z" fill="#ff3d7f"/>`).join('');
    case 'sleepy':
      return `<path d="M${L - 7} ${Y} Q${L} ${Y + 5} ${L + 7} ${Y}" stroke="#2a1a1a" stroke-width="3" fill="none" stroke-linecap="round"/>
              <path d="M${R - 7} ${Y} Q${R} ${Y + 5} ${R + 7} ${Y}" stroke="#2a1a1a" stroke-width="3" fill="none" stroke-linecap="round"/>`;
    case 'shock':
      return [L, R].map((x) => `<circle cx="${x}" cy="${Y}" r="9" fill="#fff" stroke="#2a1a1a" stroke-width="2"/><circle cx="${x}" cy="${Y}" r="2.6" fill="#2a1a1a"/>`).join('');
    case 'wow':
      return [L, R].map((x) => `<path d="M${x} ${Y - 9} l2.6 6 6.4 .6 -4.8 4.2 1.4 6.4 -5.6 -3.4 -5.6 3.4 1.4 -6.4 -4.8 -4.2 6.4 -.6z" fill="#ffd400" stroke="#b37a00" stroke-width="1"/>`).join('');
    default:
      return [L, R].map((x) => `<ellipse cx="${x}" cy="${Y}" rx="7.5" ry="8.5" fill="${color}"/>
        <ellipse cx="${x}" cy="${Y + 0.5}" rx="3.2" ry="6.5" fill="#15100f"/>
        <circle cx="${x + 2.6}" cy="${Y - 3.4}" r="2.4" fill="#fff"/>`).join('');
  }
}

function pattern(look, clip) {
  const { pattern: p, fur2 } = look;
  const g = (inner) => `<g clip-path="url(#${clip})">${inner}</g>`;
  switch (p) {
    case 'tabby':
      return g(`<path d="M50 28 v12 M42 30 l3 10 M58 30 l-3 10" stroke="${fur2}" stroke-width="3.2" stroke-linecap="round"/>
        <path d="M14 60 h10 M14 68 h9 M86 60 h-10 M86 68 h-9" stroke="${fur2}" stroke-width="3" stroke-linecap="round"/>`);
    case 'tiger':
      return g(`<path d="M50 26 v16 M40 28 l4 13 M60 28 l-4 13 M33 33 l6 10 M67 33 l-6 10" stroke="${fur2}" stroke-width="4" stroke-linecap="round"/>
        <path d="M12 56 l14 3 M12 66 l13 1 M88 56 l-14 3 M88 66 l-13 1" stroke="${fur2}" stroke-width="3.6" stroke-linecap="round"/>`);
    case 'tux':
      return g(`<path d="M50 52 C30 60 26 78 30 96 L70 96 C74 78 70 60 50 52Z" fill="${fur2}"/>`);
    case 'calico':
      return g(`<ellipse cx="30" cy="38" rx="17" ry="14" fill="${fur2}"/><ellipse cx="72" cy="44" rx="13" ry="12" fill="#2f2a2a"/><ellipse cx="78" cy="80" rx="10" ry="8" fill="${fur2}"/>`);
    case 'siamese':
      return g(`<ellipse cx="50" cy="74" rx="20" ry="16" fill="${fur2}" opacity=".85"/>`);
    case 'spots':
      return g(`<circle cx="30" cy="40" r="6" fill="${fur2}"/><circle cx="70" cy="36" r="5" fill="${fur2}"/><circle cx="76" cy="70" r="6" fill="${fur2}"/><circle cx="22" cy="70" r="4" fill="${fur2}"/><circle cx="56" cy="32" r="3" fill="${fur2}"/>`);
    case 'galaxy':
      return g(`<circle cx="30" cy="38" r="22" fill="${fur2}" opacity=".35"/><circle cx="74" cy="76" r="20" fill="#3ee8ff" opacity=".25"/>
        ${[[24, 46], [70, 32], [40, 30], [80, 58], [20, 74], [62, 84], [34, 84], [56, 40]].map(([x, y], i) => `<circle cx="${x}" cy="${y}" r="${i % 3 === 0 ? 1.8 : 1.1}" fill="#fff"/>`).join('')}`);
    default:
      return '';
  }
}

function earsInner(look) {
  const inner = look.pattern === 'siamese' ? look.fur2 : '#ffb3c7';
  return `<path d="M22 40 L24 14 L42 30Z" fill="${inner}"/><path d="M78 40 L76 14 L58 30Z" fill="${inner}"/>`;
}

function accessory(acc) {
  switch (acc) {
    case 'bow':
      return `<g transform="translate(70 24) rotate(18)"><path d="M0 0 L-12 -8 L-12 8Z M0 0 L12 -8 L12 8Z" fill="#ff3d7f" stroke="#c4105a" stroke-width="1.4"/><circle r="3.6" fill="#ff7aa8"/></g>`;
    case 'crown':
      return `<path d="M32 22 L36 6 L44 16 L50 2 L56 16 L64 6 L68 22Z" fill="#ffd400" stroke="#c48a00" stroke-width="1.6"/><circle cx="50" cy="15" r="2.6" fill="#ff3d7f"/><circle cx="38" cy="17" r="1.8" fill="#3b9cff"/><circle cx="62" cy="17" r="1.8" fill="#3ddc84"/>`;
    case 'glasses':
      return `<g fill="rgba(40,40,60,.55)" stroke="#111" stroke-width="2.4"><rect x="24" y="50" width="22" height="15" rx="6"/><rect x="54" y="50" width="22" height="15" rx="6"/></g><path d="M46 56 h8" stroke="#111" stroke-width="2.4"/>`;
    case 'tophat':
      return `<rect x="34" y="0" width="32" height="22" rx="3" fill="#1b1b22"/><rect x="26" y="20" width="48" height="6" rx="3" fill="#1b1b22"/><rect x="34" y="14" width="32" height="5" fill="#c0263b"/>`;
    case 'headphones':
      return `<path d="M16 60 Q16 14 50 14 Q84 14 84 60" stroke="#222" stroke-width="5" fill="none"/><rect x="8" y="52" width="13" height="22" rx="5" fill="#ff3d7f"/><rect x="79" y="52" width="13" height="22" rx="5" fill="#ff3d7f"/>`;
    case 'bandana':
      return `<path d="M20 34 Q50 18 80 34 L78 40 Q50 28 22 40Z" fill="#e8344a"/><circle cx="34" cy="33" r="1.4" fill="#fff"/><circle cx="50" cy="28" r="1.4" fill="#fff"/><circle cx="66" cy="33" r="1.4" fill="#fff"/><path d="M80 34 l10 -4 l-4 10z" fill="#e8344a"/>`;
    case 'flower':
      return `<g transform="translate(28 26)">${[0, 72, 144, 216, 288].map((a) => `<ellipse rx="4" ry="7" transform="rotate(${a}) translate(0 -6)" fill="#ff9bd2"/>`).join('')}<circle r="3.6" fill="#ffd400"/></g>`;
    case 'halo':
      return `<ellipse cx="50" cy="8" rx="20" ry="5" fill="none" stroke="#ffe14d" stroke-width="3.6"/><ellipse cx="50" cy="8" rx="20" ry="5" fill="none" stroke="#fff6b0" stroke-width="1.2"/>`;
    case 'horns':
      return `<path d="M28 30 Q20 12 30 4 Q30 18 38 26Z" fill="#7a1010"/><path d="M72 30 Q80 12 70 4 Q70 18 62 26Z" fill="#7a1010"/>`;
    case 'wizard':
      return `<path d="M24 28 L54 -6 L76 28Z" fill="#4b2bb5" stroke="#2b1670" stroke-width="1.6"/><rect x="18" y="24" width="64" height="7" rx="3.5" fill="#2b1670"/><path d="M48 10 l1.6 3.4 3.8.4 -2.8 2.6.8 3.8 -3.4-2 -3.4 2 .8-3.8 -2.8-2.6 3.8-.4z" fill="#ffe14d"/>`;
    case 'astronaut':
      return `<circle cx="50" cy="58" r="47" fill="rgba(180,230,255,.18)" stroke="#e8eef8" stroke-width="5"/><path d="M20 30 Q30 18 44 16" stroke="#fff" stroke-width="3" fill="none" opacity=".8" stroke-linecap="round"/>`;
    default:
      return '';
  }
}

export function catSVG(look, mood = 'idle', extraClass = '') {
  const clip = `cc${++uid}`;
  const mouth = mood === 'shock'
    ? `<ellipse cx="50" cy="78" rx="4" ry="5" fill="#5a1a26"/>`
    : mood === 'happy' || mood === 'love' || mood === 'wow'
      ? `<path d="M43 74 Q50 84 57 74 Z" fill="#c8264a"/>`
      : `<path d="M44 75 Q47 79 50 75 Q53 79 56 75" stroke="#2a1a1a" stroke-width="2.2" fill="none" stroke-linecap="round"/>`;
  return `<svg class="cat-svg ${extraClass}" viewBox="0 -8 100 112" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
    <defs><clipPath id="${clip}"><ellipse cx="50" cy="60" rx="38" ry="34"/><path d="M14 44 L22 8 L46 28Z M86 44 L78 8 L54 28Z"/></clipPath></defs>
    <path d="M14 44 L22 8 L46 28Z" fill="${look.fur}" stroke="rgba(0,0,0,.25)" stroke-width="1.5"/>
    <path d="M86 44 L78 8 L54 28Z" fill="${look.fur}" stroke="rgba(0,0,0,.25)" stroke-width="1.5"/>
    ${earsInner(look)}
    <ellipse cx="50" cy="60" rx="38" ry="34" fill="${look.fur}" stroke="rgba(0,0,0,.25)" stroke-width="1.5"/>
    ${pattern(look, clip)}
    <ellipse cx="50" cy="74" rx="15" ry="10" fill="rgba(255,255,255,.35)"/>
    ${eyes(mood, look.eyes)}
    <ellipse cx="24" cy="70" rx="6" ry="3.6" fill="#ff7aa8" opacity=".5"/>
    <ellipse cx="76" cy="70" rx="6" ry="3.6" fill="#ff7aa8" opacity=".5"/>
    <path d="M47 68 L53 68 L50 72Z" fill="#ff6b8a"/>
    ${mouth}
    <g stroke="rgba(30,20,20,.55)" stroke-width="1.3" stroke-linecap="round"><path d="M30 72 L8 68 M30 76 L8 78 M70 72 L92 68 M70 76 L92 78"/></g>
    ${accessory(look.acc)}
  </svg>`;
}
