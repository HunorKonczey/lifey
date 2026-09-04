-- The marketing site's first-touch attribution (docs/landing_page/65 D-W8,
-- Prompt 10) — a `?src=<page>-<slot>` value or a serialized `utm_*` set,
-- captured client-side into the `lifey_attrib` cookie on a visitor's first
-- marketing-page load and sent back on /auth/register. This is the join
-- key between marketing spend/content and revenue (65 §7): without it,
-- "which page produced paying trainers" is unanswerable months later when
-- a trial converts. Nullable — most users (registered before this landed,
-- or arriving with no query string at all) simply have none.
alter table users
    add column signup_source varchar(255);
