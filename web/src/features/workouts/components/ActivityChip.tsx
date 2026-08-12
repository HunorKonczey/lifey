import { activityTypeColor, activityTypeIcon } from "../activityType";
import type { ActivityType } from "../types";

/**
 * Round icon badge for an activity type — the web counterpart of the mobile
 * `ActivityChip` (`shared/widgets/activity_chip.dart`). Only two sizes are
 * needed here (24px list row, 40px detail-view header) since the web has no
 * quick-start tile or notification surface — see
 * `docs/cardio/design/Lifey Cardio Design.dc.html` W01.
 *
 * Unlike the mobile version, the background fill is a flat 16% in both
 * themes (mobile splits 14% dark / 16% light) — one rule to remember, per
 * the W01 design note.
 */
export function ActivityChip({
  activityType,
  size = 24,
}: {
  /** One of `ACTIVITY_TYPES`, or the `'STRENGTH'` sentinel for the existing set-based workout. */
  activityType: ActivityType | "STRENGTH" | null | undefined;
  size?: number;
}) {
  const color = activityTypeColor(activityType);
  return (
    <div
      className="flex items-center justify-center rounded-full flex-none"
      style={{ width: size, height: size, background: `color-mix(in srgb, ${color} 16%, transparent)` }}
    >
      <span
        className="material-symbols-rounded"
        style={{ fontSize: Math.round(size * 0.54), color, fontVariationSettings: "'FILL' 1" }}
      >
        {activityTypeIcon(activityType)}
      </span>
    </div>
  );
}
