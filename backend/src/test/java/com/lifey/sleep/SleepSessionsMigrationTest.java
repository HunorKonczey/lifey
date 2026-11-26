package com.lifey.sleep;

import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Statement;
import java.time.Instant;
import java.util.HashSet;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * V98__sleep_sessions.sql (docs/integrations/89 G2.1, D-G7) against a real Postgres, with the repository queries the
 * service relies on. A mocked service test can't see any of this:
 * <ul>
 *   <li>the unique constraint really is the import dedupe key, soft-deleted rows included;</li>
 *   <li>the check constraints hold;</li>
 *   <li>every read is scoped to its owner;</li>
 *   <li>the delta feed returns tombstones, the list doesn't;</li>
 *   <li>deleting the user removes their sessions.</li>
 * </ul>
 */
@SpringBootTest
@Testcontainers
class SleepSessionsMigrationTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    UserRepository userRepository;

    @Autowired
    SleepSessionRepository repository;

    @Autowired
    DataSource dataSource;

    Long userId;
    Long otherUserId;

    @BeforeEach
    void seedUsers() {
        userId = seedUser("sleep-a-");
        otherUserId = seedUser("sleep-b-");
    }

    @Test
    void theSameRecordImportedTwiceForOneUserViolatesTheUniqueConstraint() throws Exception {
        insert(night(userId, "'hc-sleep-1'", null));

        assertThatThrownBy(() -> insert(night(userId, "'hc-sleep-1'", null)))
                .isInstanceOf(SQLException.class)
                .hasMessageContaining("sleep_sessions_user_id_health_record_id_unique");
    }

    @Test
    void aDeletedNightStillBlocksReImport() throws Exception {
        insert(night(userId, "'hc-sleep-2'", "now()"));

        assertThatThrownBy(() -> insert(night(userId, "'hc-sleep-2'", null)))
                .isInstanceOf(SQLException.class)
                .hasMessageContaining("sleep_sessions_user_id_health_record_id_unique");
        assertThat(repository.existsByUserIdAndHealthRecordId(userId, "hc-sleep-2")).isTrue();
    }

    @Test
    void twoUsersMayHaveRecordsWithTheSameIdAndSessionsWithoutOneAreNeverBlocked() throws Exception {
        insert(night(userId, "'hc-shared'", null));

        assertThatCode(() -> insert(night(otherUserId, "'hc-shared'", null))).doesNotThrowAnyException();
        insert(night(userId, "null", null));
        assertThatCode(() -> insert(night(userId, "null", null))).doesNotThrowAnyException();
        assertThat(repository.existsByUserIdAndHealthRecordId(otherUserId, "hc-unknown")).isFalse();
    }

    @Test
    void anEndBeforeTheStartViolatesTheCheckConstraint() {
        assertThatThrownBy(() -> insert("insert into sleep_sessions (user_id, started_at, ended_at) values ("
                + userId + ", '2026-11-21T06:00:00Z', '2026-11-20T22:00:00Z')"))
                .isInstanceOf(SQLException.class)
                .hasMessageContaining("sleep_sessions_ended_after_started_ck");
    }

    @Test
    void negativeStageMinutesViolateTheCheckConstraint() {
        assertThatThrownBy(() -> insert("insert into sleep_sessions (user_id, started_at, ended_at, rem_minutes) "
                + "values (" + userId + ", '2026-11-20T22:00:00Z', '2026-11-21T06:00:00Z', -1)"))
                .isInstanceOf(SQLException.class)
                .hasMessageContaining("sleep_sessions_minutes_ck");
    }

    @Test
    void readsAreScopedToTheOwnerAndTheFeedCarriesTombstones() throws Exception {
        long live = insert(night(userId, "'hc-live'", null));
        long deleted = insert(night(userId, "'hc-deleted'", "now()"));
        long foreign = insert(night(otherUserId, "'hc-foreign'", null));

        assertThat(repository.findAllByUserIdAndDeletedAtIsNullOrderByEndedAtDesc(userId))
                .extracting(SleepSession::getId).containsExactly(live);
        assertThat(repository.findByIdAndUserId(foreign, userId)).isEmpty();
        assertThat(repository.findByIdAndUserId(live, userId)).isPresent();

        var feed = repository.findByUserIdAndUpdatedAtGreaterThanEqual(userId, Instant.EPOCH,
                PageRequest.of(0, 50, Sort.by(Sort.Order.asc("updatedAt"), Sort.Order.asc("id"))));
        assertThat(feed.getContent()).extracting(SleepSession::getId).containsExactlyInAnyOrder(live, deleted);
        assertThat(feed.getContent()).filteredOn(s -> s.getId() == deleted)
                .singleElement().extracting(SleepSession::getDeletedAt).isNotNull();
    }

    @Test
    void deletingTheUserRemovesTheirSessions() throws Exception {
        insert(night(otherUserId, "'hc-cascade'", null));

        try (Connection conn = dataSource.getConnection(); Statement st = conn.createStatement()) {
            st.executeUpdate("delete from users where id = " + otherUserId);
            var rs = st.executeQuery("select count(*) from sleep_sessions where user_id = " + otherUserId);
            rs.next();
            assertThat(rs.getInt(1)).isZero();
        }
    }

    private static String night(Long user, String healthRecordId, String deletedAt) {
        return "insert into sleep_sessions (user_id, started_at, ended_at, asleep_minutes, deep_minutes, light_minutes, "
                + "rem_minutes, awake_minutes, source_app_name, health_record_id, deleted_at) values (" + user
                + ", '2026-11-20T22:40:00Z', '2026-11-21T06:10:00Z', 420, 80, 230, 110, 30, 'Garmin Connect', "
                + healthRecordId + ", " + (deletedAt == null ? "null" : deletedAt) + ") returning id";
    }

    private Long seedUser(String emailPrefix) {
        User user = new User();
        user.setEmail(emailPrefix + System.nanoTime() + "@example.com");
        user.setPasswordHash("irrelevant");
        user.setCreatedAt(Instant.now());
        user.setRoles(new HashSet<>(List.of(Role.ROLE_USER)));
        return userRepository.save(user).getId();
    }

    private long insert(String sql) throws SQLException {
        try (Connection conn = dataSource.getConnection(); Statement st = conn.createStatement()) {
            if (sql.contains("returning id")) {
                var rs = st.executeQuery(sql);
                rs.next();
                return rs.getLong(1);
            }
            st.executeUpdate(sql);
            return -1;
        }
    }
}
