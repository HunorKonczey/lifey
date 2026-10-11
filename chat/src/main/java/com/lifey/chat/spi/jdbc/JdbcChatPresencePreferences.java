package com.lifey.chat.spi.jdbc;

import com.lifey.chat.spi.ChatPresencePreferences;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.Collection;
import java.util.HashSet;
import java.util.Set;

/**
 * {@link ChatPresencePreferences} over {@code user_settings} (LIF-153) - the same read-only seam as
 * {@link JdbcChatNotificationPreferences}. Only an explicit {@code false} hides a user: a missing settings row is the default,
 * and the default is visible.
 */
@Component
@RequiredArgsConstructor
class JdbcChatPresencePreferences implements ChatPresencePreferences {

    private final JdbcClient jdbcClient;

    @Override
    @Transactional(readOnly = true)
    public Set<Long> hiddenAmong(Collection<Long> userIds) {
        if (userIds.isEmpty()) {
            // `in ()` is a syntax error in Postgres.
            return Set.of();
        }
        return new HashSet<>(jdbcClient.sql("select user_id from user_settings where chat_online_visible = false and user_id in (:ids)")
                .param("ids", userIds)
                .query(Long.class)
                .list());
    }
}
