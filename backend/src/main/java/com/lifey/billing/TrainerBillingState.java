package com.lifey.billing;

/**
 * A trainer's current standing, derived from their own subscription status
 * and seat count — see docs/landing_page/64-billing-backend-plan.md §4.4.
 */
public enum TrainerBillingState {
    /** Can invite/assign, within their seat limit. */
    OK,
    /** Billing is in an entitling status, but {@code activeClientCount > maxClients} (e.g. a downgrade). Sponsorship still holds. */
    OVER_LIMIT,
    /** No entitling subscription (none, or CANCELED/EXPIRED) — cannot invite or assign. */
    RESTRICTED
}
