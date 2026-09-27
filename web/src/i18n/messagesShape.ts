import en from "../../messages/en.json";
import hu from "../../messages/hu.json";

/**
 * Missing translation = build error (D-W0.8) — a compile-time, not runtime,
 * check that `en.json` and `hu.json` declare exactly the same keys.
 *
 * The literal string *values* don't matter here (that's `messages.test.ts`'s
 * job, which checks ICU-placeholder parity using the actual content and
 * needs real string comparison); only the shape — every string leaf becomes
 * `true` — so a key present in one file and missing from the other fails
 * `npm run typecheck`.
 *
 * This deliberately does **not** use next-intl's documented `AppConfig.
 * Messages` global augmentation, which is the usual way to get typed
 * `useTranslations` keys: the app ships *two* independent message catalogs —
 * these two files for the authenticated app, and `messages/marketing.
 * {en,hu}.json` for the marketing tree (`src/i18n/request.ts`) — sharing the
 * one `next-intl` import, and dozens of existing call sites pass a route- or
 * state-driven `string` rather than a literal key (e.g. the top bar's page
 * title). Declaring `AppConfig.Messages` from this file alone broke both in
 * a trial run: marketing's own valid keys stopped type-checking against a
 * shape that doesn't include them, and every dynamic `t(variable)` call site
 * across the app needed its own cast — 47 files. That's a separate,
 * cross-cutting migration, not a W0.4-sized change.
 *
 * Also why this is a plain `.ts` file, not `messages.d.ts` as first planned:
 * an ambient declaration file can't contain the value-level assignments a
 * mutual-assignability check needs to actually fail compilation.
 */
type Shape<T> = T extends string ? true : { [K in keyof T]: Shape<T[K]> };

type EnShape = Shape<typeof en>;
type HuShape = Shape<typeof hu>;

declare const enAsHuShape: HuShape;
declare const huAsEnShape: EnShape;

// Mutual assignability = the two shapes declare exactly the same keys at
// every level. A key missing from either side fails `npm run typecheck`.
export const enMatchesHuShape: EnShape = enAsHuShape;
export const huMatchesEnShape: HuShape = huAsEnShape;
