package com.lifey.vitals;

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
import java.time.LocalDate;
import java.util.HashSet;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * V100__daily_vitals.sql (docs/integrations/89 G3.1, D-G8) against a real Postgres, with the repository queries the
 * service relies on:
 * <ul>
 *   <li>one row per user and day, deleted rows included;</li>
 *   <li>the check constraints hold (a value is required, HRV goes with its method, the sanity bounds);</li>
 *   <li>every read is scoped to its owner, and the delta feed returns tombstones while the list does not;</li>
 *   <li>deleting the user removes their vitals.</li>
 * </ul>
 */
@SpringBootTest
@Testcontainers
class DailyVitalsMigrationTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    UserRepository userRepository;

    @Autowired
    DailyVitalsRepository repository;

    @Autowired
    DataSource dataSource;

    Long userId;
    Long otherUserId;

    @BeforeEach
    void seedUsers() {
        userId = seedUser("vitals-a-");
        otherUserId = seedUser("vitals-b-");
    }

    @Test
    void aSecondRowForTheSameDayViolatesTheUniqueConstraint_evenWhenTheFirstIsDeleted() throws Exception {
        insert(day(userId, "2026-11-20", "52", "null", "null", "now()"));

        assertThatThrownBy(() -> insert(day(userId, "2026-11-20", "55", "null", "null", "null")))
                .isInstanceOf(SQLException.class)
                .hasMessageContaining("daily_vitals_user_id_entry_date_unique");
        assertThat(repository.findByUserIdAndDate(userId, LocalDate.parse("2026-11-20"))).isPresent();
    }

    @Test
    void twoUsersMayEachHaveTheSameDay() throws Exception {
        insert(day(userId, "2026-11-20", "52", "null", "null", "null"));

        assertThatCode(() -> insert(day(otherUserId, "2026-11-20", "60", "null", "null", "null")))
                .doesNotThrowAnyException();
    }

    @Test
    void aRowWithNoValueViolatesTheCheckConstraint() {
        assertThatThrownBy(() -> insert(day(userId, "2026-11-20", "null", "null", "null", "null")))
                .isInstanceOf(SQLException.class)
                .hasMessageContaining("daily_vitals_some_value_ck");
    }

    @Test
    void anHrvWithoutItsMethodOrAMethodWithoutAnHrvViolatesTheCheckConstraint() {
        assertThatThrownBy(() -> insert(day(userId, "2026-11-20", "null", "40", "null", "null")))
                .isInstanceOf(SQLException.class)
                .hasMessageContaining("daily_vitals_hrv_method_with_value_ck");
        assertThatThrownBy(() -> insert(day(userId, "2026-11-21", "52", "null", "'SDNN'", "null")))
                .isInstanceOf(SQLException.class)
                .hasMessageContaining("daily_vitals_hrv_method_with_value_ck");
    }

    @Test
    void anUnknownMethodAndOutOfBoundsValuesViolateTheCheckConstraints() {
        assertThatThrownBy(() -> insert(day(userId, "2026-11-20", "null", "40", "'PNN50'", "null")))
                .isInstanceOf(SQLException.class)
                .hasMessageContaining("daily_vitals_hrv_method_ck");
        assertThatThrownBy(() -> insert(day(userId, "2026-11-21", "5", "null", "null", "null")))
                .isInstanceOf(SQLException.class)
                .hasMessageContaining("daily_vitals_resting_hr_ck");
        assertThatThrownBy(() -> insert(day(userId, "2026-11-22", "null", "0", "'RMSSD'", "null")))
                .isInstanceOf(SQLException.class)
                .hasMessageContaining("daily_vitals_hrv_ms_ck");
    }

    @Test
    void readsAreScopedToTheOwnerAndTheFeedCarriesTombstones() throws Exception {
        long live = insert(day(userId, "2026-11-21", "52", "48.5", "'RMSSD'", "null"));
        long deleted = insert(day(userId, "2026-11-20", "54", "null", "null", "now()"));
        long foreign = insert(day(otherUserId, "2026-11-21", "60", "null", "null", "null"));

        assertThat(repository.findAllByUserIdAndDeletedAtIsNullOrderByDateDesc(userId))
                .singleElement()
                .satisfies(v -> {
                    assertThat(v.getId()).isEqualTo(live);
                    assertThat(v.getHrvMethod()).isEqualTo(HrvMethod.RMSSD);
                    assertThat(v.getHrvMs()).isEqualTo(48.5);
                });
        assertThat(repository.findByUserIdAndDeletedAtIsNullAndDateRange(userId,
                LocalDate.parse("2026-11-21"), LocalDate.parse("2026-11-30")))
                .extracting(DailyVitals::getId).containsExactly(live);
        assertThat(repository.findByIdAndUserId(foreign, userId)).isEmpty();

        var feed = repository.findByUserIdAndUpdatedAtGreaterThanEqual(userId, Instant.EPOCH,
                PageRequest.of(0, 50, Sort.by(Sort.Order.asc("updatedAt"), Sort.Order.asc("id"))));
        assertThat(feed.getContent()).extracting(DailyVitals::getId).containsExactlyInAnyOrder(live, deleted);
    }

    @Test
    void deletingTheUserRemovesTheirVitals() throws Exception {
        insert(day(otherUserId, "2026-11-21", "60", "null", "null", "null"));

        try (Connection conn = dataSource.getConnection(); Statement st = conn.createStatement()) {
            st.executeUpdate("delete from users where id = " + otherUserId);
            var rs = st.executeQuery("select count(*) from daily_vitals where user_id = " + otherUserId);
            rs.next();
            assertThat(rs.getInt(1)).isZero();
        }
    }

    private static String day(Long user, String date, String restingHr, String hrvMs, String method, String deletedAt) {
        return "insert into daily_vitals (user_id, entry_date, resting_hr, hrv_ms, hrv_method, deleted_at) values ("
                + user + ", '" + date + "', " + restingHr + ", " + hrvMs + ", " + method + ", " + deletedAt
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
            var rs = st.executeQuery(sql);
            rs.next();
            return rs.getLong(1);
        }
    }
}
