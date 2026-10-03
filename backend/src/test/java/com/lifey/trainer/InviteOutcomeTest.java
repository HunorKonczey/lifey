package com.lifey.trainer;

import com.lifey.trainer.dto.TrainerInviteHistoryResponse;
import com.lifey.trainer.entity.TrainerClient;
import com.lifey.user.User;
import org.junit.jupiter.api.Test;

import java.time.Instant;

import static org.assertj.core.api.Assertions.assertThat;

/** The outcome table of docs/redesign-web/82 section 2.2, row by row. */
class InviteOutcomeTest {

    private static final Instant NOW = Instant.parse("2026-10-03T12:00:00Z");
    private static final Instant SENT = Instant.parse("2026-10-02T12:00:00Z");
    private static final Instant ANSWERED = Instant.parse("2026-10-02T13:00:00Z");
    private static final Instant ENDED = Instant.parse("2026-10-02T20:00:00Z");

    private static final Instant WINDOW_OPEN = NOW.plusSeconds(3600);
    private static final Instant WINDOW_CLOSED = NOW.minusSeconds(3600);

    @Test
    void pendingInsideItsWindowIsPending() {
        assertThat(InviteOutcome.of(TrainerClientStatus.PENDING, null, WINDOW_OPEN, NOW)).isEqualTo(InviteOutcome.PENDING);
    }

    @Test
    void pendingPastItsWindowIsAlreadyExpired_beforeTheNightlySweepFlipsIt() {
        assertThat(InviteOutcome.of(TrainerClientStatus.PENDING, null, WINDOW_CLOSED, NOW)).isEqualTo(InviteOutcome.EXPIRED);
    }

    @Test
    void activeIsAccepted() {
        assertThat(InviteOutcome.of(TrainerClientStatus.ACTIVE, ANSWERED, WINDOW_CLOSED, NOW)).isEqualTo(InviteOutcome.ACCEPTED);
    }

    @Test
    void declinedAndExpiredMapStraightThrough() {
        assertThat(InviteOutcome.of(TrainerClientStatus.DECLINED, ANSWERED, WINDOW_CLOSED, NOW)).isEqualTo(InviteOutcome.DECLINED);
        assertThat(InviteOutcome.of(TrainerClientStatus.EXPIRED, null, WINDOW_CLOSED, NOW)).isEqualTo(InviteOutcome.EXPIRED);
    }

    @Test
    void revokedWithoutAnAnswerIsAWithdrawnInvite() {
        assertThat(InviteOutcome.of(TrainerClientStatus.REVOKED, null, WINDOW_OPEN, NOW)).isEqualTo(InviteOutcome.CANCELLED);
    }

    @Test
    void revokedAfterAnAnswerIsAnAcceptedInviteWhoseRelationshipLaterEnded_notACancelledOne() {
        assertThat(InviteOutcome.of(TrainerClientStatus.REVOKED, ANSWERED, WINDOW_CLOSED, NOW)).isEqualTo(InviteOutcome.ACCEPTED);
    }

    @Test
    void historyResponse_endedAtIsWhenARevokedRowStoppedBeingLive() {
        TrainerClient ended = row(TrainerClientStatus.REVOKED, ANSWERED, ENDED);
        TrainerInviteHistoryResponse response = TrainerClientMapper.toInviteHistoryResponse(ended, NOW);
        assertThat(response.outcome()).isEqualTo(InviteOutcome.ACCEPTED);
        assertThat(response.endedAt()).isEqualTo(ENDED);
        assertThat(response.respondedAt()).isEqualTo(ANSWERED);
        assertThat(response.clientEmail()).isEqualTo("client@example.com");

        TrainerClient cancelled = row(TrainerClientStatus.REVOKED, null, ENDED);
        TrainerInviteHistoryResponse withdrawn = TrainerClientMapper.toInviteHistoryResponse(cancelled, NOW);
        assertThat(withdrawn.outcome()).isEqualTo(InviteOutcome.CANCELLED);
        assertThat(withdrawn.endedAt()).as("the moment the trainer withdrew it").isEqualTo(ENDED);
        assertThat(withdrawn.respondedAt()).isNull();

        TrainerClient active = row(TrainerClientStatus.ACTIVE, ANSWERED, null);
        assertThat(TrainerClientMapper.toInviteHistoryResponse(active, NOW).endedAt()).isNull();
    }

    private static TrainerClient row(TrainerClientStatus status, Instant respondedAt, Instant revokedAt) {
        User client = new User();
        client.setEmail("client@example.com");
        TrainerClient tc = new TrainerClient();
        tc.setId(7L);
        tc.setClient(client);
        tc.setStatus(status);
        tc.setCreatedAt(SENT);
        tc.setExpiresAt(WINDOW_CLOSED);
        tc.setRespondedAt(respondedAt);
        tc.setRevokedAt(revokedAt);
        return tc;
    }
}
