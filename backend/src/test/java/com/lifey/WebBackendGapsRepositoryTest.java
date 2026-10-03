package com.lifey;

import com.lifey.auth.entity.RefreshToken;
import com.lifey.auth.repository.RefreshTokenRepository;
import com.lifey.settings.UserSettings;
import com.lifey.settings.UserSettingsRepository;
import com.lifey.trainer.TrainerClientRepository;
import com.lifey.trainer.TrainerClientStatus;
import com.lifey.trainer.entity.TrainerClient;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * The queries and columns of docs/redesign-web/82 against a real Postgres: the role-kind filter (S1), the invite
 * history read (S2), {@code last_active_at} and the activity count (S3), and the goal-attribution columns (S4) — V78..V81
 * going through Flyway and Hibernate's schema validation is part of what this boots.
 */
@SpringBootTest
@Testcontainers
class WebBackendGapsRepositoryTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    UserRepository userRepository;

    @Autowired
    RefreshTokenRepository refreshTokenRepository;

    @Autowired
    TrainerClientRepository trainerClientRepository;

    @Autowired
    UserSettingsRepository userSettingsRepository;

    // --- S1: the role-kind filter ------------------------------------------------------------------------

    @Test
    void roleKindFilter_putsEachUserInExactlyOneKind_withTheTablesPrecedence() {
        String tag = "kind" + System.nanoTime();
        User client = saveUser(tag + "-client@example.com", Role.ROLE_USER);
        User trainer = saveUser(tag + "-trainer@example.com", Role.ROLE_USER, Role.ROLE_TRAINER);
        User admin = saveUser(tag + "-admin@example.com", Role.ROLE_ADMIN);
        User adminTrainer = saveUser(tag + "-admintrainer@example.com", Role.ROLE_USER, Role.ROLE_TRAINER, Role.ROLE_ADMIN);
        User superAdmin = saveUser(tag + "-super@example.com", Role.ROLE_SUPER_ADMIN);

        assertThat(ids(userRepository.findByRoleKind(tag, "USER", PageRequest.of(0, 50)))).containsExactly(client.getId());
        assertThat(ids(userRepository.findByRoleKind(tag, "TRAINER", PageRequest.of(0, 50)))).containsExactly(trainer.getId());
        assertThat(ids(userRepository.findByRoleKind(tag, "ADMIN", PageRequest.of(0, 50))))
                .as("a user who is admin and trainer is one ADMIN row, never also a TRAINER one")
                .containsExactlyInAnyOrder(admin.getId(), adminTrainer.getId(), superAdmin.getId());
    }

    @Test
    void roleKindFilter_withAnEmptySearchStillMatchesEveryone_andPagesCorrectly() {
        String tag = "page" + System.nanoTime();
        for (int i = 0; i < 5; i++) {
            saveUser(tag + "-t" + i + "@example.com", Role.ROLE_USER, Role.ROLE_TRAINER);
        }

        Page<User> firstPage = userRepository.findByRoleKind(tag, "TRAINER", PageRequest.of(0, 2));
        Page<User> everyone = userRepository.findByRoleKind("", "TRAINER", PageRequest.of(0, 500));

        assertThat(firstPage.getTotalElements()).isEqualTo(5);
        assertThat(firstPage.getContent()).hasSize(2);
        assertThat(everyone.getTotalElements()).isGreaterThanOrEqualTo(5);
    }

    // --- S3: last_active_at ------------------------------------------------------------------------------

    @Test
    void touchLastActive_writesOncePerWindow_andNeverMovesTheStampBackwards() {
        User user = saveUser("touch" + System.nanoTime() + "@example.com", Role.ROLE_USER);
        Instant t0 = Instant.parse("2026-10-03T08:00:00Z");
        Instant window = t0.minusSeconds(300);

        assertThat(userRepository.touchLastActive(user.getId(), t0, window)).as("first stamp").isEqualTo(1);
        assertThat(userRepository.findById(user.getId()).orElseThrow().getLastActiveAt()).isEqualTo(t0);

        Instant inside = t0.plusSeconds(120);
        assertThat(userRepository.touchLastActive(user.getId(), inside, inside.minusSeconds(300)))
                .as("inside the window nothing is written").isZero();
        assertThat(userRepository.findById(user.getId()).orElseThrow().getLastActiveAt()).isEqualTo(t0);

        Instant later = t0.plusSeconds(600);
        assertThat(userRepository.touchLastActive(user.getId(), later, later.minusSeconds(300))).isEqualTo(1);
        assertThat(userRepository.findById(user.getId()).orElseThrow().getLastActiveAt()).isEqualTo(later);
    }

    @Test
    void countActiveSince_countsAUserOnEitherSignal_once() {
        Instant since = Instant.now().minusSeconds(30L * 24 * 3600);
        long before = userRepository.countActiveSince(since);

        User stamped = saveUser("act-stamped" + System.nanoTime() + "@example.com", Role.ROLE_USER);
        userRepository.touchLastActive(stamped.getId(), Instant.now(), Instant.now().minusSeconds(300));

        User refreshedOnly = saveUser("act-refresh" + System.nanoTime() + "@example.com", Role.ROLE_USER);
        saveRefreshToken(refreshedOnly, Instant.now().minusSeconds(3600));

        User both = saveUser("act-both" + System.nanoTime() + "@example.com", Role.ROLE_USER);
        userRepository.touchLastActive(both.getId(), Instant.now(), Instant.now().minusSeconds(300));
        saveRefreshToken(both, Instant.now().minusSeconds(60));
        saveRefreshToken(both, Instant.now().minusSeconds(120));

        User stale = saveUser("act-stale" + System.nanoTime() + "@example.com", Role.ROLE_USER);
        userRepository.touchLastActive(stale.getId(), Instant.now().minusSeconds(90L * 24 * 3600), Instant.now());
        saveRefreshToken(stale, Instant.now().minusSeconds(90L * 24 * 3600));

        saveUser("act-never" + System.nanoTime() + "@example.com", Role.ROLE_USER);

        assertThat(userRepository.countActiveSince(since) - before)
                .as("stamped + refreshed-only + both (once, despite two tokens); not the stale one, not the never-seen one")
                .isEqualTo(3);
    }

    // --- S2: the invite history ---------------------------------------------------------------------------

    @Test
    void inviteHistory_listsEveryStatusNewestFirst_scopedToTheTrainer_withTheClientFetched() {
        User trainer = saveUser("hist-trainer" + System.nanoTime() + "@example.com", Role.ROLE_USER, Role.ROLE_TRAINER);
        User otherTrainer = saveUser("hist-other" + System.nanoTime() + "@example.com", Role.ROLE_USER, Role.ROLE_TRAINER);
        User c1 = saveUser("hist-c1-" + System.nanoTime() + "@example.com", Role.ROLE_USER);
        User c2 = saveUser("hist-c2-" + System.nanoTime() + "@example.com", Role.ROLE_USER);
        User c3 = saveUser("hist-c3-" + System.nanoTime() + "@example.com", Role.ROLE_USER);
        User c4 = saveUser("hist-c4-" + System.nanoTime() + "@example.com", Role.ROLE_USER);
        Instant base = Instant.now().minusSeconds(10_000);

        saveInvite(trainer, c1, TrainerClientStatus.EXPIRED, base);
        saveInvite(trainer, c2, TrainerClientStatus.ACTIVE, base.plusSeconds(100));
        saveInvite(trainer, c3, TrainerClientStatus.REVOKED, base.plusSeconds(200));
        saveInvite(trainer, c4, TrainerClientStatus.PENDING, base.plusSeconds(300));
        saveInvite(otherTrainer, c1, TrainerClientStatus.ACTIVE, base.plusSeconds(400));

        Page<TrainerClient> page = trainerClientRepository.findByTrainerIdOrderByCreatedAtDescIdDesc(
                trainer.getId(), PageRequest.of(0, 10));

        assertThat(page.getTotalElements()).isEqualTo(4);
        // Reading the client's e-mail outside any session proves the entity graph fetched it with the page.
        assertThat(page.getContent()).extracting(tc -> tc.getClient().getEmail())
                .containsExactly(c4.getEmail(), c3.getEmail(), c2.getEmail(), c1.getEmail());
        assertThat(page.getContent()).extracting(TrainerClient::getStatus)
                .containsExactly(TrainerClientStatus.PENDING, TrainerClientStatus.REVOKED,
                        TrainerClientStatus.ACTIVE, TrainerClientStatus.EXPIRED);
    }

    // --- S4: the attribution columns ----------------------------------------------------------------------

    @Test
    void goalAttribution_roundTrips_andTheSetByColumnGoesNullWhenThatAccountIsDeleted() {
        User client = saveUser("attr-client" + System.nanoTime() + "@example.com", Role.ROLE_USER);
        User trainer = saveUser("attr-trainer" + System.nanoTime() + "@example.com", Role.ROLE_USER, Role.ROLE_TRAINER);
        Instant setAt = Instant.parse("2026-09-12T08:00:00Z");

        UserSettings settings = new UserSettings();
        settings.setUser(client);
        settings.setDailyCalorieGoal(2200);
        settings.setNutritionGoalsSetBy(trainer.getId());
        settings.setNutritionGoalsSetAt(setAt);
        userSettingsRepository.save(settings);

        UserSettings saved = userSettingsRepository.findByUserId(client.getId()).orElseThrow();
        assertThat(saved.getNutritionGoalsSetBy()).isEqualTo(trainer.getId());
        assertThat(saved.getNutritionGoalsSetAt()).isEqualTo(setAt);

        userRepository.deleteById(trainer.getId());

        UserSettings afterDelete = userSettingsRepository.findByUserId(client.getId()).orElseThrow();
        assertThat(afterDelete.getNutritionGoalsSetBy()).as("on delete set null").isNull();
        assertThat(afterDelete.getNutritionGoalsSetAt()).as("the date survives").isEqualTo(setAt);
        assertThat(afterDelete.getDailyCalorieGoal()).isEqualTo(2200);
    }

    // --- helpers ------------------------------------------------------------------------------------------

    private static List<Long> ids(Page<User> page) {
        return page.getContent().stream().map(User::getId).toList();
    }

    private User saveUser(String email, Role... roles) {
        User user = new User();
        user.setEmail(email);
        user.setPasswordHash("irrelevant");
        user.setCreatedAt(Instant.now());
        user.setRoles(new HashSet<>(Set.of(roles)));
        return userRepository.save(user);
    }

    private void saveRefreshToken(User user, Instant createdAt) {
        RefreshToken token = new RefreshToken();
        token.setUser(user);
        token.setTokenHash(UUID.randomUUID().toString());
        token.setExpiresAt(createdAt.plusSeconds(7L * 24 * 3600));
        token.setCreatedAt(createdAt);
        refreshTokenRepository.save(token);
    }

    private void saveInvite(User trainer, User client, TrainerClientStatus status, Instant createdAt) {
        TrainerClient tc = new TrainerClient();
        tc.setTrainer(trainer);
        tc.setClient(client);
        tc.setStatus(status);
        tc.setCreatedAt(createdAt);
        tc.setExpiresAt(createdAt.plusSeconds(86_400));
        trainerClientRepository.save(tc);
    }
}
