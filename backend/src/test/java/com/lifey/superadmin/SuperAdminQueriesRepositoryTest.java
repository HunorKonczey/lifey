package com.lifey.superadmin;

import com.lifey.trainer.TrainerClientRepository;
import com.lifey.trainer.TrainerClientStatus;
import com.lifey.trainer.entity.TrainerClient;
import com.lifey.trainer.request.TrainerRequest;
import com.lifey.trainer.request.TrainerRequestRepository;
import com.lifey.trainer.request.TrainerRequestStatus;
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
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * The JPQL behind the super-admin pages (docs/redesign-web/78 W9.b1–b3) against a real Postgres: the
 * {@code member of} role count, the grouped active-client count and the trainer join of the user list, the
 * distinct "clients with a trainer" count, the {@code min} of the oldest pending request, the request queue's
 * {@code join fetch} with its own count query, and the role-audit feeds. Until now these were only exercised
 * by hand against the dev database — the mocked service tests cannot tell whether the query itself is right.
 *
 * <p>One container per class, so counts that are global by nature ({@code member of}, distinct clients) are
 * asserted as deltas, and anything that can be scoped by id is.
 */
@SpringBootTest
@Testcontainers
class SuperAdminQueriesRepositoryTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    UserRepository userRepository;

    @Autowired
    TrainerClientRepository trainerClientRepository;

    @Autowired
    TrainerRequestRepository trainerRequestRepository;

    @Autowired
    RoleAuditLogRepository roleAuditLogRepository;

    // --- W9.b2: the role count ("member of") ----------------------------------------------------------------

    @Test
    void countByRole_countsEveryAccountHoldingTheRole_once_whateverElseItHolds() {
        long trainersBefore = userRepository.countByRole(Role.ROLE_TRAINER);
        long adminsBefore = userRepository.countByRole(Role.ROLE_ADMIN);

        saveUser("role-plain" + System.nanoTime() + "@example.com", Role.ROLE_USER);
        saveUser("role-trainer-a" + System.nanoTime() + "@example.com", Role.ROLE_USER, Role.ROLE_TRAINER);
        saveUser("role-trainer-b" + System.nanoTime() + "@example.com", Role.ROLE_TRAINER);
        saveUser("role-both" + System.nanoTime() + "@example.com", Role.ROLE_USER, Role.ROLE_TRAINER, Role.ROLE_ADMIN);
        saveUser("role-admin" + System.nanoTime() + "@example.com", Role.ROLE_ADMIN);

        assertThat(userRepository.countByRole(Role.ROLE_TRAINER) - trainersBefore)
                .as("three accounts hold the trainer role; the one that also holds ADMIN is not counted twice")
                .isEqualTo(3);
        assertThat(userRepository.countByRole(Role.ROLE_ADMIN) - adminsBefore).isEqualTo(2);
    }

    // --- W9.b1: the user list's trainer lookups ---------------------------------------------------------------

    @Test
    void countByTrainerIds_groupsTheActiveClientsPerTrainer_andLeavesOutTheRest() {
        User busy = saveUser("grp-busy" + System.nanoTime() + "@example.com", Role.ROLE_TRAINER);
        User single = saveUser("grp-single" + System.nanoTime() + "@example.com", Role.ROLE_TRAINER);
        User idle = saveUser("grp-idle" + System.nanoTime() + "@example.com", Role.ROLE_TRAINER);
        User notAsked = saveUser("grp-notasked" + System.nanoTime() + "@example.com", Role.ROLE_TRAINER);
        Instant base = Instant.now().minusSeconds(5_000);

        saveLink(busy, saveUser("grp-c1-" + System.nanoTime() + "@example.com", Role.ROLE_USER), TrainerClientStatus.ACTIVE, base);
        saveLink(busy, saveUser("grp-c2-" + System.nanoTime() + "@example.com", Role.ROLE_USER), TrainerClientStatus.ACTIVE, base);
        saveLink(busy, saveUser("grp-c3-" + System.nanoTime() + "@example.com", Role.ROLE_USER), TrainerClientStatus.REVOKED, base);
        saveLink(busy, saveUser("grp-c4-" + System.nanoTime() + "@example.com", Role.ROLE_USER), TrainerClientStatus.PENDING, base);
        saveLink(single, saveUser("grp-c5-" + System.nanoTime() + "@example.com", Role.ROLE_USER), TrainerClientStatus.ACTIVE, base);
        saveLink(notAsked, saveUser("grp-c6-" + System.nanoTime() + "@example.com", Role.ROLE_USER), TrainerClientStatus.ACTIVE, base);
        saveLink(idle, saveUser("grp-c7-" + System.nanoTime() + "@example.com", Role.ROLE_USER), TrainerClientStatus.EXPIRED, base);

        Map<Long, Long> counts = trainerClientRepository
                .countByTrainerIds(List.of(busy.getId(), single.getId(), idle.getId()), TrainerClientStatus.ACTIVE)
                .stream()
                .collect(Collectors.toMap(
                        TrainerClientRepository.TrainerClientCount::getTrainerId,
                        TrainerClientRepository.TrainerClientCount::getClientCount));

        assertThat(counts)
                .as("only ACTIVE links, grouped per trainer; a trainer with none is absent (the service reads that as 0), "
                        + "and one that was not asked about is never returned")
                .containsOnlyKeys(busy.getId(), single.getId())
                .containsEntry(busy.getId(), 2L)
                .containsEntry(single.getId(), 1L);
    }

    @Test
    void findWithTrainerByClientIds_returnsTheActiveTrainerOfEachClient_withTheTrainerFetched() {
        User trainer = saveUser("with-trainer" + System.nanoTime() + "@example.com", Role.ROLE_TRAINER);
        User former = saveUser("with-former" + System.nanoTime() + "@example.com", Role.ROLE_TRAINER);
        User served = saveUser("with-served" + System.nanoTime() + "@example.com", Role.ROLE_USER);
        User revokedOnly = saveUser("with-revoked" + System.nanoTime() + "@example.com", Role.ROLE_USER);
        User unasked = saveUser("with-unasked" + System.nanoTime() + "@example.com", Role.ROLE_USER);
        Instant base = Instant.now().minusSeconds(5_000);

        saveLink(trainer, served, TrainerClientStatus.ACTIVE, base);
        saveLink(former, served, TrainerClientStatus.REVOKED, base);
        saveLink(former, revokedOnly, TrainerClientStatus.REVOKED, base);
        saveLink(trainer, unasked, TrainerClientStatus.ACTIVE, base);

        List<TrainerClient> links = trainerClientRepository.findWithTrainerByClientIds(
                List.of(served.getId(), revokedOnly.getId()), TrainerClientStatus.ACTIVE);

        assertThat(links).hasSize(1);
        assertThat(links.get(0).getClient().getId()).isEqualTo(served.getId());
        // Read outside any session: proves `join fetch` loaded the trainer with the page, not one query per row.
        assertThat(links.get(0).getTrainer().getEmail()).isEqualTo(trainer.getEmail());
    }

    // --- W9.b2: clients with a trainer ------------------------------------------------------------------------

    @Test
    void countDistinctClientsByStatus_countsAClientOnce_howeverManyActiveLinksItHas() {
        long before = trainerClientRepository.countDistinctClientsByStatus(TrainerClientStatus.ACTIVE);
        User t1 = saveUser("dist-t1" + System.nanoTime() + "@example.com", Role.ROLE_TRAINER);
        User t2 = saveUser("dist-t2" + System.nanoTime() + "@example.com", Role.ROLE_TRAINER);
        User both = saveUser("dist-both" + System.nanoTime() + "@example.com", Role.ROLE_USER);
        User one = saveUser("dist-one" + System.nanoTime() + "@example.com", Role.ROLE_USER);
        User gone = saveUser("dist-gone" + System.nanoTime() + "@example.com", Role.ROLE_USER);
        Instant base = Instant.now().minusSeconds(5_000);

        saveLink(t1, both, TrainerClientStatus.ACTIVE, base);
        saveLink(t2, both, TrainerClientStatus.ACTIVE, base);
        saveLink(t1, one, TrainerClientStatus.ACTIVE, base);
        saveLink(t1, gone, TrainerClientStatus.REVOKED, base);

        assertThat(trainerClientRepository.countDistinctClientsByStatus(TrainerClientStatus.ACTIVE) - before)
                .as("two clients with a trainer — the one with two active links counts once, the revoked one not at all")
                .isEqualTo(2);
    }

    // --- W9.b2: the oldest pending request ("min") ---------------------------------------------------------------

    @Test
    void findOldestCreatedAt_isTheMinOfThePendingOnes_andEmptyWhenNoneIsPending() {
        Instant now = Instant.now();
        saveRequest(saveUser("min-approved" + System.nanoTime() + "@example.com", Role.ROLE_USER),
                TrainerRequestStatus.APPROVED, now.minusSeconds(100L * 24 * 3600));
        saveRequest(saveUser("min-rejected" + System.nanoTime() + "@example.com", Role.ROLE_USER),
                TrainerRequestStatus.REJECTED, now.minusSeconds(200L * 24 * 3600));

        assertThat(trainerRequestRepository.findOldestCreatedAt(TrainerRequestStatus.PENDING))
                .as("old decided requests do not make anything \"pending since\"")
                .isEmpty();

        Instant oldest = now.minusSeconds(10L * 24 * 3600).truncatedTo(java.time.temporal.ChronoUnit.MICROS);
        saveRequest(saveUser("min-p1" + System.nanoTime() + "@example.com", Role.ROLE_USER), TrainerRequestStatus.PENDING, now.minusSeconds(3L * 24 * 3600));
        saveRequest(saveUser("min-p2" + System.nanoTime() + "@example.com", Role.ROLE_USER), TrainerRequestStatus.PENDING, oldest);
        saveRequest(saveUser("min-p3" + System.nanoTime() + "@example.com", Role.ROLE_USER), TrainerRequestStatus.PENDING, now.minusSeconds(3600));

        assertThat(trainerRequestRepository.findOldestCreatedAt(TrainerRequestStatus.PENDING)).contains(oldest);
    }

    // --- the request queue: join fetch + its own count query -----------------------------------------------------

    @Test
    void findByStatus_pagesOneStatus_withTheRequesterFetchedAndTheRightTotal() {
        long rejectedBefore = trainerRequestRepository
                .findByStatus(TrainerRequestStatus.REJECTED, PageRequest.of(0, 1)).getTotalElements();
        User[] users = new User[5];
        for (int i = 0; i < users.length; i++) {
            users[i] = saveUser("queue-" + i + "-" + System.nanoTime() + "@example.com", Role.ROLE_USER);
        }
        Instant base = Instant.now().minusSeconds(50_000);
        for (int i = 0; i < 3; i++) {
            saveRequest(users[i], TrainerRequestStatus.REJECTED, base.plusSeconds(i));
        }
        saveRequest(users[3], TrainerRequestStatus.APPROVED, base);
        saveRequest(users[4], TrainerRequestStatus.APPROVED, base.plusSeconds(1));

        Page<TrainerRequest> firstPage = trainerRequestRepository.findByStatus(TrainerRequestStatus.REJECTED, PageRequest.of(0, 2));
        Page<TrainerRequest> everyone = trainerRequestRepository.findByStatus(TrainerRequestStatus.REJECTED, PageRequest.of(0, 100));

        assertThat(firstPage.getTotalElements() - rejectedBefore)
                .as("the count query counts the status, not the table: three rejected, the two approved not included")
                .isEqualTo(3);
        assertThat(firstPage.getContent()).as("a page is as long as asked").hasSize(2);
        assertThat(firstPage.getTotalPages()).isEqualTo((int) Math.ceil(firstPage.getTotalElements() / 2.0));

        Set<String> mine = Set.of(users[0].getEmail(), users[1].getEmail(), users[2].getEmail());
        Set<String> approved = Set.of(users[3].getEmail(), users[4].getEmail());
        for (TrainerRequest request : everyone.getContent()) {
            assertThat(request.getStatus()).isEqualTo(TrainerRequestStatus.REJECTED);
            // Outside a session: only readable because `join fetch` loaded the requester with the page.
            assertThat(approved).doesNotContain(request.getUser().getEmail());
        }
        assertThat(everyone.getContent()).extracting(request -> request.getUser().getEmail()).containsAll(mine);
    }

    // --- W9.b3: the role-audit feeds -----------------------------------------------------------------------------

    @Test
    void auditFeeds_areNewestFirst_tiesBrokenByIdDescending_andThePerUserOneIsScoped() {
        User actor = saveUser("audit-actor" + System.nanoTime() + "@example.com", Role.ROLE_SUPER_ADMIN);
        User target = saveUser("audit-target" + System.nanoTime() + "@example.com", Role.ROLE_USER);
        User other = saveUser("audit-other" + System.nanoTime() + "@example.com", Role.ROLE_USER);
        Instant t0 = Instant.now().minusSeconds(100_000).truncatedTo(java.time.temporal.ChronoUnit.MICROS);

        RoleAuditLog oldest = saveAudit(actor, target, RoleAuditAction.GRANT, t0);
        RoleAuditLog tieFirst = saveAudit(actor, target, RoleAuditAction.REVOKE, t0.plusSeconds(60));
        RoleAuditLog tieSecond = saveAudit(actor, other, RoleAuditAction.GRANT, t0.plusSeconds(60));
        RoleAuditLog newest = saveAudit(actor, target, RoleAuditAction.GRANT, t0.plusSeconds(120));

        List<Long> forTarget = roleAuditLogRepository.findByTargetUserIdOrderByCreatedAtDesc(target.getId())
                .stream().map(RoleAuditLog::getId).toList();
        assertThat(forTarget).as("one person's history only, newest first")
                .containsExactly(newest.getId(), tieFirst.getId(), oldest.getId());

        List<Long> global = roleAuditLogRepository
                .findAllByOrderByCreatedAtDescIdDesc(PageRequest.of(0, 4)).getContent()
                .stream().map(RoleAuditLog::getId).toList();
        assertThat(global).as("the global feed: newest first, and the two entries with the same instant by id, descending")
                .containsExactly(newest.getId(), tieSecond.getId(), tieFirst.getId(), oldest.getId());

        Page<RoleAuditLog> secondPage = roleAuditLogRepository.findAllByOrderByCreatedAtDescIdDesc(PageRequest.of(1, 2));
        assertThat(secondPage.getContent()).extracting(RoleAuditLog::getId)
                .containsExactly(tieFirst.getId(), oldest.getId());
        assertThat(secondPage.getTotalElements()).isGreaterThanOrEqualTo(4);
    }

    // --- helpers ---------------------------------------------------------------------------------------------------

    private User saveUser(String email, Role... roles) {
        User user = new User();
        user.setEmail(email);
        user.setPasswordHash("irrelevant");
        user.setCreatedAt(Instant.now());
        user.setRoles(new HashSet<>(Set.of(roles)));
        return userRepository.save(user);
    }

    private void saveLink(User trainer, User client, TrainerClientStatus status, Instant createdAt) {
        TrainerClient link = new TrainerClient();
        link.setTrainer(trainer);
        link.setClient(client);
        link.setStatus(status);
        link.setCreatedAt(createdAt);
        link.setExpiresAt(createdAt.plusSeconds(86_400));
        trainerClientRepository.save(link);
    }

    private void saveRequest(User user, TrainerRequestStatus status, Instant createdAt) {
        TrainerRequest request = new TrainerRequest();
        request.setUser(user);
        request.setStatus(status);
        request.setCreatedAt(createdAt);
        trainerRequestRepository.save(request);
    }

    private RoleAuditLog saveAudit(User actor, User target, RoleAuditAction action, Instant createdAt) {
        RoleAuditLog log = new RoleAuditLog();
        log.setActorId(actor.getId());
        log.setTargetUserId(target.getId());
        log.setRole(Role.ROLE_TRAINER);
        log.setAction(action);
        log.setCreatedAt(createdAt);
        return roleAuditLogRepository.save(log);
    }
}
