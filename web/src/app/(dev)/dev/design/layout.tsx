"use client";

import { Providers } from "@/lib/providers";

/** No auth guard, no shell — the gallery is a standalone dev tool (D-W0.12),
 *  not a page inside the app's `(app)`/`(admin)`/`(superadmin)` route groups. */
export default function DevDesignLayout({ children }: { children: React.ReactNode }) {
  return <Providers>{children}</Providers>;
}
