# Marketing demo dataset and captures (LIF-120)

The marketing site's product pictures - the clients, programme and chat pages in the value blocks of the home and for-trainers pages -
are **captures of the real trainer workspace**, not reproduced HTML/CSS. They are taken from a seeded local backend so that every
picture shows one product with one set of names (`docs/landing_page/72` W12, `68` D-DW1: "one demo dataset").

| File | What it does |
|---|---|
| `seed.mjs` | Seeds a **local** backend and chat service with a demo trainer, five clients, a six-week programme, a schedule from today, four weeks of the main client's weigh-ins, workouts and meals, and a chat thread. Idempotent: it creates only what is missing. |
| `capture.mjs` | Seeds, logs in as the demo trainer and writes `public/marketing/shots/<shot>-<locale>-<theme>.webp` (clients, program, chat × hu, en × dark, light = 12 files, about 1.1 MB). |

## Running it

You need the local stack, as for the backend-dependent e2e specs (`e2e/README.md`):

1. Postgres: `docker compose up -d postgres`
2. Backend on :8080 (the `backend` launch config) and the chat service on :8081 (`chat/`: `./mvnw spring-boot:run`, with `LIFEY_API_INTERNAL_URL=http://localhost:8080`).
3. The web dev server on :3000 **started with `NEXT_PUBLIC_CHAT_BASE_URL=http://localhost:8081/api/v1`** (the `web-chat` launch config).

```bash
cd web
node scripts/marketing-demo/seed.mjs                 # both universes (hu, en); or: seed.mjs hu
node scripts/marketing-demo/capture.mjs              # all 12 images
node scripts/marketing-demo/capture.mjs en light     # one locale, one theme
node scripts/marketing-demo/capture.mjs --png <dir>  # PNG previews to <dir> instead, to look at them
```

**Never run it against a shared database**: it registers accounts, and `ROLE_TRAINER` has no grant API, so it inserts the role
through `pg` (the same as the e2e specs).

## The demo universes

Two parallel ones, because the pages are bilingual and an English UI full of Hungarian exercise names and chat messages is not a
believable product. Each has its own trainer, clients and texts, and each user's `language` setting is set to match; the clients keep
their Hungarian names in both.

| | Hungarian | English |
|---|---|---|
| Trainer | `peter.kovacs@example.com` | `peter.kovacs@example.org` |
| Clients | `anna.szabo@`, `mark.toth@`, `reka.nagy@`, `lilla.horvath@` `example.com` | the same on `example.org` |
| Invited, not answered | `david.kiss@example.com` | `david.kiss@example.org` |
| Password (all) | `LifeyDemo123!` | |

`example.com` and `example.org` are reserved for examples; nothing is ever sent.

## When to regenerate

- **Whenever the trainer pages change** (the clients overview, the programme grid, the chat): the pictures are of the product.
- **Before a launch.** The clients page shows today's date ("Ma · okt. 15., csütörtök") and the logging calendar covers the four weeks
  before the capture, so the pictures date themselves. Re-run `capture.mjs` and commit the files.

## What is *not* captured

- **The phone screens.** The hero, the app page's phone mockups, and the compact mobile versions of the value blocks are still
  reproduced HTML/CSS. Capturing them needs an emulator or a device with a seeded account (`adb`, `emulator-adb-workflow`); the
  trainer pages above are the part a browser can capture.
- **Past occurrences of a schedule.** A schedule cannot start in the past, so history comes from freeform sessions; only today's
  scheduled workout is completed ("1 / 3 this week").

## How the site uses them

`src/components/marketing/home/ProductShot.tsx` renders the dark and the light image of a shot in a browser-window frame; the
stylesheet shows the one that matches the theme (`.product-shot-*` in `globals.css`), and a lazy image that is not displayed is not
fetched. `ClientsShot`, `ProgramShot` and `ChatShot` are thin wrappers. Alt texts are `home.shots.*` in `messages/marketing.*.json`.
`e2e/marketing/product-shots.spec.ts` checks the right language and theme is shown, loaded, and that no other variant is requested.
