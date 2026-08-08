package com.lifey.chat.spi.jdbc;

import com.lifey.chat.spi.ChatNotificationPreferences;
import com.lifey.chat.spi.ChatPushPrefs;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Time;
import java.time.LocalTime;

/**
 * {@link ChatNotificationPreferences} over {@code users} + {@code user_settings} (§4.4).
 *
 * <p><b>One query, left join.</b> The offset lives on {@code users} and the
 * preferences on {@code user_settings}, and the push ladder needs both before it
 * can decide anything — joining them here keeps the hot path at a single round
 * trip. The join has to be a LEFT join: settings rows are created lazily on
 * first access in the monolith, so a user who has never opened the settings
 * screen has no row, and that has to mean "all defaults" rather than "no push".
 * The monolith's {@code ChatPreferencesAdapter} applies exactly the same
 * defaults; if you change one, change both.
 */
@Component
@RequiredArgsConstructor
class JdbcChatNotificationPreferences implements ChatNotificationPreferences {

    private static final String QUERY = """
            select u.utc_offset_minutes,
                   s.chat_push_enabled,
                   s.chat_quiet_hours_start,
                   s.chat_quiet_hours_end,
                   s.language
              from users u
              left join user_settings s on s.user_id = u.id
             where u.id = :id
            """;

    private final JdbcClient jdbcClient;

    @Override
    @Transactional(readOnly = true)
    public ChatPushPrefs load(Long userId) {
        return jdbcClient.sql(QUERY)
                .param("id", userId)
                .query(JdbcChatNotificationPreferences::toPrefs)
                .optional()
                // No user row at all: nothing to notify, but the ladder still
                // has to be handed something. Push stays enabled so the failure
                // mode is a wasted send rather than a silently dropped message.
                .orElseGet(() -> new ChatPushPrefs(true, 0, null, null, false));
    }

    private static ChatPushPrefs toPrefs(ResultSet rs, int rowNum) throws SQLException {
        // getBoolean returns false for SQL NULL, which is the wrong default for
        // a missing settings row — so the null has to be checked explicitly.
        boolean pushEnabled = rs.getObject("chat_push_enabled") == null
                || rs.getBoolean("chat_push_enabled");
        return new ChatPushPrefs(
                pushEnabled,
                rs.getInt("utc_offset_minutes"),
                localTime(rs.getTime("chat_quiet_hours_start")),
                localTime(rs.getTime("chat_quiet_hours_end")),
                "HUNGARIAN".equals(rs.getString("language")));
    }

    private static LocalTime localTime(Time value) {
        return value == null ? null : value.toLocalTime();
    }
}
