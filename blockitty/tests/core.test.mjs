import test from 'node:test';
import assert from 'node:assert/strict';
import {
  SIZE, SHAPES, emptyBoard, canPlace, placePiece, scoreMove, dealTray, anyMoveLeft, mulberry32, bomb, hammer,
  reviveClear, challengeBoard, fullLines, COMBO_GRACE,
} from '../js/core.js';

const shape = (id) => SHAPES.find((s) => s.id === id);

test('pieces stay inside the board', () => {
  const b = emptyBoard();
  assert.equal(canPlace(b, shape('h5'), 0, 3), true);
  assert.equal(canPlace(b, shape('h5'), 0, 4), false);
  assert.equal(canPlace(b, shape('v5'), 4, 0), false);
});

test('cannot overlap filled cells', () => {
  const b = emptyBoard();
  b[1][1] = 3;
  assert.equal(canPlace(b, shape('sq2'), 0, 0), false);
  assert.equal(canPlace(b, shape('sq2'), 2, 2), true);
});

test('completing a row and a column clears both, shared cell counted once', () => {
  const b = emptyBoard();
  for (let c = 0; c < SIZE; c++) if (c !== 0) b[0][c] = 1;
  for (let r = 0; r < SIZE; r++) if (r !== 0) b[r][0] = 2;
  const move = placePiece(b, shape('dot'), 0, 0, 5);
  assert.equal(move.lines, 2);
  assert.equal(move.cleared.length, 15);
  assert.equal(move.perfect, true);
  assert.ok(b.every((row) => row.every((v) => v === 0)));
});

test('combo grows and expires after grace moves', () => {
  let st = { combo: 0, miss: 0 };
  const clear = { placed: 1, lines: 1, perfect: false };
  const none = { placed: 1, lines: 0, perfect: false };
  let r = scoreMove(clear, st); st = r.combo;
  assert.equal(st.combo, 1); assert.equal(r.points, 11);
  r = scoreMove(clear, st); st = r.combo;
  assert.equal(st.combo, 2); assert.equal(r.points, 21);
  for (let i = 0; i < COMBO_GRACE - 1; i++) { st = scoreMove(none, st).combo; assert.equal(st.combo, 2); }
  st = scoreMove(none, st).combo;
  assert.equal(st.combo, 0);
});

test('dealt tray always has a playable piece on a playable board', () => {
  const rng = mulberry32(42);
  for (let i = 0; i < 300; i++) {
    const b = emptyBoard();
    for (let k = 0; k < 40; k++) b[Math.floor(rng() * 8)][Math.floor(rng() * 8)] = 1;
    const { rows, cols } = fullLines(b);
    if (rows.length || cols.length) continue;
    if (!SHAPES.some((s) => s.id === 'dot') || !anyMoveLeft(b, [{ shape: shape('dot') }])) continue;
    const tray = dealTray(b, rng);
    assert.equal(tray.length, 3);
    assert.ok(anyMoveLeft(b, tray), 'tray should fit');
  }
});

test('power-ups and revive clear cells', () => {
  const b = emptyBoard();
  for (let r = 0; r < SIZE; r++) for (let c = 0; c < SIZE; c++) b[r][c] = (r + c) % 2 ? 1 : 0;
  assert.equal(hammer(b, 0, 0).length, 0);
  assert.equal(hammer(b, 0, 1).length, 1);
  assert.ok(bomb(b, 4, 4).length > 0);
  for (let r = 3; r <= 5; r++) for (let c = 3; c <= 5; c++) assert.equal(b[r][c], 0);
  b[2][2] = 4;
  reviveClear(b);
  for (let r = 2; r < 6; r++) for (let c = 2; c < 6; c++) assert.equal(b[r][c], 0);
});

test('challenge board is deterministic and has no full lines', () => {
  const a = challengeBoard(mulberry32(7));
  const b = challengeBoard(mulberry32(7));
  assert.deepEqual(a, b);
  const { rows, cols } = fullLines(a);
  assert.equal(rows.length + cols.length, 0);
});
