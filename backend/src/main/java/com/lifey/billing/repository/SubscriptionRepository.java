package com.lifey.billing.repository;

import com.lifey.billing.entity.Subscription;
import com.lifey.billing.entity.SubscriptionProvider;
import com.lifey.billing.entity.SubscriptionStatus;
import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface SubscriptionRepository extends JpaRepository<Subscription, Long> {

    List<Subscription> findByUserId(Long userId);

    Optional<Subscription> findByUserIdAndProvider(Long userId, SubscriptionProvider provider);

    /**
     * {@code SELECT … FOR UPDATE} on the trainer's subscription row — the
     * concurrent-accept re-check (docs/landing_page/64-billing-backend-plan.md
     * §4.3, 63 §7.6): two clients accepting the last seat at once must not
     * both win. Must be called from inside the same transaction that then
     * mutates the accepted {@code TrainerClient} row, so the lock is actually
     * held across both reads.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select s from Subscription s where s.user.id = :trainerId and s.provider = com.lifey.billing.entity.SubscriptionProvider.STRIPE")
    Optional<Subscription> lockTrainerSubscriptionForUpdate(@Param("trainerId") Long trainerId);

    Optional<Subscription> findByProviderAndProviderSubscriptionId(SubscriptionProvider provider, String providerSubscriptionId);

    /** Used by the {@code charge.refunded} handler, which carries a customer id but no subscription id. */
    Optional<Subscription> findByProviderAndProviderCustomerId(SubscriptionProvider provider, String providerCustomerId);

    /**
     * The subscriptions of every trainer who currently holds this user as an
     * ACTIVE client — the "sponsoring trainers" half of {@code
     * EntitlementService.resolve} (docs/landing_page/64-billing-backend-plan.md
     * D-B3, 63 §3 item 3). Combined with {@link #findByUserId}, this is the
     * resolver's whole "at most two queries" read.
     */
    @Query("select s from Subscription s join TrainerClient tc on tc.trainer.id = s.user.id "
            + "where tc.client.id = :clientId and tc.status = com.lifey.trainer.TrainerClientStatus.ACTIVE")
    List<Subscription> findSponsoringSubscriptionsForActiveClient(@Param("clientId") Long clientId);

    /** The reconciliation job's trial-expiry sweep (64 §7 step 3). */
    List<Subscription> findByStatusAndTrialEndsAtBefore(SubscriptionStatus status, Instant before);

    /**
     * The reconciliation job's provider re-fetch sweep (64 §7 steps 1-2, Prompt 11) —
     * every non-terminal row that's actually linked to a provider (a {@code TRIALING}
     * row from {@code startTrainerTrial} that never converted has no {@code
     * providerSubscriptionId} yet, so there's nothing to re-fetch). {@code pageable}
     * is the per-run cap (§7's rate limit), not real pagination — the job always reads
     * page 0.
     */
    List<Subscription> findByStatusInAndProviderSubscriptionIdIsNotNull(
            List<SubscriptionStatus> statuses, Pageable pageable);
}
