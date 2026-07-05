# feeds.likelylabs.com

Station backup feeds for the radio apps — the **Firebase-outage / Mainland-
China fallback**. When a Remote Config fetch fails, the apps fetch these
files and serve them until RC succeeds again (iOS: `StationBackup.swift`;
Android spec: `radioapp-android/station-backup-feed.md`).

## Why a dedicated subdomain

The URL `https://feeds.likelylabs.com/...` is **baked into shipped app
binaries** as the Remote Config default — and the users who need it most
(Mainland China) can never receive an RC override, because RC is exactly
what's unreachable for them. A subdomain we control means the backing host
can be changed with one DNS record — GitHub Pages today, a China-reachable
mirror or CDN tomorrow — without shipping new binaries.

## Files

| file | market / app |
|------|--------------|
| `stations-hk.json` | HK (iOS app + Android `hk` flavor) |
| `stations-hktw.json` | Android `hktw` |
| `stations-hksamsung.json` | Android `hksamsung` |
| `stations-my.json` | Android `my` |
| `stations-sg.json` | Android `sg` |

## Rules

- Each file must contain **exactly the current Remote Config `stations`
  value** for that market's Firebase project. The current files are seeded
  from the apps' *bundled* defaults — **refresh from the RC console before
  going live**: clients prefer a freshly-fetched backup over their cached RC
  data, so a stale file here can downgrade users' station lists during any
  RC hiccup.
- Update these files **every time** a `stations` RC value changes — one
  step in the station-update routine, so they can't drift.
- Clients validate before applying (must parse to ≥ 1 station), fetch at
  most once per 6 hours, and switch back to RC automatically on its next
  success. HTTPS is required by the clients.

## One-time setup (DNS + GitHub)

1. Create a GitHub repo for this directory (e.g. `likelylabs/feeds`) and
   push.
2. Repo Settings → Pages → deploy from the default branch; set custom
   domain `feeds.likelylabs.com` (the `CNAME` file here keeps it pinned).
3. At the DNS registrar: add a CNAME record
   `feeds.likelylabs.com → likelylabs.github.io`.
4. Wait for the certificate to provision, then enable "Enforce HTTPS".
5. Verify `https://feeds.likelylabs.com/stations-hk.json` returns the JSON.
6. Check reachability from a Mainland China vantage point. If blocked,
   host a mirror there and re-point the DNS record — no app change needed.
