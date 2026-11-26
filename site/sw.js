/* SOWRIX R43: privacy-first service worker. Do not cache API, HTML, sessions, private records or files. */
'use strict';
const CACHE_NAME = 'sowrix-pwa-r46-26-static-v3';
const CACHE_PREFIX = 'sowrix-pwa-';
const PRECACHE = ['/offline.html', '/assets/sowrix-pwa-192.png', '/assets/sowrix-pwa-512.png'];
const PRECACHE_SET = new Set(PRECACHE);
self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE_NAME).then(cache =>
    cache.addAll(PRECACHE.map(path => new Request(path,{cache:'reload'})))
  ).then(()=>self.skipWaiting()));
});
self.addEventListener('activate', event => {
  event.waitUntil(Promise.all([
    caches.keys().then(keys => Promise.all(keys.filter(key => key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME).map(key => caches.delete(key)))),
    self.clients.claim()
  ]));
});
self.addEventListener('fetch', event => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;
  // Never intercept API responses or potentially private downloads. All navigation is network-first.
  if (url.pathname.startsWith('/api/') || url.pathname.startsWith('/downloads/')) return;
  if (request.mode === 'navigate') {
    event.respondWith(fetch(request).catch(async () => {
      const cache = await caches.open(CACHE_NAME);
      return (await cache.match('/offline.html')) || Response.error();
    }));
    return;
  }
  if (PRECACHE_SET.has(url.pathname)) {
    event.respondWith(caches.open(CACHE_NAME).then(async cache => {
      const cached = await cache.match(url.pathname);
      return cached || fetch(request);
    }));
  }
});
