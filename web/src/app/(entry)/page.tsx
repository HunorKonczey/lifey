import { redirect } from "next/navigation";
import { routing } from "@/i18n/routing";

// In practice `proxy.ts` (matcher includes "/") always redirects a bare "/"
// request to the negotiated `/hu` or `/en` before this ever renders — this is
// a defensive fallback for the (unlikely) case proxy is bypassed. It must
// never point at /dashboard: a signed-in visitor hitting "/" is meant to land
// on the marketing home page, not be sent past it (docs/landing_page/65 D-W2).
export default function RootPage() {
  redirect(`/${routing.defaultLocale}`);
}
