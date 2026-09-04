package com.lifey.superadmin;

/**
 * Published when {@code RoleManagementServiceImpl} actually grants {@code
 * ROLE_TRAINER} (never on the idempotent no-op branch). Consumed
 * synchronously, in the same transaction, by billing's trial-creation
 * listener (docs/landing_page/64-billing-backend-plan.md §4.1) — a trainer
 * who waits three days for approval must still get the full 14-day trial
 * measured from this moment, not from whenever a later request happens to
 * notice the missing subscription row. Also consumed by {@code
 * TrainerRequestResolutionListener} (docs/landing_page/66-trainer-billing-web-plan.md
 * §2), which is why {@code actorId} — the granting super admin — travels on
 * the event: that listener needs it for the request row's {@code decided_by},
 * and re-deriving "who granted this" from anywhere else would mean re-reading
 * {@code role_audit_log} just to recover a value already known at publish time.
 */
public record TrainerRoleGrantedEvent(Long userId, Long actorId) {
}
