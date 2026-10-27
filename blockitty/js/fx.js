// Full-screen particle overlay for clear effects.

const canvas = document.createElement('canvas');
canvas.id = 'fx-layer';
const ctx = canvas.getContext('2d');
let parts = [];
let running = false;
let dpr = 1;

export function initFx() {
  document.body.appendChild(canvas);
  const resize = () => {
    dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = innerWidth * dpr;
    canvas.height = innerHeight * dpr;
  };
  resize();
  addEventListener('resize', resize);
}

const RAINBOW = ['#ff3d3d', '#ff9f1c', '#ffe14d', '#3ddc84', '#2bb5ff', '#7a5cff', '#ff5ce1'];

function heart(c, s) {
  c.beginPath();
  c.moveTo(0, s * 0.3);
  c.bezierCurveTo(-s, -s * 0.4, -s * 0.4, -s, 0, -s * 0.35);
  c.bezierCurveTo(s * 0.4, -s, s, -s * 0.4, 0, s * 0.3);
  c.fill();
}
function star(c, s) {
  c.beginPath();
  for (let i = 0; i < 10; i++) {
    const r = i % 2 ? s * 0.45 : s;
    const a = (Math.PI / 5) * i - Math.PI / 2;
    c.lineTo(Math.cos(a) * r, Math.sin(a) * r);
  }
  c.closePath(); c.fill();
}
function pawShape(c, s) {
  c.beginPath(); c.ellipse(0, s * 0.25, s * 0.45, s * 0.38, 0, 0, Math.PI * 2); c.fill();
  for (const [x, y] of [[-0.48, -0.2], [-0.17, -0.5], [0.17, -0.5], [0.48, -0.2]]) {
    c.beginPath(); c.ellipse(x * s, y * s, s * 0.16, s * 0.2, 0, 0, Math.PI * 2); c.fill();
  }
}
function fishShape(c, s) {
  c.beginPath(); c.ellipse(0, 0, s, s * 0.55, 0, 0, Math.PI * 2); c.fill();
  c.beginPath(); c.moveTo(s * 0.8, 0); c.lineTo(s * 1.5, -s * 0.6); c.lineTo(s * 1.5, s * 0.6); c.closePath(); c.fill();
}

export function burst(cells, fxId, palette) {
  for (const cell of cells) {
    const n = fxId === 'rainbow' ? 7 : 5;
    for (let i = 0; i < n; i++) {
      const a = Math.random() * Math.PI * 2;
      const sp = 2 + Math.random() * 5;
      const col = fxId === 'rainbow' ? RAINBOW[(i + Math.floor(cell.x)) % 7]
        : fxId === 'hearts' ? ['#ff3d7f', '#ff7aa8', '#ffb3c7'][i % 3]
          : fxId === 'stars' ? ['#ffe14d', '#fff6b0', '#ffb000'][i % 3]
            : fxId === 'bubbles' ? 'rgba(180,230,255,.8)'
              : fxId === 'fish' ? ['#7ad3ff', '#ffb36b', '#a98bff'][i % 3]
                : palette[(cell.color - 1 + i) % palette.length];
      parts.push({
        x: cell.x, y: cell.y,
        vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - (fxId === 'bubbles' ? 3 : 2),
        g: fxId === 'bubbles' ? -0.05 : fxId === 'fish' ? 0.35 : 0.22,
        life: 1, decay: 0.012 + Math.random() * 0.015,
        size: (fxId === 'confetti' ? 5 : 7) + Math.random() * 6,
        rot: Math.random() * 6, vr: (Math.random() - 0.5) * 0.3,
        col, kind: fxId,
      });
    }
  }
  if (!running) { running = true; requestAnimationFrame(tick); }
}

function tick() {
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  parts = parts.filter((p) => p.life > 0);
  for (const p of parts) {
    p.x += p.vx; p.y += p.vy; p.vy += p.g; p.vx *= 0.98; p.rot += p.vr; p.life -= p.decay;
    ctx.save();
    ctx.globalAlpha = Math.max(0, p.life);
    ctx.translate(p.x, p.y);
    ctx.rotate(p.rot);
    ctx.fillStyle = p.col;
    const s = p.size;
    switch (p.kind) {
      case 'confetti': ctx.fillRect(-s / 2, -s / 4, s, s / 2); break;
      case 'hearts': heart(ctx, s); break;
      case 'stars': case 'rainbow': star(ctx, s); break;
      case 'paws': pawShape(ctx, s * 0.8); break;
      case 'fish': fishShape(ctx, s * 0.6); break;
      case 'bubbles':
        ctx.strokeStyle = p.col; ctx.lineWidth = 2;
        ctx.beginPath(); ctx.arc(0, 0, s * 0.7, 0, Math.PI * 2); ctx.stroke();
        ctx.fillStyle = 'rgba(255,255,255,.6)'; ctx.beginPath(); ctx.arc(-s * 0.25, -s * 0.25, s * 0.15, 0, Math.PI * 2); ctx.fill();
        break;
      default: // sparkle
        ctx.beginPath(); ctx.moveTo(0, -s); ctx.lineTo(s * 0.25, 0); ctx.lineTo(0, s); ctx.lineTo(-s * 0.25, 0); ctx.closePath(); ctx.fill();
        ctx.beginPath(); ctx.moveTo(-s, 0); ctx.lineTo(0, s * 0.25); ctx.lineTo(s, 0); ctx.lineTo(0, -s * 0.25); ctx.closePath(); ctx.fill();
    }
    ctx.restore();
  }
  if (parts.length) requestAnimationFrame(tick);
  else { running = false; ctx.clearRect(0, 0, canvas.width, canvas.height); }
}

export function floatText(text, x, y, cls = '') {
  const el = document.createElement('div');
  el.className = `float-text ${cls}`;
  el.textContent = text;
  el.style.left = `${x}px`;
  el.style.top = `${y}px`;
  document.body.appendChild(el);
  setTimeout(() => el.remove(), 1200);
}

export function confettiRain(n = 80) {
  const cells = [];
  for (let i = 0; i < n / 5; i++) cells.push({ x: Math.random() * innerWidth, y: Math.random() * innerHeight * 0.4, color: 1 + (i % 7) });
  burst(cells, 'confetti', RAINBOW);
}
