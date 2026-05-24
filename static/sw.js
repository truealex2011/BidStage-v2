/* BidStage Service Worker
   - Кэшируем статику и шаблоны главной для офлайн-состояния
   - Для API всегда ходим в сеть
   - При новой версии — самообновление
*/
const VERSION = 'bs-v1.0.4';
const STATIC_CACHE = 'bs-static-' + VERSION;
const RUNTIME_CACHE = 'bs-runtime-' + VERSION;

const PRECACHE = [
  '/',
  '/static/css/main.css',
  '/static/js/main.js',
  '/static/manifest.webmanifest',
  '/static/icon-192.png',
  '/static/icon-512.png',
  '/static/apple-touch-icon.png'
];

self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(STATIC_CACHE)
      .then((cache) => cache.addAll(PRECACHE).catch(() => {}))
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((k) => k.startsWith('bs-') && k !== STATIC_CACHE && k !== RUNTIME_CACHE)
          .map((k) => caches.delete(k))
      )
    ).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);

  // Сторонние домены — не трогаем
  if (url.origin !== self.location.origin) return;

  // API и WebSocket — всегда сеть
  if (url.pathname.startsWith('/api/') ||
      url.pathname.startsWith('/socket.io') ||
      url.pathname.startsWith('/auth/') ||
      url.pathname.startsWith('/webhook/')) {
    return;
  }

  // Картинки лотов — всегда сеть (это user-content, не кэшируем во избежание stale)
  if (url.pathname.startsWith('/static/lot_images/') ||
      url.pathname.startsWith('/lot-image/')) {
    return;
  }

  // Навигационные запросы — network-first с фолбэком на кеш
  if (req.mode === 'navigate') {
    event.respondWith(
      fetch(req)
        .then((res) => {
          const copy = res.clone();
          caches.open(RUNTIME_CACHE).then((c) => c.put(req, copy));
          return res;
        })
        .catch(() => caches.match(req).then((cached) => cached || caches.match('/')))
    );
    return;
  }

  // Статика — cache-first
  if (url.pathname.startsWith('/static/')) {
    event.respondWith(
      caches.match(req).then((cached) => {
        if (cached) return cached;
        return fetch(req).then((res) => {
          if (res.ok) {
            const copy = res.clone();
            caches.open(STATIC_CACHE).then((c) => c.put(req, copy));
          }
          return res;
        });
      })
    );
    return;
  }
});

/* Push-уведомления — приём от сервера */
self.addEventListener('push', (event) => {
  let data = {};
  try { data = event.data ? event.data.json() : {}; } catch (e) {}
  const title = data.title || 'BidStage';
  const options = {
    body: data.body || '',
    icon: data.icon || '/static/icon-192.png',
    badge: '/static/icon-192.png',
    data: { url: data.url || '/', tag: data.tag || 'bs' },
    tag: data.tag || 'bs',
    renotify: !!data.renotify
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = (event.notification.data && event.notification.data.url) || '/';
  event.waitUntil(
    clients.matchAll({ type: 'window' }).then((wins) => {
      for (const w of wins) {
        if (w.url.includes(url) && 'focus' in w) return w.focus();
      }
      if (clients.openWindow) return clients.openWindow(url);
    })
  );
});
