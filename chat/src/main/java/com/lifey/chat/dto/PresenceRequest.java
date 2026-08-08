package com.lifey.chat.dto;

/**
 * "I am looking at this thread right now" — or, with a null id, "I am not
 * looking at any". This is the input to the §5.1 decision about whether a push
 * is needed at all; clients send it on opening a thread, closing it, and going
 * to the background.
 *
 * <p>Deliberately nullable and unvalidated beyond that: an id the caller does
 * not participate in simply never matches a real conversation, so the worst a
 * bogus value achieves is a push the caller would have got anyway.
 */
public record PresenceRequest(Long activeConversationId) {
}
