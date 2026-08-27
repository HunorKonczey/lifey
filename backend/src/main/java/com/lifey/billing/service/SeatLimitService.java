package com.lifey.billing.service;

import com.lifey.billing.TrainerBillingState;
import com.lifey.billing.exception.SeatLimitExceededException;

/**
 * The trainer seat rules (docs/landing_page/64-billing-backend-plan.md §4).
 * Enforcement is wired into the invite and assignment paths as of `64`
 * Prompt 6 — every throwing method here is a deliberate, explicit call at
 * each of those call sites (D-B4), not an interceptor.
 */
public interface SeatLimitService {

    /**
     * The ONE canonical active-client count (63 §8.1) — backed by {@code
     * TrainerClientRepository#countByTrainerIdAndStatus}, the same method the
     * UI reads, so the check and the display can never disagree.
     */
    int activeClientCount(Long trainerId);

    /** {@code activeClientCount(trainerId) < maxClients}, and the trainer's own billing is in an entitling state. */
    boolean canAcquireClient(Long trainerId);

    /** @throws SeatLimitExceededException if {@link #canAcquireClient} would return false. */
    void assertCanAcquireClient(Long trainerId);

    TrainerBillingState state(Long trainerId);

    /**
     * {@code TrainerInviteController} — send invite (§4.3): pending
     * (non-expired) invites count toward the limit too, so a trainer can't
     * queue 40 invites on a 5-seat plan. Deliberately separate from {@link
     * #activeClientCount}, which stays the pure "real client" number the UI
     * displays.
     *
     * @throws SeatLimitExceededException if billing isn't in an entitling
     *                                     state, or active + pending would reach the plan's limit
     */
    void assertCanSendInvite(Long trainerId);

    /**
     * {@code ClientInviteController}/the email accept link — the re-check at
     * accept time (§4.3, 63 §7.6). Takes a {@code SELECT … FOR UPDATE} on the
     * trainer's subscription row first, so two concurrent accepts racing for
     * the last seat can't both win; must be called from inside the same
     * transaction that then mutates the accepted {@code TrainerClient} row.
     *
     * @throws SeatLimitExceededException if billing isn't in an entitling
     *                                     state, or accepting would exceed the plan's limit
     */
    void assertCanAcquireClientForAccept(Long trainerId);

    /**
     * {@code AssignmentController}/{@code ProgramAssignmentController}/
     * {@code WorkoutScheduleController} — new content/programs/schedules are
     * blocked whenever {@link #state} isn't {@code OK} (§4.3, §4.4); read
     * endpoints and chat are never gated by this.
     *
     * @throws SeatLimitExceededException if {@link #state} isn't {@code OK}
     */
    void assertActiveState(Long trainerId);
}
