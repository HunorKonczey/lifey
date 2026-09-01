/// Shared layout math for placing [BannerAdSlot] and `MainShell`'s
/// floating FAB/cards relative to `AdaptiveBottomNav` (`67` §5.2, `69`
/// §4.4, DV-10). Kept as pure functions — not read off a rendered tree — so
/// the "the slot never overlaps the bottom navigation or a FAB" verify line
/// is a deterministic layout test rather than an eyeball check.
library;

/// `AdaptiveBottomNav`'s own reserved height, excluding the device safe
/// area (58 dp bar + 26 dp bottom gap — see `main_shell.dart`).
const double navSlotHeight = 58.0 + 26.0;

/// Gap kept above whatever sits directly below the FAB (the nav, or the
/// banner when one is showing).
const double fabGap = 16.0;

/// Where [BannerAdSlot] sits, measured from the screen's bottom edge —
/// anchored directly above the nav's own reserved slot (`69` DV-10's
/// "anchored" variant).
double bannerBottom(double safeAreaBottom) => navSlotHeight + safeAreaBottom;

/// Where the FAB (and `TrainerInviteCard`/`UpcomingWorkoutCard`) sit,
/// measured from the screen's bottom edge — above the nav, and above the
/// banner too whenever [bannerHeight] is non-zero, so a shown banner is
/// never covered by the FAB (`67` §5.2: "Never over a FAB").
double fabBottom(double safeAreaBottom, {double bannerHeight = 0}) =>
    navSlotHeight + safeAreaBottom + bannerHeight + fabGap;
