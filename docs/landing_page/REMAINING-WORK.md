# Remaining work — landing page & monetization

**Unnumbered on purpose.** `63`–`74` are plans: written once, implemented, then annotated with
what actually landed. This file is the opposite — a working list that changes every time
something is picked up or dropped. Numbering it would imply it is a plan someone should execute
top to bottom, and it is not.

It answers one question: *given that `63`–`74` are done, what is genuinely left?*

Last reviewed: **2026-10-03** (quick-wins pass: W10, W11, B5, M10 and the first-load JS work closed; before that 2026-09-03, after `72` F1–F5).

---

## 1. Parked until the company exists

**This is the whole store-launch section, and it is deliberately on hold** — not forgotten, not
descoped. It was written up in full first (`74`) so that the day the company is registered, it
is a paste-and-upload job rather than a fresh start.

The blocker is one thing: **there is no legal entity yet**, so there is no App Store Connect
account, no Play Console account, no Stripe account, and no company data for the Impresszum.

What unblocks the moment the company exists, in the order that unblocks the most:

| # | Item | Where it is already written up |
|---|---|---|
| 1 | Company identity — name, registered address, company registration number, tax number, representative | fills the five `[kitöltendő]` fields in `messages/marketing.{hu,en}.json` → `/jogi/impresszum`; `72` F1 Prompt 6 |
| 2 | App Store Connect + Play Console app records | `devops/deploy-ios-appstore.md`, `devops/deploy-android-playstore.md` |
| 3 | The four IAP products (`lifey.pro.monthly`, `lifey.pro.yearly` in one subscription group per store) | `74` §5, ids from `63` D-M6 — already compiled into the app |
| 4 | AdMob console: two apps + four ad units | then `--dart-define` them and run `dart run tool/check_release_ad_ids.dart` (`72` Prompt 11) |
| 5 | Paste the listing copy, privacy answers and screenshots into the consoles | `74` §1–§4; the 19 PNGs come from `node devops/export-store-screenshots.mjs` |
| 6 | Stripe account → the 12-step test-mode round trip | `73` §1 |
| 7 | Store sandbox matrix, two devices | `73` §2 |
| 8 | Swap the placeholders: real store URLs + official badge artwork in `StoreBadges.tsx` | `72` Prompt 20 |
| 9 | Real legal review of the four legal pages | `72` W8 |

Nothing in the codebase is waiting on a decision here — the app runs, sells nothing, and shows
"Hamarosan" where the store links will go. That state is deliberate and safe to leave.

**One decision to make when this is picked up again:** the English screenshot set does not
exist (the canvas has six full-size Hungarian frames and English only as a contact sheet).
`74` §4 lays out three options and recommends shipping Hungarian screenshots in both storefronts
for the first submission, then drawing six real English frames before any English-language
marketing push.

---

## 2. Developable now — nothing external needed

Ordered by value per hour, roughly.

### 2.1 The AI meal-estimation feature (`docs/23`)

**Backend landed 2026-09-22** (`POST /api/v1/meals/estimate`, `EntitlementAiFeatureGate`): B1
and B4 below are closed — the counter is incremented after each successful call and the gate
enforces Free 3 / Pro 100 per month. **M7 closed too** — the mobile screen landed the same day. The list
below is the state this started from:

- `72` B1 — the 402/`AI_CREDITS_EXHAUSTED` gate has no AI call path to sit in. The counter, the
  config, the entitlement field and the mobile chip are all built and tested; nothing increments
  the counter because nothing calls an LLM yet.
- `72` M7 — `AiCreditChip` and `requireAiCredits` exist, are tested, and are mounted on no
  screen.
- `72` B4 — Pro's 100/month fair-use ceiling (`63` D-M5) is enforced nowhere; it belongs to
  `AiFeatureGate`, which this feature brings.

`docs/23` now carries the exact call order, the transaction boundary and the status codes the
gate must use (`72` F3 Prompt 14), so the billing side is specified rather than guessed.

### 2.2 Web: first-load JS — ✅ done (2026-10-08, LIF-117)

`/hu` went from ~278 KB to **~168 KB** gzipped. Earlier (2026-10-03): `lib/env.ts` no longer imports zod (~64 KB) and
Vercel's Analytics/Speed Insights load behind an idle callback. LIF-117 found two more things:

- **~39 KB was never a visitor's cost.** `scripts/check-js-budget.mjs` counted Next's `noModule` polyfill bundle, which only
  browsers too old for ES modules fetch. It is excluded now, so the number is what a real first load downloads.
- **~8 KB was query-core on pages that have no query cache.** The marketing header reads the session store, and the store
  imported the `queryClient` singleton to clear it on logout. It goes through `lib/queryCacheClearer` now; the app's
  `queryClient` registers itself when its providers load.

`65` §8's literal **100 KB is not reachable**: React DOM plus the Next client router are ~142 KB gzipped on their own, and
the app's own share (next-intl, the header island, the session store) is ~26 KB. The CI ceiling is tightened 240 → 190 KB.
Lighthouse was re-measured locally against a production build (headless Chrome, mobile profile, median of the warm runs):
performance 94 (was 93), accessibility 100, SEO 92, LCP ~2.9 s (was 3.16 s), CLS 0.005. A deployed-URL measurement is
still open, and `lighthouserc.js` thresholds are unchanged. The first run after `next start` is a cold outlier (0.55,
LCP 30 s) — the reason CI takes the median of three.

### 2.3 Small, self-contained

| Item | What | Size |
|---|---|---|
| `72` D5 | `68` §2.2–2.3's marketing type scale and `--mkt-*` tokens exist in neither `globals.css` nor `docs/web/06-design-system-web.md` — the shipped pages use Tailwind arbitrary values plus the app's tokens. Either land the tokens or record the deviation | small |

---

## 3. Blocked on something other than the company

| Item | Needs |
|---|---|
| `72` W9 — structured data validated with Google's Rich Results tool | a deployed URL |
| `72` W13 — `lifey://invite/<token>` on iOS | an Apple device (the Android side was checked on an emulator on 2026-10-07, LIF-99: see `72` §3.1 W13) |
| `72` W12 — hero/value-block visuals are reproduced UI, not real captures | a seeded demo backend to capture from |
| `72` D3 — never drawn: for-trainers page, app page, download page, the web state frames, the motion + open-questions addendum (`68` §13) | design time |
| `72` D4 — never drawn: the sponsorship-ended card, the price-loading skeleton (both built in code from the spec text) (`69` §13) | design time |

None of these block a release. D3/D4 are worth having so the next change to those surfaces has
something to check itself against, not because anything is broken.

---

## 4. Decided against — do not re-raise without new evidence

Listed so nobody spends an afternoon rediscovering a closed decision:

- **Mobile end-of-onboarding upsell** (`72` D-F7, M8). `PaywallTrigger.onboarding` exists and is
  reachable from nowhere. A user who has not logged a single meal has no evidence Pro is worth
  1 490 Ft; the triggers with real context fire later on their own. The enum value stays so
  reversing this is a one-screen change.
- **A store free trial for mobile Pro** (`69` §12.2). The free tier is the trial.
- **NAV e-invoicing, rewarded ads, referral programme, team/gym accounts, A/B testing, a public
  trainer directory, a blog** — all `63` §6 non-goals, all still non-goals.
- **EUR as a second displayed currency** — see `72` W11: the fix in scope is making the fine
  print true, not building currency negotiation.

---

## 5. How to use this file

When something here is picked up, do the work, then **delete its row** and put the landed note
in the plan that owns it (`72`'s milestone tables, or the numbered doc for that surface). This
file should shrink; if it grows, something is being deferred rather than decided.
