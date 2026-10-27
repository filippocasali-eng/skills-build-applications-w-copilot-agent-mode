import { load, ensureDaily, S } from './state.js';
import { setAudio } from './audio.js';
import { initFx } from './fx.js';
import { initBilling } from './billing.js';
import { initUI, show, gameHooks, loginModal, rerender, refreshTop } from './ui.js';
import { initGame } from './game.js';

async function boot() {
  load();
  const newDay = ensureDaily();
  setAudio(S.settings.sound, S.settings.haptics);
  initFx();
  initUI();
  initGame(gameHooks());
  await initBilling();
  show('home');
  if (newDay || !S.daily.loginClaimed) setTimeout(loginModal, 500);

  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible' && ensureDaily()) {
      if (!document.body.classList.contains('in-game')) rerender();
      refreshTop();
      setTimeout(loginModal, 300);
    }
  });

  if ('serviceWorker' in navigator && location.protocol !== 'file:') {
    navigator.serviceWorker.register('sw.js').catch(() => {});
  }
}

boot();
