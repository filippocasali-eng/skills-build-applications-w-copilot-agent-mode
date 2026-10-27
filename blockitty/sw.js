// Offline-first cache so the installed game works without network.
const CACHE = 'blockitty-v2';
const ASSETS = [
  './', 'index.html', 'privacy.html', 'manifest.webmanifest', 'css/style.css',
  'js/main.js', 'js/config.js', 'js/core.js', 'js/data.js', 'js/state.js', 'js/ui.js', 'js/game.js',
  'js/cats.js', 'js/skins.js', 'js/fx.js', 'js/audio.js', 'js/billing.js', 'js/ads.js', 'js/share.js', 'js/notify.js',
  'fonts/fredoka-latin-400-normal.woff2', 'fonts/fredoka-latin-500-normal.woff2',
  'fonts/fredoka-latin-600-normal.woff2', 'fonts/fredoka-latin-700-normal.woff2',
  'icons/icon-192.png', 'icons/icon-512.png', 'icons/maskable-512.png',
];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(ASSETS)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))).then(() => self.clients.claim()));
});

// Network first for fresh updates, cache fallback when offline.
self.addEventListener('fetch', (e) => {
  if (e.request.method !== 'GET' || new URL(e.request.url).origin !== location.origin) return;
  e.respondWith(
    fetch(e.request)
      .then((res) => {
        const copy = res.clone();
        caches.open(CACHE).then((c) => c.put(e.request, copy));
        return res;
      })
      .catch(() => caches.match(e.request, { ignoreSearch: true }).then((r) => r || caches.match('index.html'))),
  );
});
