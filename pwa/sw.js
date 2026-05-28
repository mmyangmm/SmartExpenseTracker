const CACHE_NAME = "i-expense-pwa-v11";
const CORE_ASSETS = [
  "./",
  "./index.html",
  "./styles.css?v=11",
  "./firebase-config.js?v=11",
  "./app.js?v=11",
  "./manifest.webmanifest",
  "./CHANGELOG.md",
  "./assets/icon-192.png",
  "./assets/icon-512.png",
  "./assets/icon-1024.png",
  "./assets/apple-touch-icon.png",
  "./assets/app-icon-cat.png"
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(CORE_ASSETS))
  );
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key)))
    )
  );
  self.clients.claim();
});

self.addEventListener("fetch", (event) => {
  if (event.request.method !== "GET") return;
  event.respondWith(
    caches.match(event.request).then((cached) => {
      if (cached) return cached;
      return fetch(event.request).then((response) => {
        const copy = response.clone();
        caches.open(CACHE_NAME).then((cache) => cache.put(event.request, copy));
        return response;
      });
    })
  );
});
