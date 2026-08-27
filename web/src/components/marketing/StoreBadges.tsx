import { getTranslations } from "next-intl/server";
import { TrackedStoreBadge } from "./TrackedStoreBadge";

/**
 * Shared "App Store / Google Play" badge pair — the footer (small), the app
 * page (large, its own CTA), and the download page (large, but disabled —
 * see below) all render the same two buttons rather than three hand-rolled
 * copies. Icon + text, not the official store artwork: no real App
 * Store/Play Store listing exists yet (README "M5 — Store & polish"), so
 * there is no real badge asset to embed, and reproducing the official
 * trademarked graphics from scratch for a store presence that doesn't
 * exist would be its own kind of dishonest screenshot (68 D-DW1's
 * reasoning applied to a different asset type).
 *
 * `variant="link"` (footer, app page) points at `/download` — the funnel
 * destination regardless of platform, same as the footer already did.
 * `variant="disabled"` (the download page itself, which can't link to
 * itself) renders the same visual but inert, with a small "coming soon"
 * caption — once a real store URL exists, this is a one-place swap.
 */
export async function StoreBadges({
  size = "sm",
  variant = "link",
  page = "footer",
}: {
  size?: "sm" | "lg";
  variant?: "link" | "disabled";
  /** Which page the badges render on, for the `store_badge_click` event (65 §7). */
  page?: string;
}) {
  const t = await getTranslations("footer");

  const sizeClasses = size === "lg" ? "h-14 px-5 text-sm gap-2.5" : "h-10 px-3.5 text-[13px] gap-2";
  const iconSize = size === "lg" ? "text-xl" : "text-lg";

  const badges = [
    { icon: "apple", platform: "apple" as const, label: t("appStore") },
    { icon: "shop", platform: "google" as const, label: t("googlePlay") },
  ];

  if (variant === "disabled") {
    return (
      <div className="flex flex-col items-center gap-2">
        <div className="flex gap-2.5">
          {badges.map((b) => (
            <div
              key={b.icon}
              aria-disabled="true"
              className={`rounded-md border border-outline flex items-center font-bold ${sizeClasses}`}
              style={{ color: "var(--muted)", opacity: 0.6 }}
            >
              <span className={`material-symbols-rounded ${iconSize}`}>{b.icon}</span>
              {b.label}
            </div>
          ))}
        </div>
        <div className="text-xs font-semibold" style={{ color: "var(--muted)" }}>
          {t("storesComingSoon")}
        </div>
      </div>
    );
  }

  return (
    <div className="flex gap-2.5">
      {badges.map((b) => (
        <TrackedStoreBadge
          key={b.icon}
          platform={b.platform}
          page={page}
          className={`rounded-md border border-outline flex items-center font-bold ${sizeClasses}`}
        >
          <span className={`material-symbols-rounded ${iconSize}`}>{b.icon}</span>
          {b.label}
        </TrackedStoreBadge>
      ))}
    </div>
  );
}
