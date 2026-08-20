# Open Items

Durable notes for this repo. Add a date to every entry. Delete an entry when it
is closed, and say where it went.

## Outbound link audit — 2026-08-20

Every URL that ships in this repo was checked live on 2026-08-20. All resolve to
the correct destination.

| URL | Result |
|---|---|
| `https://ko-fi.com/initiatorworks?app=timeannouncer` | Live. Shows "Buy Douglas a Coffee". Checked in a browser. |
| `https://github.com/initiator1/timeannouncer` | 200 |
| `https://github.com/initiator1/timeannouncer/issues` | 200 |
| `https://github.com/initiator1/timeannouncer/releases/latest` | 200, redirects to `v1.0.1` |
| `https://huggingface.co/hexgrad/Kokoro-82M` | 200 |
| `https://initiatorworks.com` | 200, titled "INITIATOR LLC" |

**No GitHub Sponsors link exists in this repo.** unstray shipped
`https://github.com/sponsors/initiator1` in its README, and that page does not
exist. GitHub Sponsors is not enabled for the account, so the URL redirects to
the profile page instead of returning 404. BOSS has said he will probably not
enable Sponsors. Do not add such a link to this repo.

**How to check a Ko-fi URL.** `curl` cannot do it. Ko-fi answers 403 from
Cloudflare whether the page exists or not, so a dead link passes a scripted
check. Load the URL in a real browser and read the page title.

**Do not use `ko-fi.com/initiator1`.** That slug never existed. It shipped as a
dead link in RedButtonQuit 1.0.0. The correct slug is `initiatorworks`.

## Ko-fi tracking gives no data yet — 2026-08-20 — owner: BOSS

The support link carries `?app=timeannouncer` so one Ko-fi page can tell which
of four apps sent a visitor. The other three apps use `?app=redbuttonquit`,
`?app=unstray`, and `?app=portmanager`.

The parameter records nothing readable today. Ko-fi exposes this data only
through its Google Analytics 4 integration, and that integration requires a paid
Ko-fi Contributor account. The tag costs nothing and starts working on the day
GA4 is connected.

**Decision waiting on BOSS:** pay for Ko-fi Contributor and connect GA4, or
accept that the four apps stay indistinguishable. Until then, do not tell him
the parameter produces click counts.

## Stale debug build ran for 12 days — 2026-08-19 — closed

The menu bar clock was running a build from 6 August out of Xcode's DerivedData
folder, not the signed app in `/Applications`. It was missing **Check for
Updates…**, which shipped in 1.0.1. It was restarted on the current build on
2026-08-19.

Worth knowing: `open` on the app bundle activates an already-running instance
instead of loading new code. Kill the process first when verifying a UI change.
