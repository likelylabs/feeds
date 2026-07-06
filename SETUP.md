# SETUP — stand up feeds.likelylabs.com

Self-contained work order for this repo. Execute top to bottom; acceptance
criteria at the end. Context: `README.md` in this repo (what these feeds
are); consumers are `radioapp-ios` (`StationBackup.swift`, shipped) and
`radioapp-android` (`StationBackup.kt`, implemented). The five JSON files
here are currently **seeds from the apps' bundled defaults** — correct
format, potentially stale content.

## Why the content refresh matters (read first)

The clients prefer a **freshly fetched** backup over their cached Remote
Config data (precedence is by fetch timestamp, not content). If these files
go live older than what RC has already delivered to users, any RC hiccup
"upgrades" users to the older list. **Nothing goes live before step 1.**

Client validation contract (do not break): each file must be a JSON array
that parses with ≥ 1 station; stations carry `shortcode`, `titleen`,
`titlezh`, `descriptionen`, `descriptionzh`, `tags`, `streamurl`,
`logourl`, `volume` (schema identical to the RC `stations` value — because
it IS the RC `stations` value).

## Prerequisites

- `gh` CLI authenticated to the GitHub account that owns `likelylabs`.
- `firebase-tools` authenticated to an account with Remote Config read
  access on all four Firebase projects (`npx firebase-tools login`).
- DNS registrar access for `likelylabs.com` (one manual record).

## Step 1 — refresh the feeds from Remote Config

Market → Firebase project → file:

| file | Firebase project | note |
|------|------------------|------|
| `stations-hk.json` | `ios-hk-radio` | template default `stations` value |
| `stations-hksamsung.json` | `ios-hk-radio` | **conditional variant** — see trap below |
| `stations-hktw.json` | `hktwradio` | template default |
| `stations-my.json` | `my-radio-185b7` | template default |
| `stations-sg.json` | `radio-singapore` | template default |

For each project, pull the current template and extract the `stations`
parameter's value:

```bash
npx firebase-tools remoteconfig:get --project <project-id> -o /tmp/<project-id>.json
python3 - <<'EOF'
import json
t = json.load(open('/tmp/<project-id>.json'))
value = t['parameters']['stations']['defaultValue']['value']
stations = json.loads(value)          # must parse
assert len(stations) >= 1 and all('shortcode' in s for s in stations)
json.dump(stations, open('stations-<market>.json','w'),
          ensure_ascii=False, separators=(',',':'))
print(len(stations), 'stations')
EOF
```

> **The hksamsung trap:** `hksamsung` shares the `ios-hk-radio` project with
> `hk` but ships a *different* bundled list (150 vs 162 stations — Samsung
> store compliance). Its production value is therefore a **conditional
> value** in that project's RC template (keyed on the Samsung app's package/
> app id), not `defaultValue`. Inspect `parameters['stations']
> ['conditionalValues']` in the pulled template, identify the Samsung
> condition, and use that value for `stations-hksamsung.json`. If no such
> condition exists, STOP and confirm with Kevin how the Samsung build gets
> its reduced list before publishing anything for it — publishing the wrong
> variant would push store-non-compliant stations to Samsung users.
>
> **Resolved 2026-07-05:** no Samsung conditional exists — one shared
> `stations` value serves both `hk` and `hksamsung` (the flavor is dormant,
> not in `build.gradle`), so the feed carries the shared value: exactly what
> live RC already delivers to any Samsung install. Refresh via
> `./refresh.sh`, which delegates to `radioapp-firebase-rest/rc.py`
> (gcloud auth) — the firebase-tools snippet above is superseded.

Sanity-diff each refreshed file against the seed before committing: the
diff should look like recent station edits, not a wholesale replacement.
If a refreshed file is byte-identical to the seed, that market simply
hasn't changed since the last app release — fine.

Save the pull-and-extract as `refresh.sh` in this repo (parameterized over
the table above) and commit it — updating these files must become one
mechanical step in every future station-list update.

## Step 2 — GitHub repo + Pages

```bash
gh repo create likelylabs/feeds --public --source . --push
```
(Public is required for Pages on free plans; the data is public anyway.)

Then: repo Settings → Pages → Deploy from branch → `main` / root. Set
custom domain `feeds.likelylabs.com` (the committed `CNAME` file keeps it
pinned across deploys).

## Step 3 — DNS (manual, registrar)

Add: `feeds.likelylabs.com  CNAME  likelylabs.github.io`

This record is the entire "forwardable URL" design: the day GitHub Pages is
unsuitable (e.g. blocked in China), re-point this one record at a mirror —
every shipped binary follows, no release needed.

## Step 4 — HTTPS

Wait for GitHub to provision the certificate (minutes to ~1h after DNS
propagates), then enable **Enforce HTTPS** in the Pages settings. The
clients hard-require `https://` and will silently skip the fetch without it.

## Step 5 — verify serving

```bash
for f in stations-hk stations-hktw stations-hksamsung stations-my stations-sg; do
  curl -fsS "https://feeds.likelylabs.com/$f.json" | python3 -c "
import json,sys; d=json.load(sys.stdin); assert len(d)>=1; print('$f:', len(d), 'stations')"
done
```

All five must print a station count. Anything else (404, HTML, redirect to
the apex domain) means the Pages custom domain isn't wired right.

## Step 6 — Mainland China reachability check

GitHub Pages is frequently blocked or DNS-poisoned in mainland China — the
primary audience for this fallback. Check `https://feeds.likelylabs.com/stations-hk.json`
from a mainland vantage point (e.g. 17ce.com / boce.com multi-region probes,
or a contact on the mainland). Record the result in this README.

- **Reachable** → done; China users get station updates for the first time.
- **Blocked** → the mechanism still works as a global Firebase-outage
  fallback, but the China goal needs a mirror on a mainland-reachable host
  (options: a China-friendly CDN in front, or object storage + CDN with an
  ICP-filed domain — a product/ops decision for Kevin). Re-point the DNS
  record when the mirror exists; apps need no change.

## Step 7 — close the loop

In `radioapp-ios/tasks/todo.md`, check off **S.1** with a note of the date,
the China-check result, and the `refresh.sh` location. The end-to-end app
verification lives there too: block Firebase on a device/simulator, allow
`feeds.likelylabs.com`, launch the app → the `station_backup_applied`
analytics event fires and the station grid populates from the feed.

## Acceptance criteria

1. All five files refreshed from their RC sources (hksamsung from the
   correct conditional variant), committed, pushed.
2. `refresh.sh` committed and re-runnable.
3. Step 5 curl loop passes over HTTPS.
4. DNS record live; Enforce HTTPS enabled.
5. China check performed and its result recorded in README.md.
6. S.1 in radioapp-ios updated.
