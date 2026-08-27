package com.lifey.superadmin;

/**
 * Published when {@code RoleManagementServiceImpl} actually grants {@code
 * ROLE_TRAINER} (never on the idempotent no-op branch). Consumed
 * synchronously, in the same transaction, by billing's trial-creation
 * listener (docs/landing_page/64-billing-backend-plan.md §4.1) — a trainer
 * who waits three days for approval must still get the full 14-day trial
 * measured from this moment, not from whenever a later request happens to
 * notice the missing subscription row.
 */
public record TrainerRoleGrantedEvent(Long userId) {
}
