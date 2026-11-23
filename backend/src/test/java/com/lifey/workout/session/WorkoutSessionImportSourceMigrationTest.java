package com.lifey.workout.session;

import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
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
 * V97__workout_session_import_source.sql (docs/integrations/89 D-G2, D-G3)
 * runs against a real Postgres here. These checks are about the database
 * itself, which a mocked service test can't see:
 * <ul>
 *   <li>the partial unique index really is the import dedupe key;</li>
 *   <li>the index leaves paired Lifey sessions alone;</li>
 *   <li>soft-deleted imports still count;</li>
 *   <li>the two check constraints hold.</li>
 * </ul>
 */
@SpringBootTest
@Testcontainers
class WorkoutSessionImportSourceMigrationTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    UserRepository userRepository;

    @Autowired
    WorkoutSessionRepository sessionRepository;

    @Autowired
    DataSource dataSource;

    Long userId;
    Long otherUserId;

    @BeforeEach
    void seedUsers() {
        userId = seedUser("import-source-a-");
        otherUserId = seedUser("import-source-b-");
    }

    @Test
    void existingRowsAreLifeyRecordedWithNoProvenance() throws Exception {
        long id = insert("insert into workout_sessions (user_id, started_at) values (" + userId + ", now()) returning id");

        try (Connection conn = dataSource.getConnection(); Statement st = conn.createStatement()) {
            var rs = st.executeQuery("select import_source, import_app_name from workout_sessions where id = " + id);
            rs.next();
            assertThat(rs.getString("import_source")).isNull();
            assertThat(rs.getString("import_app_name")).isNull();
        }
    }

    @Test
    void theSameRecordImportedTwiceForOneUserViolatesTheUniqueIndex() throws Exception {
        insert(importOf(userId, "hc-run-1", null));

        assertThatThrownBy(() -> insert(importOf(userId, "hc-run-1", null)))
                .isInstanceOf(SQLException.class)
                .hasMessageContaining("workout_sessions_user_id_health_workout_id_unique");
    }

    @Test
    void aSoftDeletedImportStillBlocksReImport() throws Exception {
        insert(importOf(userId, "hc-run-2", "now()"));

        assertThatThrownBy(() -> insert(importOf(userId, "hc-run-2", null)))
                .isInstanceOf(SQLException.class)
                .hasMessageContaining("workout_sessions_user_id_health_workout_id_unique");
        assertThat(sessionRepository.existsByUserIdAndHealthWorkoutIdAndImportSourceIsNotNull(userId, "hc-run-2"))
                .isTrue();
    }

    @Test
    void twoUsersMayImportRecordsWithTheSameId() throws Exception {
        insert(importOf(userId, "hc-shared", null));

        assertThatCode(() -> insert(importOf(otherUserId, "hc-shared", null))).doesNotThrowAnyException();
    }

    @Test
    void pairedLifeySessionsAreOutsideTheIndex() throws Exception {
        // A deleted paired session and a new one paired with the same store workout (V15
        // semantics), plus an import of that workout next to them: all three may coexist.
        String paired = "insert into workout_sessions (user_id, started_at, health_workout_id, deleted_at) values ("
                + userId + ", now(), 'hk-paired', %s) returning id";
        insert(paired.formatted("now()"));

        assertThatCode(() -> insert(paired.formatted("null"))).doesNotThrowAnyException();
        assertThatCode(() -> insert(importOf(userId, "hk-paired", null))).doesNotThrowAnyException();
        assertThat(sessionRepository.existsByUserIdAndHealthWorkoutIdAndImportSourceIsNotNull(userId, "hk-paired"))
                .isTrue();
        assertThat(sessionRepository.existsByUserIdAndHealthWorkoutIdAndImportSourceIsNotNull(userId, "hk-unknown"))
                .isFalse();
    }

    @Test
    void anUnknownImportSourceViolatesTheCheckConstraint() {
        assertThatThrownBy(() -> insert("insert into workout_sessions (user_id, started_at, import_source) values ("
                + userId + ", now(), 'STRAVA')"))
                .isInstanceOf(SQLException.class)
                .hasMessageContaining("workout_sessions_import_source_ck");
    }

    @Test
    void anAppNameWithoutASourceViolatesTheCheckConstraint() {
        assertThatThrownBy(() -> insert("insert into workout_sessions (user_id, started_at, import_app_name) values ("
                + userId + ", now(), 'Garmin Connect')"))
                .isInstanceOf(SQLException.class)
                .hasMessageContaining("workout_sessions_import_app_name_ck");
    }

    private static String importOf(Long user, String healthWorkoutId, String deletedAt) {
        return "insert into workout_sessions (user_id, started_at, session_kind, activity_type, health_workout_id, "
                + "import_source, import_app_name, deleted_at) values (" + user + ", now(), 'CARDIO', 'RUNNING', '"
                + healthWorkoutId + "', 'HEALTH', 'Garmin Connect', " + (deletedAt == null ? "null" : deletedAt)
                + ") returning id";
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
