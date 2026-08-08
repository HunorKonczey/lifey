package com.lifey.auth;

import com.lifey.chat.spi.ChatCaller;
import org.springframework.security.authentication.InsufficientAuthenticationException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

/**
 * Backs the chat's {@link ChatCaller} port with this service's own security
 * context — the same port the monolith fills from <em>its</em> context, which is
 * what made the move a no-op above the interface
 * (docs/chat/44-chat-service-extraction-plan.md §5.2).
 */
@Component
class ChatCallerAdapter implements ChatCaller {

    @Override
    public Long currentUserId() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated() || !(auth.getPrincipal() instanceof UserPrincipal principal)) {
            throw new InsufficientAuthenticationException("No authenticated user in the current request");
        }
        return principal.id();
    }
}
