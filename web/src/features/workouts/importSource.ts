import type { WorkoutSessionResponse } from "./types";

/**
 * The name on an imported session's source chip (docs/integrations/89 G1.9), the web counterpart of the mobile
 * `importSourceName`: the app the health store reported, e.g. "Garmin Connect", or null for a session recorded in
 * Lifey. A product name, so it is never translated.
 *
 * The web cannot tell which phone the session came from, so with no app name it falls back to [healthFallback], the
 * caller's translated name for the health store in general.
 */
export function importSourceLabel(
  session: Pick<WorkoutSessionResponse, "importSource" | "importAppName">,
  healthFallback: string,
): string | null {
  if (session.importSource == null) return null;
  const app = session.importAppName?.trim();
  if (app) return app;
  return session.importSource === "GARMIN" ? "Garmin Connect" : healthFallback;
}
