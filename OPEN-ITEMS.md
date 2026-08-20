# Open Items

Durable notes for this repo. Add a date to every entry. Delete an entry when it
is closed, and say where it went.

## Outbound link audit — 2026-08-20

Every URL that ships in this repo was checked live on 2026-08-20. All resolve to
the correct destination.

| URL | Result |
|---|---|
| `https://ko-fi.com/initiatorworks?app=timeannouncer` | Live. Checked in a browser. |
| `https://github.com/initiator1/timeannouncer` | 200 |
| `https://github.com/initiator1/timeannouncer/issues` | 200 |
| `https://github.com/initiator1/timeannouncer/releases/latest` | 200, redirects to `v1.0.1` |
| `https://huggingface.co/hexgrad/Kokoro-82M` | 200 |
| `https://initiatorworks.com` | 200, titled "INITIATOR LLC" |

**`.github/FUNDING.yml` uses the `custom` key on purpose.** The `ko_fi:` key
takes a bare username and drops the query string, which loses the `app` tag. The
`github:` key is dead here — GitHub Sponsors is not enabled for the account, and
GitHub silently omits the Sponsor button rather than showing an error. unstray
and RedButtonQuit both had a `github:` key that rendered nothing.

**No GitHub Sponsors link exists in this repo.** unstray shipped
`https://github.com/sponsors/initiator1` in its README, and that page does not
exist. GitHub Sponsors is not enabled for the account, so the URL redirects to
the profile page instead of returning 404. BOSS has said he will probably not
enable Sponsors. Do not add such a link to this repo.

**How to check a Ko-fi URL.** `curl` cannot do it. Ko-fi answers 403 from
Cloudflare whether the page exists or not, so a dead link passes a scripted
check. Load the URL in a real browser and confirm the tip form renders.

Do not match on the page title. BOSS changed the Ko-fi display name from
"Douglas" to "Douglas Baker" on 2026-08-20, so the title moved from "Buy Douglas
a Coffee" to "Buy Douglas Baker a Coffee". A title check would have failed on a
live page.

**Do not use `ko-fi.com/initiator1`.** That slug never existed. It shipped as a
dead link in RedButtonQuit 1.0.0. The correct slug is `initiatorworks`.

## GitHub Sponsor button does not render — 2026-08-20 — owner: BOSS

`.github/FUNDING.yml` is correct in all four app repos and no Sponsor button
appears on any of them.

Verified logged-out on 2026-08-20:

- No Sponsor button and no "Sponsor this project" panel on `timeannouncer` or
  `redbuttonquit`. The word "Sponsor" appears nowhere on either page.
- A control repo that does show the button, `sindresorhus/awesome`, renders
  "Sponsor this project" with its funding URLs in the sidebar under the same
  check. The method is sound.

**Cause:** the per-repo Sponsorships feature is switched off. GitHub accepts the
file and shows nothing, which is the same silent failure as a dead `github:`
key, one layer up.

**Fix, and only BOSS can do it.** Web-only setting, no API. For each repo:
Settings → General → Features → tick **Sponsorships**. Four repos, four ticks.

Until then the funding files are inert. Do not report the Sponsor button as
shipped.

### GraphQL `fundingLinks` lags on a newly created file

It looks like a clean way to check the file. It is not, and the reason is
specific rather than random. Measured across all four repos at 11:01 UTC on
2026-08-20:

| Repo | FUNDING.yml first added | Last modified | `fundingLinks` |
|---|---|---|---|
| `unstray` | 2026-07-28 | today 10:53 | populated |
| `redbuttonquit` | 2026-08-12 | today 07:26 | populated |
| `timeannouncer` | today 07:30 | today 07:30 | empty |
| `portmanager` | today 10:54 | today 10:54 | empty |

Both files that predate today register. Both files created today do not. Four
for four.

So the field tracks whether GitHub has indexed the file, not whether the file is
correct. An edit to an already-indexed file appears within minutes — `unstray`
registered its new tagged URL five minutes after the change. A first-time
creation had not appeared after three and a half hours.

Two rules follow:

1. **Never use it to check a newly added funding file.** It reports empty for a
   correct file, which reads as a defect that is not there.
2. **It never tells you what a visitor sees.** `redbuttonquit` has a populated
   `fundingLinks` and shows no Sponsor button. Registered and visible are
   independent. Check the rendered page.

**Open, costs nothing:** re-query `timeannouncer` and `portmanager` tomorrow.
Both files were created on 2026-08-20 and were still unindexed hours later. The
answer puts a real number on the first-index lag, and both repos will produce it
without any work.

    gh api graphql -f query='{ repository(owner:"initiator1", name:"timeannouncer") { fundingLinks { platform url } } }'

## Ko-fi tracking gives no data yet — 2026-08-20 — owner: BOSS

The support link carries `?app=timeannouncer` so one Ko-fi page can tell which
of four apps sent a visitor. The other three apps use `?app=redbuttonquit`,
`?app=unstray`, and `?app=portmanager`. The same tagged URL is in
`.github/FUNDING.yml`.

The parameter records nothing readable today. Ko-fi exposes this data only
through its Google Analytics 4 integration, and that needs Contributor status.

**Contributor is not a paid subscription.** Verified on ko-fi.com/pricing and
help.ko-fi.com on 2026-08-20. It is a toggle in Settings → Payment that shares
**5% of tip income** with Ko-fi. There is no monthly charge and the toggle is
reversible. It affects one-time tips only; Memberships, Shop, and Commissions
carry 5% either way. Ko-fi Gold is the separate paid tier at $12/month for a 0%
fee — do not confuse the two.

With Contributor off, tips carry 0%. That is why it is off, and that is a
defensible trade rather than a blocker.

**Decision waiting on BOSS:** turn Contributor on, give up 5% of tips, and
connect GA4 to see which app sends supporters — or leave it off, keep 100% of
tips, and accept that the four apps stay indistinguishable. Five percent of zero
is zero, so the cost today is nothing.

An earlier version of this file called Contributor "a paid account". That was
wrong and it turned a reversible toggle into a purchase decision.

## Stale debug build ran for 12 days — 2026-08-19 — closed

The menu bar clock was running a build from 6 August out of Xcode's DerivedData
folder, not the signed app in `/Applications`. It was missing **Check for
Updates…**, which shipped in 1.0.1. It was restarted on the current build on
2026-08-19.

Worth knowing: `open` on the app bundle activates an already-running instance
instead of loading new code. Kill the process first when verifying a UI change.
