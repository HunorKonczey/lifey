package com.lifey.chat.spi.jdbc;

import com.lifey.chat.spi.ChatUser;
import com.lifey.chat.spi.ChatUserDirectory;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * {@link ChatUserDirectory} over the monolith's {@code users} table (§4.4).
 *
 * <p>Four columns, read-only. The display-name fallback — name if there is one,
 * email otherwise — is applied here, exactly as {@code ChatUserDirectoryAdapter}
 * does it on the monolith side, so both implementations of this port answer the
 * same question the same way.
 */
@Component
@RequiredArgsConstructor
class JdbcChatUserDirectory implements ChatUserDirectory {

    private static final String COLUMNS = "id, first_name, last_name, email";

    private final JdbcClient jdbcClient;

    @Override
    @Transactional(readOnly = true)
    public Optional<ChatUser> find(Long userId) {
        return jdbcClient.sql("select " + COLUMNS + " from users where id = :id")
                .param("id", userId)
                .query(JdbcChatUserDirectory::toChatUser)
                .optional();
    }

    @Override
    @Transactional(readOnly = true)
    public Map<Long, ChatUser> findAll(Collection<Long> userIds) {
        if (userIds.isEmpty()) {
            // `in ()` is a syntax error in Postgres, and a round trip to learn
            // nothing is a waste on the empty conversation list.
            return Map.of();
        }
        List<ChatUser> users = jdbcClient.sql("select " + COLUMNS + " from users where id in (:ids)")
                .param("ids", userIds)
                .query(JdbcChatUserDirectory::toChatUser)
                .list();
        return users.stream().collect(Collectors.toMap(ChatUser::id, Function.identity()));
    }

    private static ChatUser toChatUser(java.sql.ResultSet rs, int rowNum) throws java.sql.SQLException {
        String email = rs.getString("email");
        return new ChatUser(rs.getLong("id"), displayName(rs.getString("first_name"),
                rs.getString("last_name"), email), email);
    }

    private static String displayName(String firstName, String lastName, String email) {
        String name = ((firstName == null ? "" : firstName) + " " + (lastName == null ? "" : lastName)).trim();
        return name.isEmpty() ? email : name;
    }
}
