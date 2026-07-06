/*
 * coi-serviceworker (versión simplificada)
 * ------------------------------------------------------------------
 * GitHub Pages no permite configurar cabeceras HTTP personalizadas, pero
 * sqlite3.wasm (usado por sqflite_common_ffi_web) necesita que el sitio
 * sea "cross-origin isolated" (cabeceras COOP + COEP) para funcionar de
 * forma fiable con SharedArrayBuffer / workers.
 *
 * Este service worker intercepta cada petición y le agrega esas dos
 * cabeceras a la respuesta, simulando que el servidor las envió.
 * ------------------------------------------------------------------
 */

const IS_SW = typeof window === 'undefined';

if (IS_SW) {
  // ---- Contexto: Service Worker ----
  self.addEventListener('install', () => self.skipWaiting());
  self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

  self.addEventListener('fetch', (event) => {
    const request = event.request;
    if (request.cache === 'only-if-cached' && request.mode !== 'same-origin') {
      return;
    }

    event.respondWith(
      fetch(request)
        .then((response) => {
          if (response.status === 0) {
            return response;
          }
          const newHeaders = new Headers(response.headers);
          newHeaders.set('Cross-Origin-Embedder-Policy', 'credentialless');
          newHeaders.set('Cross-Origin-Opener-Policy', 'same-origin');
          return new Response(response.body, {
            status: response.status,
            statusText: response.statusText,
            headers: newHeaders,
          });
        })
        .catch((e) => console.error('coi-serviceworker fetch error:', e))
    );
  });
} else {
  // ---- Contexto: Página principal ----
  (() => {
    // Si el navegador ya está cross-origin isolated, no hace falta nada.
    if (window.crossOriginIsolated !== false) return;

    // Evita loops infinitos de recarga.
    const alreadyReloaded = window.sessionStorage.getItem('coiReloadedBySelf');

    if (!navigator.serviceWorker) {
      console.log('coi-serviceworker no soportado (se requiere HTTPS o localhost).');
      return;
    }

    navigator.serviceWorker
      .register(window.document.currentScript.src)
      .then((registration) => {
        console.log('COOP/COEP service worker registrado', registration.scope);

        registration.addEventListener('updatefound', () => {
          if (!alreadyReloaded) {
            window.sessionStorage.setItem('coiReloadedBySelf', 'true');
            window.location.reload();
          }
        });

        // Si ya hay un SW controlando la página pero aún no está aislada,
        // recarga una vez para que las cabeceras surtan efecto.
        if (registration.active && !navigator.serviceWorker.controller) {
          if (!alreadyReloaded) {
            window.sessionStorage.setItem('coiReloadedBySelf', 'true');
            window.location.reload();
          }
        }
      })
      .catch((e) => console.error('No se pudo registrar coi-serviceworker:', e));
  })();
}
