-- A third kind of result card: a meal (LIF-123, docs/chat/83-chat-result-card-plan.md section 10).
-- The kind list is the app own (`com.lifey.chat.dto.MessageCard.Kind`); the check is widened here, as V1001 said it would be.
alter table chat_messages drop constraint chat_messages_card_ck;
alter table chat_messages
    add constraint chat_messages_card_ck
        check ((card_kind is null) = (card_data is null)
            and (card_kind is null or card_kind in ('WORKOUT', 'PR', 'MEAL'))
            and (card_data is null or char_length(card_data) <= 4000));
