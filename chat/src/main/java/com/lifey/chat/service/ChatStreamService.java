package com.lifey.chat.service;

import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

public interface ChatStreamService {

    /**
     * Open the caller's event stream.
     *
     * @param lastEventId the id of the newest message the client already has,
     *                    from the {@code Last-Event-ID} header — null for a
     *                    fresh client, which loads over REST instead
     */
    SseEmitter open(Long lastEventId);

    /** Record which thread the caller is looking at; null means none (§4.3). */
    void updatePresence(Long activeConversationId);

    /**
     * Tell the other side of a thread that the caller is writing.
     *
     * <p>Lives here rather than on {@code ChatService} because it writes
     * nothing: there is no row, no cursor and no transaction — just a frame on
     * a socket. Throttled server-side, and silently dropped when the peer has
     * no live stream. Never produces a push (§19.4/2).
     */
    void typing(Long conversationId);
}
