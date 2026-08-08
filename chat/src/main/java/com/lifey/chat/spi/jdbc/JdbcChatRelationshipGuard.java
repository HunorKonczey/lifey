package com.lifey.chat.spi.jdbc;

import com.lifey.chat.spi.ChatRelationship;
import com.lifey.chat.spi.ChatRelationshipGuard;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Optional;

/**
 * {@link ChatRelationshipGuard} over {@code trainer_clients} (§4.4) — the
 * authorization basis for every thread.
 *
 * <p><b>This is the single strongest argument for Phase A's shared database</b>
 * (§5.4). The query sees exactly what the monolith sees, with no replication lag
 * and no cache to invalidate, so a revoked relationship stops accepting messages
 * on the very next request. Move to a separate database and this becomes the
 * hardest problem in the whole extraction: every alternative — a cached copy, an
 * event-driven replica, a synchronous call — has a window in which someone can
 * still write to a thread that should already be frozen.
 *
 * <p>The {@code ACTIVE} filter is in the SQL rather than in the caller, so the
 * chat never holds a relationship it still has to check a status on.
 */
@Component
@RequiredArgsConstructor
class JdbcChatRelationshipGuard implements ChatRelationshipGuard {

    private static final String BY_ID = """
            select id, trainer_id, client_id
              from trainer_clients
             where id = :id and status = 'ACTIVE'
            """;

    /**
     * Either direction in one query: the caller may be the peer's trainer or
     * their client, and a 1:1 thread is the same thread whichever way round.
     * One round trip rather than the monolith adapter's two — the derived
     * finders it was built on could not express the symmetry.
     */
    private static final String BETWEEN = """
            select id, trainer_id, client_id
              from trainer_clients
             where status = 'ACTIVE'
               and ((trainer_id = :a and client_id = :b) or (trainer_id = :b and client_id = :a))
             limit 1
            """;

    private final JdbcClient jdbcClient;

    @Override
    @Transactional(readOnly = true)
    public Optional<ChatRelationship> findActive(Long trainerClientId) {
        return jdbcClient.sql(BY_ID)
                .param("id", trainerClientId)
                .query(JdbcChatRelationshipGuard::toRelationship)
                .optional();
    }

    @Override
    @Transactional(readOnly = true)
    public Optional<ChatRelationship> findActiveBetween(Long userId, Long peerUserId) {
        return jdbcClient.sql(BETWEEN)
                .param("a", userId)
                .param("b", peerUserId)
                .query(JdbcChatRelationshipGuard::toRelationship)
                .optional();
    }

    private static ChatRelationship toRelationship(ResultSet rs, int rowNum) throws SQLException {
        return new ChatRelationship(rs.getLong("id"), rs.getLong("trainer_id"), rs.getLong("client_id"));
    }
}
