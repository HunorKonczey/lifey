-- A message can carry a result card: a finished workout or one personal record
-- (docs/chat/83-chat-result-card-plan.md §2.4).
--
-- The card is a validated JSON snapshot in one text column, with its kind beside
-- it so the database can check it. Not jsonb (never queried, §2.4) and not one
-- column per field (a migration per future kind).
--
-- Both columns are null together or set together. The kind list is the app's own
-- (`com.lifey.chat.dto.MessageCard.Kind`); adding a kind means widening this check
-- in a new migration, which is the point of having it.
alter table chat_messages
    add column card_kind varchar(16),
    add column card_data text;

alter table chat_messages
    add constraint chat_messages_card_ck
        check ((card_kind is null) = (card_data is null)
            and (card_kind is null or card_kind in ('WORKOUT', 'PR'))
            and (card_data is null or char_length(card_data) <= 4000));

-- A message must still carry something: text, an image, a card, or a tombstone.
-- The old check is replaced rather than added to, because it is the one that
-- would otherwise reject a card with no caption.
alter table chat_messages drop constraint chat_messages_content_present;
alter table chat_messages
    add constraint chat_messages_content_present
        check (deleted_at is not null or body is not null or attachment_width is not null
            or card_kind is not null);
