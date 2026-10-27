// Pure game logic: board, pieces, scoring, tray generation. No DOM here.

export const SIZE = 8;
export const COLORS = 7;

export function mulberry32(seed) {
  let a = seed >>> 0;
  return function () {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function hashString(str) {
  let h = 2166136261;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

// Shapes as lists of [row, col]. Weight = relative chance to be dealt.
const RAW_SHAPES = [
  { id: 'dot', w: 3, cells: [[0, 0]] },
  { id: 'h2', w: 5, cells: [[0, 0], [0, 1]] },
  { id: 'v2', w: 5, cells: [[0, 0], [1, 0]] },
  { id: 'h3', w: 6, cells: [[0, 0], [0, 1], [0, 2]] },
  { id: 'v3', w: 6, cells: [[0, 0], [1, 0], [2, 0]] },
  { id: 'h4', w: 4, cells: [[0, 0], [0, 1], [0, 2], [0, 3]] },
  { id: 'v4', w: 4, cells: [[0, 0], [1, 0], [2, 0], [3, 0]] },
  { id: 'h5', w: 2, cells: [[0, 0], [0, 1], [0, 2], [0, 3], [0, 4]] },
  { id: 'v5', w: 2, cells: [[0, 0], [1, 0], [2, 0], [3, 0], [4, 0]] },
  { id: 'sq2', w: 6, cells: [[0, 0], [0, 1], [1, 0], [1, 1]] },
  { id: 'sq3', w: 2, cells: [[0, 0], [0, 1], [0, 2], [1, 0], [1, 1], [1, 2], [2, 0], [2, 1], [2, 2]] },
  { id: 'r23', w: 3, cells: [[0, 0], [0, 1], [0, 2], [1, 0], [1, 1], [1, 2]] },
  { id: 'r32', w: 3, cells: [[0, 0], [0, 1], [1, 0], [1, 1], [2, 0], [2, 1]] },
  { id: 'c1', w: 4, cells: [[0, 0], [1, 0], [1, 1]] },
  { id: 'c2', w: 4, cells: [[0, 0], [0, 1], [1, 0]] },
  { id: 'c3', w: 4, cells: [[0, 0], [0, 1], [1, 1]] },
  { id: 'c4', w: 4, cells: [[0, 1], [1, 0], [1, 1]] },
  { id: 'l1', w: 3, cells: [[0, 0], [1, 0], [2, 0], [2, 1]] },
  { id: 'l2', w: 3, cells: [[0, 0], [0, 1], [0, 2], [1, 0]] },
  { id: 'l3', w: 3, cells: [[0, 0], [0, 1], [1, 1], [2, 1]] },
  { id: 'l4', w: 3, cells: [[0, 2], [1, 0], [1, 1], [1, 2]] },
  { id: 'j1', w: 3, cells: [[0, 1], [1, 1], [2, 0], [2, 1]] },
  { id: 'j2', w: 3, cells: [[0, 0], [1, 0], [1, 1], [1, 2]] },
  { id: 'j3', w: 3, cells: [[0, 0], [0, 1], [1, 0], [2, 0]] },
  { id: 'j4', w: 3, cells: [[0, 0], [0, 1], [0, 2], [1, 2]] },
  { id: 't1', w: 3, cells: [[0, 0], [0, 1], [0, 2], [1, 1]] },
  { id: 't2', w: 3, cells: [[0, 1], [1, 0], [1, 1], [2, 1]] },
  { id: 't3', w: 3, cells: [[0, 1], [1, 0], [1, 1], [1, 2]] },
  { id: 't4', w: 3, cells: [[0, 0], [1, 0], [1, 1], [2, 0]] },
  { id: 's1', w: 2, cells: [[0, 1], [0, 2], [1, 0], [1, 1]] },
  { id: 's2', w: 2, cells: [[0, 0], [1, 0], [1, 1], [2, 1]] },
  { id: 'z1', w: 2, cells: [[0, 0], [0, 1], [1, 1], [1, 2]] },
  { id: 'z2', w: 2, cells: [[0, 1], [1, 0], [1, 1], [2, 0]] },
  { id: 'big_l', w: 2, cells: [[0, 0], [1, 0], [2, 0], [2, 1], [2, 2]] },
  { id: 'big_j', w: 2, cells: [[0, 0], [0, 1], [0, 2], [1, 2], [2, 2]] },
];

export const SHAPES = RAW_SHAPES.map((s) => {
  const rows = Math.max(...s.cells.map((c) => c[0])) + 1;
  const cols = Math.max(...s.cells.map((c) => c[1])) + 1;
  return { ...s, rows, cols };
});

export function emptyBoard() {
  return Array.from({ length: SIZE }, () => new Array(SIZE).fill(0));
}

export function cloneBoard(board) {
  return board.map((r) => r.slice());
}

export function canPlace(board, shape, r, c) {
  for (const [dr, dc] of shape.cells) {
    const rr = r + dr;
    const cc = c + dc;
    if (rr < 0 || cc < 0 || rr >= SIZE || cc >= SIZE) return false;
    if (board[rr][cc]) return false;
  }
  return true;
}

export function fitsAnywhere(board, shape) {
  for (let r = 0; r <= SIZE - shape.rows; r++) {
    for (let c = 0; c <= SIZE - shape.cols; c++) {
      if (canPlace(board, shape, r, c)) return true;
    }
  }
  return false;
}

// Which rows/cols would be full if shape were placed at r,c (assumes placeable).
export function linesCompletedBy(board, shape, r, c) {
  const b = cloneBoard(board);
  for (const [dr, dc] of shape.cells) b[r + dr][c + dc] = 1;
  return fullLines(b);
}

export function fullLines(board) {
  const rows = [];
  const cols = [];
  for (let i = 0; i < SIZE; i++) {
    if (board[i].every((v) => v)) rows.push(i);
    let full = true;
    for (let j = 0; j < SIZE; j++) if (!board[j][i]) { full = false; break; }
    if (full) cols.push(i);
  }
  return { rows, cols };
}

export const LINE_POINTS = [0, 10, 30, 60, 100, 150, 210, 280, 360, 450, 550, 660, 780, 910, 1050, 1200, 1360];

// Mutates board. Returns details of the move for scoring/effects.
export function placePiece(board, shape, r, c, color) {
  for (const [dr, dc] of shape.cells) board[r + dr][c + dc] = color;
  const { rows, cols } = fullLines(board);
  const cleared = [];
  const seen = new Set();
  const take = (rr, cc) => {
    const k = rr * SIZE + cc;
    if (seen.has(k)) return;
    seen.add(k);
    cleared.push({ r: rr, c: cc, color: board[rr][cc] });
  };
  for (const rr of rows) for (let cc = 0; cc < SIZE; cc++) take(rr, cc);
  for (const cc of cols) for (let rr = 0; rr < SIZE; rr++) take(rr, cc);
  for (const cell of cleared) board[cell.r][cell.c] = 0;
  const lines = rows.length + cols.length;
  const perfect = lines > 0 && board.every((row) => row.every((v) => !v));
  return { rows, cols, lines, cleared, perfect, placed: shape.cells.length };
}

// Combo logic: combo grows with every clearing move, survives up to
// COMBO_GRACE non-clearing moves, then resets.
export const COMBO_GRACE = 3;

export function scoreMove(move, comboState) {
  const next = { ...comboState };
  let points = move.placed;
  if (move.lines > 0) {
    next.combo = comboState.combo + 1;
    next.miss = 0;
    const base = LINE_POINTS[Math.min(move.lines, LINE_POINTS.length - 1)];
    points += base * next.combo;
    if (move.perfect) points += 300 * next.combo;
  } else {
    next.miss = comboState.miss + 1;
    if (next.miss >= COMBO_GRACE) next.combo = 0;
  }
  return { points, combo: next };
}

function pickWeighted(rng, list) {
  const total = list.reduce((s, x) => s + x.w, 0);
  let roll = rng() * total;
  for (const x of list) {
    roll -= x.w;
    if (roll <= 0) return x;
  }
  return list[list.length - 1];
}

export function fillRatio(board) {
  let n = 0;
  for (const row of board) for (const v of row) if (v) n++;
  return n / (SIZE * SIZE);
}

// Deal three pieces. Guarantees at least one fits when possible, and when the
// board gets crowded it leans toward smaller pieces so runs feel fair.
export function dealTray(board, rng) {
  const crowded = fillRatio(board) > 0.55;
  const pool = crowded
    ? SHAPES.map((s) => ({ ...s, w: s.cells.length <= 3 ? s.w * 2.5 : s.w }))
    : SHAPES;
  let best = null;
  for (let attempt = 0; attempt < 30; attempt++) {
    const tray = [0, 1, 2].map(() => {
      const s = pickWeighted(rng, pool);
      return { shape: SHAPES.find((x) => x.id === s.id), color: 1 + Math.floor(rng() * COLORS) };
    });
    const fitCount = tray.filter((t) => fitsAnywhere(board, t.shape)).length;
    if (!best || fitCount > best.fitCount) best = { tray, fitCount };
    if (fitCount >= (crowded ? 2 : 1)) return tray;
  }
  return best.tray;
}

export function anyMoveLeft(board, tray) {
  return tray.some((t) => t && fitsAnywhere(board, t.shape));
}

// Hammer: clear one cell. Bomb: clear a 3x3 area. Both return cleared cells.
export function hammer(board, r, c) {
  if (!board[r] || !board[r][c]) return [];
  const cell = { r, c, color: board[r][c] };
  board[r][c] = 0;
  return [cell];
}

export function bomb(board, r, c) {
  const out = [];
  for (let rr = r - 1; rr <= r + 1; rr++) {
    for (let cc = c - 1; cc <= c + 1; cc++) {
      if (rr < 0 || cc < 0 || rr >= SIZE || cc >= SIZE) continue;
      if (board[rr][cc]) {
        out.push({ r: rr, c: cc, color: board[rr][cc] });
        board[rr][cc] = 0;
      }
    }
  }
  return out;
}

// Revive: clear the central 4x4 so the player gets a real second chance.
export function reviveClear(board) {
  const out = [];
  for (let r = 2; r < 6; r++) {
    for (let c = 2; c < 6; c++) {
      if (board[r][c]) {
        out.push({ r, c, color: board[r][c] });
        board[r][c] = 0;
      }
    }
  }
  return out;
}

// Daily challenge board: a seeded, partially filled board with no full lines.
export function challengeBoard(rng) {
  const board = emptyBoard();
  const target = 14 + Math.floor(rng() * 8);
  let placed = 0;
  let guard = 0;
  while (placed < target && guard++ < 500) {
    const r = Math.floor(rng() * SIZE);
    const c = Math.floor(rng() * SIZE);
    if (board[r][c]) continue;
    board[r][c] = 1 + Math.floor(rng() * COLORS);
    const { rows, cols } = fullLines(board);
    if (rows.length || cols.length) { board[r][c] = 0; continue; }
    placed++;
  }
  return board;
}
