package com.lifey.migration;

import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Statement;
import java.time.Duration;
import java.time.Instant;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.within;

/**
 * V75__backfill_trainer_trials.sql (docs/landing_page/64-billing-backend-plan.md
 * §8, §9 Prompt 7's own *Verify* line: "the backfill migration test asserts
 * every pre-existing trainer got 30 days"). Seeds pre-existing rows migrating
 * only up to V74 — same two-phase approach as {@link
 * FoodsExercisesOwnershipMigrationTest} — since a normal {@code
 * @SpringBootTest} would apply V75 before a test method ever gets to seed
 * the "pre-existing" data it's meant to backfill.
 */
@Testcontainers
class BackfillTrainerTrialsMigrationTest {

    static final PostgreSQLContainer POSTGRES =
            new PostgreSQLContainer("postgres:16").withDatabaseName("lifey").withUsername("lifey").withPassword("lifey");

    static Connection connection;

    static long trainerWithoutSubscriptionId;
    static long trainerWithExistingSubscriptionId;
    static long plainUserId;

    @BeforeAll
    static void migrateToPreV75AndSeedExistingTrainers() throws Exception {
        POSTGRES.start();

        Flyway.configure()
                .dataSource(POSTGRES.getJdbcUrl(), POSTGRES.getUsername(), POSTGRES.getPassword())
                .locations("classpath:db/migration")
                .target("74")
                .load()
                .migrate();

        connection = DriverManager.getConnection(POSTGRES.getJdbcUrl(), POSTGRES.getUsername(), POSTGRES.getPassword());
        connection.setAutoCommit(true);

        try (Statement st = connection.createStatement()) {
            trainerWithoutSubscriptionId = insertUser(st, "trainer-no-sub@example.com");
            grantRole(st, trainerWithoutSubscriptionId, "ROLE_TRAINER");

            trainerWithExistingSubscriptionId = insertUser(st, "trainer-with-sub@example.com");
            grantRole(st, trainerWithExistingSubscriptionId, "ROLE_TRAINER");
            st.executeUpdate("insert into subscription (user_id, provider, status, plan, created_at, updated_at) "
                    + "values (" + trainerWithExistingSubscriptionId + ", 'STRIPE', 'ACTIVE', 'PRO', now(), now())");

            plainUserId = insertUser(st, "plain-user@example.com");
            grantRole(st, plainUserId, "ROLE_USER");
        }

        Flyway.configure()
                .dataSource(POSTGRES.getJdbcUrl(), POSTGRES.getUsername(), POSTGRES.getPassword())
                .locations("classpath:db/migration")
                .load()
                .migrate();
    }

    @AfterAll
    static void tearDown() throws Exception {
        if (connection != null) connection.close();
        POSTGRES.stop();
    }

    @Test
    void everyPreExistingTrainerWithoutASubscriptionGetsA30DayTrialingProRow() throws Exception {
        try (PreparedStatement ps = connection.prepareStatement(
                "select status, plan, trial_ends_at, provider from subscription where user_id = ?")) {
            ps.setLong(1, trainerWithoutSubscriptionId);
            try (ResultSet rs = ps.executeQuery()) {
                assertThat(rs.next()).isTrue();
                assertThat(rs.getString("status")).isEqualTo("TRIALING");
                assertThat(rs.getString("plan")).isEqualTo("PRO");
                assertThat(rs.getString("provider")).isEqualTo("STRIPE");
                Instant trialEndsAt = rs.getTimestamp("trial_ends_at").toInstant();
                Instant expected = Instant.now().plus(Duration.ofDays(30));
                assertThat(trialEndsAt).isCloseTo(expected, within(Duration.ofMinutes(5)));
                assertThat(rs.next()).isFalse();
            }
        }
    }

    @Test
    void aTrainerWhoAlreadyHasASubscriptionRowIsNotTouchedOrDuplicated() throws Exception {
        try (PreparedStatement ps = connection.prepareStatement(
                "select status, plan, trial_ends_at from subscription where user_id = ?")) {
            ps.setLong(1, trainerWithExistingSubscriptionId);
            try (ResultSet rs = ps.executeQuery()) {
                assertThat(rs.next()).isTrue();
                assertThat(rs.getString("status")).isEqualTo("ACTIVE");
                assertThat(rs.getString("plan")).isEqualTo("PRO");
                assertThat(rs.getTimestamp("trial_ends_at")).isNull();
                assertThat(rs.next()).isFalse(); // exactly one row — no duplicate inserted
            }
        }
    }

    @Test
    void aPlainNonTrainerUserGetsNoSubscriptionRowAtAll() throws Exception {
        try (PreparedStatement ps = connection.prepareStatement("select count(*) from subscription where user_id = ?")) {
            ps.setLong(1, plainUserId);
            try (ResultSet rs = ps.executeQuery()) {
                rs.next();
                assertThat(rs.getLong(1)).isZero();
            }
        }
    }

    private static long insertUser(Statement st, String email) throws Exception {
        try (ResultSet rs = st.executeQuery(
                "insert into users (email, password_hash, created_at) "
                        + "values ('" + email + "', 'hash', now()) returning id")) {
            rs.next();
            return rs.getLong(1);
        }
    }

    private static void grantRole(Statement st, long userId, String role) throws Exception {
        st.executeUpdate("insert into user_roles (user_id, role) values (" + userId + ", '" + role + "')");
    }
}
