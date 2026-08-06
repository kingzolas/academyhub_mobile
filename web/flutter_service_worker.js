/*
 * AcademyHub's Flutter 3.41 migration worker.
 *
 * `flutter build web --pwa-strategy=none` leaves no runtime cache strategy.
 * This tiny worker exists only at the historical Flutter worker URL so a
 * device controlled by an old Flutter cache worker can install a non-caching
 * replacement. It owns no CacheStorage and does not intercept fetches.
 */
'use strict';

self.addEventListener('install', () => {
  // The page only requests a worker update after the user has chosen a safe
  // moment to reload. Do not leave this compatibility worker in waiting.
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  // Unregister only this exact registration. No other worker, cache,
  // IndexedDB database, local storage item or authentication state is touched.
  event.waitUntil(self.registration.unregister());
});
