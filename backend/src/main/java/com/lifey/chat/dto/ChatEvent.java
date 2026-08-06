package com.lifey.chat.dto;

/**
 * One frame on the SSE stream (docs/chat/40-trainer-chat-plan.md §4.4).
 *
 * <p><b>Only message frames carry an {@code id}.</b> The SSE spec leaves
 * {@code Last-Event-ID} untouched by a frame without one, so keeping the id
 * space equal to {@code chat_messages.id} makes the reconnect cursor mean
 * exactly one thing: "the newest message this client has already seen". The
 * plan sketched a second monotonic sequence for read frames; a receipt is
 * cheap to re-derive from the conversation list on reconnect, and a mixed id
 * space would have made the gap-fill query ambiguous.
 *
 * @param name event name as it appears in {@code event:} — see {@link #MESSAGE},
 *             {@link #READ}, {@link #RESYNC}
 * @param id   value for {@code id:}, or null to leave the client's cursor alone
 * @param data serialized to JSON into {@code data:}
 */
public record ChatEvent(String name, Long id, Object data) {

    public static final String MESSAGE = "message";
    public static final String READ = "read";
    /** "I cannot replay what you missed — reload from REST." */
    public static final String RESYNC = "resync";

    public static ChatEvent message(MessageEventPayload payload) {
        return new ChatEvent(MESSAGE, payload.message().id(), payload);
    }

    public static ChatEvent read(ReadEventPayload payload) {
        return new ChatEvent(READ, null, payload);
    }

    public static ChatEvent resync() {
        return new ChatEvent(RESYNC, null, new ResyncEventPayload("catch-up window exceeded"));
    }
}
