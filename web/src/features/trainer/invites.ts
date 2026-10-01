export type InviteStatus = "PENDING" | "EXPIRED";

/** A listed invite is pending until its `expiresAt`, then expired — the page can outlive an invite's 24 hours. */
export function inviteStatus(expiresAt: string, now: number): InviteStatus {
  return new Date(expiresAt).getTime() > now ? "PENDING" : "EXPIRED";
}

/** True when a pending invite has under three hours left — its "X left" text turns urgent (heart). */
export function inviteUrgent(expiresAt: string, now: number): boolean {
  const left = new Date(expiresAt).getTime() - now;
  return left > 0 && left < 3 * 60 * 60 * 1000;
}
