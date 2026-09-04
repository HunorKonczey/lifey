/// Where a paywall visit originated — changes only the paywall's headline
/// and highlighted benefit (`docs/landing_page/67-mobile-free-pro-plan.md`
/// §4.3); the rest of the screen is identical (D-DM2).
enum PaywallTrigger {
  historyRange,
  aiCredits,
  adRemoval,
  settings,
  onboarding,
}
