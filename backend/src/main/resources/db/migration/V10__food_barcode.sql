-- Barcode support for the shared food catalog (V2: barcode scanner + OpenFoodFacts).
-- Foods are NOT user-owned (see V6__ownership.sql), so the barcode is global:
-- a barcode identifies exactly one product across all users. Nullable because
-- manually-entered foods have no barcode. A unique index lets a re-scan resolve
-- to the existing catalog entry and prevents duplicate products; Postgres allows
-- multiple NULLs, so existing barcode-less rows are unaffected.
alter table foods add column barcode varchar(255);

create unique index foods_barcode_idx on foods (barcode);
