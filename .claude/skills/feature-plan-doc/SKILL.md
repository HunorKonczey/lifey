---
name: feature-plan-doc
description: Write a numbered feature plan under docs/ before implementation starts — the house format used by docs/NN-*-plan.md and the topic folders (cardio/, chat/, watch/, personal_trainer/, web/). Use when a feature is large enough to need decisions recorded before code, when the user asks for a plan or design doc, or when an existing plan needs a new section. Not for one-off code changes, and not for reference documentation of something already built.
---

# Feature plan doc

Every non-trivial feature in this repo starts as a numbered doc under `docs/`,
and the code then refers back to it — migrations, entity javadoc and Dart
comments all cite plan sections by number. A plan that is never referenced was
too vague; a plan section number that appears in three source files is doing
its job.

## 1. Number and place the file

Numbers are a **single global sequence** shared by `docs/` and its topic
subfolders — `docs/39-rest-timer-plan.md` and `docs/cardio/60-...` are the same
series. (Two historical exceptions: `docs/web/` runs its own `01–09` series,
and a few early root numbers are duplicated — `05`, `06`, `15`, `16`. Don't
add to either.) Find the next number:

```bash
ls docs docs/*/ | grep -oE '^[0-9]+' | sort -n | tail -1
```

- **One doc** → `docs/NN-<kebab-topic>-plan.md`.
- **A topic that needs several docs** (backend + mobile + design + web) → its
  own folder, `docs/<topic>/NN-...-plan.md`, with a `README.md` (see §5).
- Sibling doc types in the same series: `NN-...-design-prompt.md` for a
  self-contained brief to the design tool, `NN-...-guide.md` for reference
  material about something already built.

**Language: write plan docs in English.** This holds for every new plan,
including one added to a folder whose older docs are Hungarian
(`docs/personal_trainer/`, `docs/cardio/60`) — that mix is historical, not a
pattern to continue. The single exception is *editing an existing document*:
keep it in the language it is already written in, so no one doc ends up
bilingual. Reply to the user in whatever language they are using; the document
itself is English either way.

## 2. Header block

```markdown
# 39 – Rest Timer

Status: done (all 5 prompts implemented)
Scope: roadmap item #1 (docs/05-improvement-roadmap.md) — backend + mobile
Depends on: docs/15-set-rest-time-plan.md (`performedAt` / `doneAt`, already done)
```

Title is `# NN – Title` with an en dash. `Status:` is kept current as the work
lands — a plan whose status still says "not started" six months after shipping
is worse than no status. Name the surfaces in `Scope:` (backend · mobile ·
watch · web · design), because that is what tells a reader whether the doc
concerns them.

## 3. The skeleton

Two shapes are in use; pick by size.

**Standard (most plans):**

```markdown
## 1. What we're building      — numbered list of the user-visible outcomes,
                                 including what happens when the feature is off
## 2. Key design decisions     — ### 2.1, 2.2 … one decision per heading
## 3. UI spec                  — per screen/widget, naming the actual files
## 4. Order of work            — milestones, then prompt-sized steps
## Prompt 1 — <surface>: <what>
## Prompt 2 — …
## 5. After implementation     — docs to update, follow-ups deferred
```

**Large / multi-surface (cardio, watch, personal_trainer):** add
`## Current state (what already exists)` up front, group steps under milestone
headings (`### 3.1 Milestones`), and mark finished steps with ✅ in place.

Sections that must not be dropped, whichever shape you use:

- **Non-goals (deferred)** — what this feature explicitly does *not* do. Half
  the value of a plan is the scope it refuses.
- **Edge cases** — the ones that will otherwise be discovered in review.
- **Test plan** — what gets a test, at which layer.
- **Suggested PR split** — how this lands in reviewable pieces.
- **Risk checkpoints where a failure would be silent** — the strongest section
  in the existing plans (`docs/cardio/60` §9). List the places where a bug
  produces a wrong number rather than an error: a bad best-effort value that
  lands in the PR list, a sync change that stops bumping `updated_at`. These
  are what reviewers should stare at.

## 4. Write decisions, not intentions

The section headings in a good plan here are *claims*, not topics:

> `### 2.1 The timer is fully derived state — no timer object`
> `### D-C7.1 The interval plan is its own entity; the execution goes into cardio_splits`

Each decision says what was chosen, what it was chosen over, and why — enough
that a reader six months later does not reopen it. Give decisions stable ids
(`D-C7.1`, `M1`, `C6w`) when the doc is large: source comments and other docs
cite those ids, and renumbering breaks the citations.

Reference concrete artefacts: file paths (`log_session_screen.dart,
_RestBanner`), migration versions (`V66+`), endpoints, and other docs with
their section (`docs/15-delta-sync.md §4(c)`).

## 5. Break the work into small iterations

The most common failure of a plan here is steps that are too big. Size them
down aggressively — a plan whose first step is "implement the backend" gives a
reviewer nothing to review and a session nothing it can finish.

Rules for a step:

- **One surface.** Backend, mobile data, mobile UI, watch, web, design — a step
  that spans two of them is two steps. Name the surface in the heading:
  `## Prompt 2 — Mobile data: sync both settings through the offline stack`.
- **One session's work**, implementable and verifiable end to end without the
  next step existing.
- **Independently mergeable.** It leaves `main` working. A step that only makes
  sense once the following one lands is not a step, it is half of one.
- **Its own verification** — which test, which command, what you should see.
- An "and" in the step title is a split waiting to happen.

Group steps into milestones, and make each milestone something you can
actually look at: a demoable slice, not a layer. Two or three milestones of
four to eight small steps beats one milestone of five large ones.

Prefer iterations that ship a narrow version of the whole feature over
iterations that ship a complete layer of it — the first tells you whether the
design works, the second tells you nothing until the last one lands. When the
feature is large, say explicitly which iteration is the smallest thing that
would be worth using, and put everything past it under Non-goals for now.

## 6. Wire it into the surrounding docs

- A topic folder gets a `README.md` with a **reading-order table** — file, what
  it covers, who it is for — plus an iterations/milestones table when there are
  phases. `docs/cardio/README.md` is the model; copy its shape.
- Adding a doc to an existing folder means updating that folder's README table
  in the same change.
- If the feature comes from `docs/07-roadmap.md` or
  `docs/05-improvement-roadmap.md`, link the plan from the roadmap entry.

## 7. Before handing it over

- [ ] Number is the next in the global sequence; filename ends `-plan.md`
- [ ] Header block: Status, Scope (surfaces), Depends on
- [ ] Every design decision heading states the decision, with the rejected
      alternative and the reason
- [ ] Steps are small: one surface, one session, independently mergeable,
      each with its own verification
- [ ] Milestones are demoable slices, not layers
- [ ] Non-goals, edge cases, test plan, PR split, silent-failure risks all present
- [ ] Real file paths, endpoints and migration versions — not placeholders
- [ ] Folder README table updated; roadmap linked if applicable
- [ ] Written in English
