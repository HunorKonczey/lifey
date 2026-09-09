-- Every pre-existing ROLE_TRAINER user gets a TRIALING row on deploy day
-- (docs/landing_page/64-billing-backend-plan.md §8, §9 Prompt 7) — otherwise
-- they'd resolve RESTRICTED the moment lifey.billing.enabled flips to true,
-- since TrainerRoleGrantedEvent only fires for grants from this point
-- forward. 30 days, not the normal 14: an existing trainer must not wake up
-- locked out on deploy day, deliberately more generous than a brand-new
-- signup's trial.
insert into subscription (user_id, provider, status, plan, trial_ends_at, created_at, updated_at)
select ur.user_id, 'STRIPE', 'TRIALING', 'PRO', now() + interval '30 days', now(), now()
from user_roles ur
where ur.role = 'ROLE_TRAINER'
  and not exists (
      select 1 from subscription s
      where s.user_id = ur.user_id and s.provider = 'STRIPE'
  );
