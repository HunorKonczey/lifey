package com.lifey.chat.spi;

/**
 * Who is making the current request. Backed by Spring Security's context today;
 * in a standalone chat service it is the same thing read from that service's own
 * JWT filter.
 */
public interface ChatCaller {

    /**
     * @return the authenticated user's id
     * @throws org.springframework.security.core.AuthenticationException if the
     *         request carries no authenticated principal
     */
    Long currentUserId();
}
