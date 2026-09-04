# Remaining work — landing page & monetization

**Unnumbered on purpose.** `63`–`74` are plans: written once, implemented, then annotated with
what actually landed. This file is the opposite — a working list that changes every time
something is picked up or dropped. Numbering it would imply it is a plan someone should execute
top to bottom, and it is not.

It answers one question: *given that `63`–`74` are done, what is genuinely left?*

Last reviewed: **2026-09-03**, after `72` F1–F5.

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

The biggest one, and it unblocks three separate loose ends at once:

- `72` B1 — the 402/`AI_CREDITS_EXHAUSTED` gate has no AI call path to sit in. The counter, the
  config, the entitlement field and the mobile chip are all built and tested; nothing increments
  the counter because nothing calls an LLM yet.
- `72` M7 — `AiCreditChip` and `requireAiCredits` exist, are tested, and are mounted on no
  screen.
- `72` B4 — Pro's 100/month fair-use ceiling (`63` D-M5) is enforced nowhere; it belongs to
  `AiFeatureGate`, which this feature brings.

`docs/23` now carries the exact call order, the transaction boundary and the status codes the
gate must use (`72` F3 Prompt 14), so the billing side is specified rather than guessed.

### 2.2 Web: first-load JS (`72` W7 / F6)

`/hu` ships ~275 KB gzipped against `65` §8's 100 KB target; Lighthouse 93 / SEO 92 / LCP 3.16 s
against 95 / 100 / 2.5 s. Only ~16 KB of that is marketing-specific — the rest is a shared
root-layout baseline `/login` already paid. The work is `@next/bundle-analyzer` over the root
layout and deferring `<Analytics>`/`<SpeedInsights>` behind an idle callback, then re-measuring
and tightening the CI thresholds in the same commit.

### 2.3 Small, self-contained

| Item | What | Size |
|---|---|---|
| `72` W10 | `sitemap.xml` emits `hu`/`en` alternates but no `x-default` | minutes |
| `72` W11 | The pricing fine print promises prices "forintban vagy euróban … a számlázási országtól függően", but `lib/pricing.ts` carries HUF only and no page shows a EUR figure. Either surface EUR or make the sentence true | small |
| `72` D5 | `68` §2.2–2.3's marketing type scale and `--mkt-*` tokens exist in neither `globals.css` nor `docs/web/06-design-system-web.md` — the shipped pages use Tailwind arbitrary values plus the app's tokens. Either land the tokens or record the deviation | small |
| `72` B5 | No runbook for `BillingReconciliationJob` corrections (`64` §15 asks for one). `73` covers the verification passes, not this | small |
| `72` M10 | 2–4 chat-attachment tests fail on Windows per run — a file-lock race in the test's own temp handling, unrelated to this work but noisy in every full-suite run | small |

---

## 3. Blocked on something other than the company

| Item | Needs |
|---|---|
| `72` W9 — structured data validated with Google's Rich Results tool | a deployed URL |
| `72` W13 — `lifey://invite/<token>` checked on a device with the app installed | a physical device |
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
