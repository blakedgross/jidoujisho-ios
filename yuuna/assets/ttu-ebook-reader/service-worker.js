const e = /* @__PURE__ */ location.pathname.split("/").slice(0, -1).join("/"), v = [
  e + "/_app/immutable/entry/start.12131640.js",
  e + "/_app/immutable/entry/error.svelte.7ea0a6d1.js",
  e + "/_app/immutable/entry/app.74c756fd.js",
  e + "/_app/immutable/chunks/0.38425743.js",
  e + "/_app/immutable/chunks/1.42f3a3f6.js",
  e + "/_app/immutable/chunks/2.6670f027.js",
  e + "/_app/immutable/chunks/3.3ede055b.js",
  e + "/_app/immutable/chunks/4.aacb6fce.js",
  e + "/_app/immutable/chunks/5.66ce67c9.js",
  e + "/_app/immutable/chunks/6.af60902d.js",
  e + "/_app/immutable/chunks/error-handler.275fe05e.js",
  e + "/_app/immutable/chunks/fa.1edd0cc5.js",
  e + "/_app/immutable/assets/fa.32503cb2.css",
  e + "/_app/immutable/chunks/fonts.37c28be2.js",
  e + "/_app/immutable/chunks/format-page-title.f7c88302.js",
  e + "/_app/immutable/chunks/index.5ec26865.js",
  e + "/_app/immutable/chunks/index.92b6332b.js",
  e + "/_app/immutable/chunks/merged-header-icon.214071fc.js",
  e + "/_app/immutable/chunks/singletons.4ff16de6.js",
  e + "/_app/immutable/chunks/store.67b455b4.js",
  e + "/_app/immutable/assets/store.ad073191.css",
  e + "/_app/immutable/chunks/stores.6eaf01a8.js",
  e + "/_app/immutable/chunks/theme-option.4e279c0f.js",
  e + "/_app/immutable/assets/_layout.866c1a46.css",
  e + "/_app/immutable/entry/_layout.svelte.c3aa58b2.js",
  e + "/_app/immutable/entry/_page.svelte.83846a2d.js",
  e + "/_app/immutable/entry/auth-page.svelte.a0cfdce2.js",
  e + "/_app/immutable/assets/_page.64118891.css",
  e + "/_app/immutable/entry/b-page.svelte.e4207a47.js",
  e + "/_app/immutable/entry/manage-page.svelte.fef9e332.js",
  e + "/_app/immutable/entry/settings-page.svelte.9dc4e277.js"
], k = [
  e + "/apple-touch-icon.png",
  e + "/favicon.ico",
  e + "/favicon.png",
  e + "/fonts/genEiKoburiMin5.ttf",
  e + "/fonts/klee-one-v7-600.woff",
  e + "/fonts/klee-one-v7-600.woff2",
  e + "/fonts/klee-one-v7-regular.woff",
  e + "/fonts/klee-one-v7-regular.woff2",
  e + "/fonts/noto-sans-v42-500.woff",
  e + "/fonts/noto-sans-v42-500.woff2",
  e + "/fonts/noto-sans-v42-700.woff",
  e + "/fonts/noto-sans-v42-700.woff2",
  e + "/fonts/noto-sans-v42-regular.woff",
  e + "/fonts/noto-sans-v42-regular.woff2",
  e + "/fonts/noto-serif-v21-500.woff",
  e + "/fonts/noto-serif-v21-500.woff2",
  e + "/fonts/noto-serif-v21-700.woff",
  e + "/fonts/noto-serif-v21-700.woff2",
  e + "/fonts/noto-serif-v21-regular.woff",
  e + "/fonts/noto-serif-v21-regular.woff2",
  e + "/fonts/shippori-mincho-v14-500.woff",
  e + "/fonts/shippori-mincho-v14-500.woff2",
  e + "/fonts/shippori-mincho-v14-700.woff",
  e + "/fonts/shippori-mincho-v14-700.woff2",
  e + "/fonts/shippori-mincho-v14-regular.woff",
  e + "/fonts/shippori-mincho-v14-regular.woff2",
  e + "/icons/maskable-icon@128x128.png",
  e + "/icons/maskable-icon@16x16.png",
  e + "/icons/maskable-icon@192x192.png",
  e + "/icons/maskable-icon@32x32.png",
  e + "/icons/maskable-icon@512x512.png",
  e + "/icons/regular-icon@16x16.png",
  e + "/icons/regular-icon@192x192.png",
  e + "/icons/regular-icon@32x32.png",
  e + "/icons/regular-icon@512x512.png",
  e + "/manifest.webmanifest",
  e + "/safari-pinned-tab.svg"
], g = [
  e + "/",
  e + "/__data.json",
  e + "/auth",
  e + "/auth/__data.json",
  e + "/b",
  e + "/b/__data.json",
  e + "/manage",
  e + "/manage/__data.json",
  e + "/settings",
  e + "/settings/__data.json"
], _ = "1794755319413";
/**
 * @license BSD-3-Clause
 * Copyright (c) 2023, ッツ Reader Authors
 * All rights reserved.
 */
const y = {}.VITE_PAGE_PATH || "";
/**
 * @license BSD-3-Clause
 * Copyright (c) 2023, ッツ Reader Authors
 * All rights reserved.
 */
function x(t) {
  return Object.entries(t).map(([s, a]) => `${encodeURIComponent(s)}=${encodeURIComponent(a)}`).join("&");
}
/**
 * @license BSD-3-Clause
 * Copyright (c) 2023, ッツ Reader Authors
 * All rights reserved.
 */
const R = "ttu-userfonts", c = self, l = `build:${_}`, C = new Set(g), w = v.concat(k).concat(g), E = new Set(w);
c.addEventListener("install", (t) => {
  c.skipWaiting(), t.waitUntil(caches.open(l).then((s) => s.addAll(w)));
});
c.addEventListener("activate", (t) => {
  t.waitUntil(
    caches.keys().then((s) => {
      const a = s.filter(
        (n) => n !== l && n !== R
      );
      return Promise.all(a.map((n) => caches.delete(n)));
    })
  );
});
c.addEventListener("fetch", (t) => {
  if (t.request.method !== "GET" || t.request.headers.has("range"))
    return;
  const s = new URL(t.request.url), a = s.protocol.startsWith("http"), n = s.hostname === c.location.hostname && s.port !== c.location.port, r = s.host === c.location.host, f = r && E.has(s.pathname), i = t.request.cache === "only-if-cached" && !f;
  if (!(!a || n || i)) {
    if (r && C.has(s.pathname)) {
      const o = new Request(s.pathname);
      t.respondWith(
        b(t.request, !1, l, o)
      );
      return;
    }
    if (r && s.pathname.startsWith("/userfonts/")) {
      t.respondWith(
        caches.match(s.pathname).then((o) => o ?? j("/fonts/noto-serif-v21-regular.woff2"))
      );
      return;
    }
    if (r) {
      const o = f ? caches.match(s.pathname).then((u) => u ?? fetch(t.request)) : U(t.request);
      if (o) {
        t.respondWith(o);
        return;
      }
    }
    s.host === "fonts.googleapis.com" && t.respondWith(b(t.request));
  }
});
async function b(t, s = !0, a, n) {
  const r = await caches.open(`other:${_}`), f = new AbortController();
  let i, o = !1, u = !1;
  const m = () => a ? caches.match(n ?? t, { cacheName: a }) : void 0, h = async () => {
    if (!s)
      return m();
    const p = await r.match(t);
    if (p)
      return p;
    if (a)
      return m();
  };
  try {
    const p = setTimeout(async () => {
      i = await h(), u = !0, !(!i || o) && f.abort();
    }, 1e3), d = await fetch(t, { signal: f.signal });
    return o = !0, clearTimeout(p), s && r.put(t, d.clone()), d;
  } catch (p) {
    if (u || (i = await h()), i)
      return i;
    throw p;
  }
}
function U(t) {
  const s = new URL(t.url), n = /\/b\/(?<id>\d+)\/?(\?|$)/.exec(s.pathname);
  if (n != null && n.groups)
    return j(`${[[y]]}/b?${x(n.groups)}`);
}
function j(t) {
  return new Response(null, {
    status: 302,
    headers: {
      location: t
    }
  });
}
