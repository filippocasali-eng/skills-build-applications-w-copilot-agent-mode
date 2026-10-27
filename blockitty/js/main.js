import { load, ensureDaily, S } from './state.js';
import { setAudio, unlockOnGesture, suspendAudio, resumeAudio, playMusic } from './audio.js';
import { initFx } from './fx.js';
import { initBilling } from './billing.js';
import { initAds } from './ads.js';
import { initUI, show, gameHooks, rerender, refreshTop, startGame, incomingChallenge, grantSku } from './ui.js';
import { initGame, isRunning, hasSavedRun } from './game.js';
import { readIncomingChallenge } from './share.js';
import { scheduleReminders } from './notify.js';
import { isNative, plugin } from './config.js';
import { verifyOfficial } from './guard.js';

function onBack() {
  const modals = document.querySelectorAll('#modal-root .modal-back');
  if (modals.length) {
    const top = modals[modals.length - 1];
    const x = top.querySelector('[data-close]');
    if (x) x.click();
    return;
  }
  if (document.body.classList.contains('in-game')) { document.getElementById('btn-pause').click(); return; }
  if (!document.getElementById('screen-home').classList.contains('active')) { show('home'); return; }
  plugin('App')?.exitApp();
}

async function boot() {
  await verifyOfficial();
  load();
  const newDay = ensureDaily();
  setAudio(S.settings);
  unlockOnGesture();
  initFx();
  initUI();
  initGame(gameHooks());
  initBilling(grantSku).catch(() => {});
  initAds().catch(() => {});
  scheduleReminders();

  const challenge = readIncomingChallenge();
  if (challenge) history.replaceState(null, '', location.pathname);

  if (S.stats.games === 0 && !challenge) {
    // Instant play: the first launch drops straight into a game.
    startGame(hasSavedRun() ? { resume: true } : { mode: 'classic' });
  } else {
    show('home');
    if (challenge) incomingChallenge(challenge);
    else if (newDay || !S.daily.loginClaimed) setTimeout(() => document.querySelector('[data-act="rewards"]')?.click(), 600);
  }

  const App = plugin('App');
  if (App) App.addListener('backButton', onBack);

  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'hidden') { suspendAudio(); return; }
    resumeAudio();
    if (ensureDaily()) { if (!isRunning() || !document.body.classList.contains('in-game')) rerender(); refreshTop(); }
  });

  if ('serviceWorker' in navigator && !isNative() && location.protocol !== 'file:') {
    navigator.serviceWorker.register('sw.js').catch(() => {});
  }
  playMusic(document.body.classList.contains('in-game') ? 'game' : 'menu');
}

boot();
