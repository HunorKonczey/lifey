-- A deleted food no longer holds its barcode.
--
-- foods_barcode_idx (V40) is unique over (user_id, barcode) for every row, deleted ones
-- included - and a delete is a soft delete (deleted_at / hidden = true) that keeps the row and
-- its barcode. So once a user deleted a scanned food, scanning the same product again could
-- never be saved: POST /foods answered 409, the mobile outbox parked the create as a permanent
-- failure, and every meal logged with that food waited behind it for good (the web add-food
-- dialog works around it by retrying without the barcode, docs/84 Prompt 7).
--
-- The uniqueness that matters is among foods the user can see, so the index now covers live
-- rows only (the same shape as foods_name_unique_idx, which only covers hidden = false). The
-- tombstone keeps its barcode for the delta feed; nothing looks a deleted food up by it any more
-- (FoodRepository.findByUserIdAndBarcodeAndDeletedAtIsNull).
drop index foods_barcode_idx;
create unique index foods_barcode_idx on foods (user_id, barcode) where deleted_at is null;
