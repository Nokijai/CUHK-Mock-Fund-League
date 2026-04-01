// Browsers often probe /service-worker.js; without this file Rails logged RoutingError.
// This app does not register an offline PWA worker from HTML; this is a no-op placeholder.
self.addEventListener("install", (event) => {
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(self.clients.claim());
});
