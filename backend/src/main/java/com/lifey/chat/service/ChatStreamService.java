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
}
