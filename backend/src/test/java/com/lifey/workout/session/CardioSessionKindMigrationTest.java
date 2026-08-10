package com.lifey.workout.session;

import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Statement;
import java.time.Instant;
import java.util.HashSet;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * V66__cardio_session_kind.sql (docs/cardio/52-cardio-domain-backend-plan.md §2.1):
 * runs the real migration against a real Postgres and checks the two things a
 * JPA-level test can't — the column *default* (what an insert that predates
 * this column sees) and the CHECK constraint (a DB-level invariant, not just
 * an application-code convention) — see docs/cardio/59-cardio-implementation-plan.md C1.1.
 */
@SpringBootTest
@Testcontainers
class CardioSessionKindMigrationTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    UserRepository userRepository;

    @Autowired
    DataSource dataSource;

    Long userId;

    @BeforeEach
    void seedUser() {
        User user = new User();
        user.setEmail("cardio-session-kind-migration-" + System.nanoTime() + "@example.com");
        user.setPasswordHash("irrelevant");
        user.setCreatedAt(Instant.now());
        user.setRoles(new HashSet<>(List.of(Role.ROLE_USER)));
        userId = userRepository.save(user).getId();
    }

    @Test
    void anInsertThatOmitsSessionKindDefaultsToStrengthWithNoActivityType() throws Exception {
        long id = insertSession("insert into workout_sessions (user_id, started_at) "
                + "values (" + userId + ", now()) returning id");

        try (Connection conn = dataSource.getConnection();
             Statement st = conn.createStatement()) {
            var rs = st.executeQuery(
                    "select session_kind, activity_type from workout_sessions where id = " + id);
            rs.next();
            assertThat(rs.getString("session_kind")).isEqualTo("STRENGTH");
            assertThat(rs.getString("activity_type")).isNull();
        }
    }

    @Test
    void cardioWithAnActivityTypeIsAccepted() throws Exception {
        long id = insertSession("insert into workout_sessions (user_id, started_at, session_kind, activity_type) "
                + "values (" + userId + ", now(), 'CARDIO', 'RUNNING') returning id");

        try (Connection conn = dataSource.getConnection();
             Statement st = conn.createStatement()) {
            var rs = st.executeQuery(
                    "select session_kind, activity_type from workout_sessions where id = " + id);
            rs.next();
            assertThat(rs.getString("session_kind")).isEqualTo("CARDIO");
            assertThat(rs.getString("activity_type")).isEqualTo("RUNNING");
        }
    }

    @Test
    void cardioWithoutAnActivityTypeViolatesTheCheckConstraint() {
        assertThatThrownBy(() -> insertSession(
                "insert into workout_sessions (user_id, started_at, session_kind) "
                        + "values (" + userId + ", now(), 'CARDIO')"))
                .isInstanceOf(SQLException.class)
                .hasMessageContaining("workout_sessions_kind_activity_ck");
    }

    @Test
    void strengthWithAnActivityTypeViolatesTheCheckConstraint() {
        assertThatThrownBy(() -> insertSession(
                "insert into workout_sessions (user_id, started_at, session_kind, activity_type) "
                        + "values (" + userId + ", now(), 'STRENGTH', 'RUNNING')"))
                .isInstanceOf(SQLException.class)
                .hasMessageContaining("workout_sessions_kind_activity_ck");
    }

    private long insertSession(String sql) throws SQLException {
        try (Connection conn = dataSource.getConnection();
             Statement st = conn.createStatement()) {
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
