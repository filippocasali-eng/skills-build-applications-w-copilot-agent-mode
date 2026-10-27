// Canvas rendering for block skins.

function rr(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}

function shade(hex, amt) {
  const n = parseInt(hex.slice(1), 16);
  let r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
  const f = (v) => Math.max(0, Math.min(255, Math.round(amt > 0 ? v + (255 - v) * amt : v * (1 + amt))));
  r = f(r); g = f(g); b = f(b);
  return `rgb(${r},${g},${b})`;
}

function paw(ctx, cx, cy, s, color) {
  ctx.fillStyle = color;
  ctx.beginPath(); ctx.ellipse(cx, cy + s * 0.12, s * 0.2, s * 0.16, 0, 0, Math.PI * 2); ctx.fill();
  for (const [dx, dy] of [[-0.2, -0.1], [-0.07, -0.22], [0.07, -0.22], [0.2, -0.1]]) {
    ctx.beginPath(); ctx.ellipse(cx + dx * s, cy + dy * s, s * 0.07, s * 0.085, 0, 0, Math.PI * 2); ctx.fill();
  }
}

function fish(ctx, cx, cy, s, color) {
  ctx.fillStyle = color;
  ctx.beginPath(); ctx.ellipse(cx - s * 0.04, cy, s * 0.22, s * 0.13, 0, 0, Math.PI * 2); ctx.fill();
  ctx.beginPath(); ctx.moveTo(cx + s * 0.14, cy); ctx.lineTo(cx + s * 0.3, cy - s * 0.12); ctx.lineTo(cx + s * 0.3, cy + s * 0.12); ctx.closePath(); ctx.fill();
  ctx.fillStyle = 'rgba(0,0,0,.5)';
  ctx.beginPath(); ctx.arc(cx - s * 0.15, cy - s * 0.02, s * 0.025, 0, Math.PI * 2); ctx.fill();
}

// Deterministic sparkle positions for galaxy cells
const STAR_SPOTS = [[0.2, 0.25], [0.7, 0.2], [0.5, 0.55], [0.25, 0.75], [0.8, 0.7]];

export function drawCell(ctx, x, y, s, colorIdx, skin, alpha = 1) {
  const base = skin.palette[(colorIdx - 1) % skin.palette.length];
  const pad = s * 0.04;
  const X = x + pad, Y = y + pad, S = s - pad * 2;
  ctx.save();
  ctx.globalAlpha = alpha;
  switch (skin.style) {
    case 'flat': {
      rr(ctx, X, Y, S, S, S * 0.28); ctx.fillStyle = base; ctx.fill();
      ctx.fillStyle = 'rgba(255,255,255,.35)';
      rr(ctx, X + S * 0.15, Y + S * 0.12, S * 0.3, S * 0.12, S * 0.06); ctx.fill();
      break;
    }
    case 'gloss': {
      const g = ctx.createLinearGradient(X, Y, X, Y + S);
      g.addColorStop(0, shade(base, 0.35)); g.addColorStop(1, shade(base, -0.25));
      rr(ctx, X, Y, S, S, S * 0.22); ctx.fillStyle = g; ctx.fill();
      ctx.fillStyle = 'rgba(255,255,255,.55)';
      ctx.beginPath(); ctx.ellipse(X + S * 0.5, Y + S * 0.26, S * 0.34, S * 0.14, 0, 0, Math.PI * 2); ctx.fill();
      ctx.strokeStyle = shade(base, -0.4); ctx.lineWidth = S * 0.05; rr(ctx, X, Y, S, S, S * 0.22); ctx.stroke();
      break;
    }
    case 'pixel': {
      const p = S / 8;
      ctx.fillStyle = base; ctx.fillRect(X, Y, S, S);
      ctx.fillStyle = shade(base, 0.45); ctx.fillRect(X, Y, S, p); ctx.fillRect(X, Y, p, S);
      ctx.fillStyle = shade(base, -0.45); ctx.fillRect(X, Y + S - p, S, p); ctx.fillRect(X + S - p, Y, p, S);
      ctx.fillStyle = 'rgba(255,255,255,.8)'; ctx.fillRect(X + p * 2, Y + p * 2, p, p);
      break;
    }
    case 'neon': {
      rr(ctx, X + S * 0.06, Y + S * 0.06, S * 0.88, S * 0.88, S * 0.16);
      ctx.fillStyle = 'rgba(10,8,25,.85)'; ctx.fill();
      ctx.shadowColor = base; ctx.shadowBlur = S * 0.45;
      ctx.strokeStyle = base; ctx.lineWidth = S * 0.1; ctx.stroke();
      ctx.shadowBlur = 0;
      ctx.strokeStyle = 'rgba(255,255,255,.75)'; ctx.lineWidth = S * 0.03; ctx.stroke();
      break;
    }
    case 'jelly': {
      const g = ctx.createRadialGradient(X + S * 0.35, Y + S * 0.3, S * 0.05, X + S * 0.5, Y + S * 0.5, S * 0.75);
      g.addColorStop(0, shade(base, 0.55)); g.addColorStop(0.6, base); g.addColorStop(1, shade(base, -0.35));
      rr(ctx, X, Y, S, S, S * 0.38); ctx.fillStyle = g; ctx.fill();
      ctx.fillStyle = 'rgba(255,255,255,.7)';
      ctx.beginPath(); ctx.ellipse(X + S * 0.3, Y + S * 0.28, S * 0.1, S * 0.07, -0.6, 0, Math.PI * 2); ctx.fill();
      break;
    }
    case 'paw': {
      rr(ctx, X, Y, S, S, S * 0.24); ctx.fillStyle = base; ctx.fill();
      ctx.strokeStyle = shade(base, -0.3); ctx.lineWidth = S * 0.06; ctx.stroke();
      paw(ctx, X + S / 2, Y + S / 2 + S * 0.04, S, 'rgba(255,255,255,.6)');
      break;
    }
    case 'fish': {
      rr(ctx, X, Y, S, S, S * 0.24); ctx.fillStyle = base; ctx.fill();
      ctx.strokeStyle = shade(base, -0.3); ctx.lineWidth = S * 0.06; ctx.stroke();
      fish(ctx, X + S / 2, Y + S / 2, S, 'rgba(255,255,255,.7)');
      break;
    }
    case 'galaxy': {
      const g = ctx.createLinearGradient(X, Y, X + S, Y + S);
      g.addColorStop(0, '#1a0f3d'); g.addColorStop(0.55, shade(base, -0.35)); g.addColorStop(1, base);
      rr(ctx, X, Y, S, S, S * 0.2); ctx.fillStyle = g; ctx.fill();
      ctx.fillStyle = '#fff';
      STAR_SPOTS.forEach(([sx, sy], i) => { ctx.beginPath(); ctx.arc(X + sx * S, Y + sy * S, S * (i % 2 ? 0.025 : 0.04), 0, Math.PI * 2); ctx.fill(); });
      ctx.strokeStyle = shade(base, 0.3); ctx.lineWidth = S * 0.05; rr(ctx, X, Y, S, S, S * 0.2); ctx.stroke();
      break;
    }
    case 'metal': {
      const g = ctx.createLinearGradient(X, Y, X + S, Y + S);
      g.addColorStop(0, '#fff6c8'); g.addColorStop(0.35, base); g.addColorStop(0.6, '#b8860b'); g.addColorStop(1, '#ffe680');
      rr(ctx, X, Y, S, S, S * 0.14); ctx.fillStyle = g; ctx.fill();
      ctx.strokeStyle = '#8a6410'; ctx.lineWidth = S * 0.06; ctx.stroke();
      ctx.strokeStyle = 'rgba(255,255,255,.7)'; ctx.lineWidth = S * 0.04;
      ctx.beginPath(); ctx.moveTo(X + S * 0.2, Y + S * 0.75); ctx.lineTo(X + S * 0.75, Y + S * 0.2); ctx.stroke();
      break;
    }
    case 'gem': {
      const cx = X + S / 2, cy = Y + S / 2, i = S * 0.22;
      ctx.fillStyle = shade(base, -0.35); ctx.fillRect(X, Y, S, S);
      const face = (pts, col) => { ctx.beginPath(); pts.forEach(([a, b], k) => (k ? ctx.lineTo(a, b) : ctx.moveTo(a, b))); ctx.closePath(); ctx.fillStyle = col; ctx.fill(); };
      face([[X, Y], [X + S, Y], [cx + i, cy - i], [cx - i, cy - i]], shade(base, 0.45));
      face([[X + S, Y], [X + S, Y + S], [cx + i, cy + i], [cx + i, cy - i]], shade(base, 0.05));
      face([[X, Y + S], [X + S, Y + S], [cx + i, cy + i], [cx - i, cy + i]], shade(base, -0.45));
      face([[X, Y], [X, Y + S], [cx - i, cy + i], [cx - i, cy - i]], shade(base, 0.2));
      face([[cx - i, cy - i], [cx + i, cy - i], [cx + i, cy + i], [cx - i, cy + i]], shade(base, 0.25));
      ctx.fillStyle = 'rgba(255,255,255,.85)'; ctx.fillRect(cx - i * 0.7, cy - i * 0.7, i * 0.4, i * 0.4);
      break;
    }
    default: { // bevel
      rr(ctx, X, Y, S, S, S * 0.16); ctx.fillStyle = base; ctx.fill();
      ctx.fillStyle = shade(base, 0.35);
      ctx.beginPath(); ctx.moveTo(X + S * 0.12, Y + S * 0.12); ctx.lineTo(X + S * 0.88, Y + S * 0.12); ctx.lineTo(X + S * 0.74, Y + S * 0.26); ctx.lineTo(X + S * 0.26, Y + S * 0.26); ctx.closePath(); ctx.fill();
      ctx.fillStyle = shade(base, -0.25);
      ctx.beginPath(); ctx.moveTo(X + S * 0.12, Y + S * 0.88); ctx.lineTo(X + S * 0.88, Y + S * 0.88); ctx.lineTo(X + S * 0.74, Y + S * 0.74); ctx.lineTo(X + S * 0.26, Y + S * 0.74); ctx.closePath(); ctx.fill();
    }
  }
  ctx.restore();
}

// Small preview canvas for shop/collection cards.
export function skinPreview(skin, size = 96) {
  const c = document.createElement('canvas');
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  c.width = c.height = size * dpr;
  c.style.width = c.style.height = `${size}px`;
  const ctx = c.getContext('2d');
  ctx.scale(dpr, dpr);
  const s = size / 3;
  const layout = [[0, 0, 1], [0, 1, 2], [1, 1, 4], [1, 2, 5], [2, 0, 6], [2, 1, 3], [2, 2, 7]];
  for (const [r, col, k] of layout) drawCell(ctx, col * s, r * s, s, k, skin);
  return c;
}
