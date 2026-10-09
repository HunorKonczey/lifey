import type { InviteOutcome, TrainerInviteHistoryResponse, TrainerInviteResponse } from "./types";

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

/** The history list leaves out PENDING rows: they are already shown, with their actions, in the live list above it. */
export function historyRows(items: readonly TrainerInviteHistoryResponse[]): TrainerInviteHistoryResponse[] {
  return items.filter((i) => i.outcome !== "PENDING");
}

/** Only an invite that lapsed or was withdrawn is worth re-sending; an accepted one is a client already, a declined one a "no". */
export function canResend(outcome: InviteOutcome): boolean {
  return outcome === "EXPIRED" || outcome === "CANCELLED";
}

/** The moment that decided the outcome, for the row's second line. */
export function outcomeAt(row: TrainerInviteHistoryResponse): string {
  switch (row.outcome) {
    case "ACCEPTED":
    case "DECLINED":
      return row.respondedAt ?? row.createdAt;
    case "CANCELLED":
      return row.endedAt ?? row.createdAt;
    default:
      return row.expiresAt;
  }
}

/** Least time between two reminders of one invite, counted from the invite or the last reminder - the backend's own rule. */
export const REMINDER_COOLDOWN_MS = 4 * 60 * 60 * 1000;

/** When the trainer may remind the client of this invite next (LIF-103). */
export function nextReminderAt(invite: Pick<TrainerInviteResponse, "createdAt" | "lastRemindedAt">): number {
  return new Date(invite.lastRemindedAt ?? invite.createdAt).getTime() + REMINDER_COOLDOWN_MS;
}

/** True when a reminder would be accepted now: the invite is still pending and the cooldown has passed. */
export function canRemind(invite: Pick<TrainerInviteResponse, "createdAt" | "lastRemindedAt" | "expiresAt">, now: number): boolean {
  return inviteStatus(invite.expiresAt, now) === "PENDING" && nextReminderAt(invite) <= now;
}

/** The address a trainer shares for a join link: this site's own `/join/<token>`. */
export function joinUrl(origin: string, token: string): string {
  return `${origin}/join/${encodeURIComponent(token)}`;
}
