-- LIF-107: an optional free-text "qualifications" (végzettség) on the trainer access request, so the super admin
-- deciding on it can see what the applicant trained for. Optional, bounded in the API (500 chars), text here like
-- motivation; no backfill - existing requests simply have none.
alter table trainer_request add column qualifications text;
