package com.lifey.workout.session.cardio;

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
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * V70__cardio_interval_plans.sql, the {@code cardio_splits} half
 * (docs/cardio/60 C7.1): runs the real migration against a real Postgres and
 * checks what a JPA-level test can't — the column *default*, i.e. what a row
 * written before this migration existed (or by a client that doesn't know
 * about intervals) ends up as. Every split that exists today is a per-km
 * split, so it must read back as DISTANCE, with the running split list
 * behaving exactly as it did (docs/cardio/60 §6).
 */
@SpringBootTest
@Testcontainers
class CardioSplitTypeMigrationTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    UserRepository userRepository;

    @Autowired
    DataSource dataSource;

    Long sessionId;

    @BeforeEach
    void seedCardioSession() throws Exception {
        User user = new User();
        user.setEmail("cardio-split-type-migration-" + System.nanoTime() + "@example.com");
        user.setPasswordHash("irrelevant");
        user.setCreatedAt(Instant.now());
        user.setRoles(new HashSet<>(List.of(Role.ROLE_USER)));
        Long userId = userRepository.save(user).getId();

        sessionId = insertReturningId("insert into workout_sessions (user_id, started_at, session_kind, activity_type) "
                + "values (" + userId + ", now(), 'CARDIO', 'RUNNING') returning id");
    }

    @Test
    void aSplitInsertedWithoutASplitTypeIsADistanceSplit() throws Exception {
        // Exactly the shape every pre-V70 row has: index, distance, duration
        // and nothing else.
        long id = insertReturningId("insert into cardio_splits "
                + "(workout_session_id, split_index, distance_meters, duration_seconds) "
                + "values (" + sessionId + ", 0, 1000, 312) returning id");

        try (Connection conn = dataSource.getConnection();
             Statement st = conn.createStatement()) {
            var rs = st.executeQuery(
                    "select split_type, distance_meters, avg_watts, intensity from cardio_splits where id = " + id);
            rs.next();
            assertThat(rs.getString("split_type")).isEqualTo("DISTANCE");
            assertThat(rs.getDouble("distance_meters")).isEqualTo(1000.0);
            assertThat(rs.getObject("avg_watts")).isNull();
            assertThat(rs.getObject("intensity")).isNull();
        }
    }

    @Test
    void anIntervalSplitNeedsNoDistance() throws Exception {
        long id = insertReturningId("insert into cardio_splits "
                + "(workout_session_id, split_index, split_type, duration_seconds, intensity, avg_watts) "
                + "values (" + sessionId + ", 0, 'INTERVAL', 240, 'HARD', 218) returning id");

        try (Connection conn = dataSource.getConnection();
             Statement st = conn.createStatement()) {
            var rs = st.executeQuery(
                    "select split_type, distance_meters, intensity from cardio_splits where id = " + id);
            rs.next();
            assertThat(rs.getString("split_type")).isEqualTo("INTERVAL");
            assertThat(rs.getObject("distance_meters")).isNull();
            assertThat(rs.getString("intensity")).isEqualTo("HARD");
        }
    }

    @Test
    void anUnknownSplitTypeViolatesTheCheckConstraint() {
        assertThatThrownBy(() -> insertReturningId("insert into cardio_splits "
                + "(workout_session_id, split_index, split_type, distance_meters, duration_seconds) "
                + "values (" + sessionId + ", 0, 'LAP', 1000, 300) returning id"))
                .isInstanceOf(SQLException.class)
                .hasMessageContaining("cardio_splits_type_ck");
    }

    private long insertReturningId(String sql) throws SQLException {
        try (Connection conn = dataSource.getConnection();
             Statement st = conn.createStatement()) {
            var rs = st.executeQuery(sql);
            rs.next();
            return rs.getLong(1);
        }
    }
}
