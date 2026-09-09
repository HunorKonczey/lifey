"use client";

import Link from "next/link";
import { track } from "@vercel/analytics";

/** The `store_badge_click` event (docs/landing_page/65 §7: props `platform`, `page`). */
export function TrackedStoreBadge({
  platform,
  page,
  className,
  children,
}: {
  platform: "apple" | "google";
  page: string;
  className?: string;
  children: React.ReactNode;
}) {
  return (
    <Link href="/download" className={className} onClick={() => track("store_badge_click", { platform, page })}>
      {children}
    </Link>
  );
}
