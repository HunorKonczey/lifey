/**
 * A relative, same-origin path only — guards against an open-redirect via `?next=`. Shared by the sign-in and the
 * sign-up pages, which both send the visitor on to where they were headed (a trainer request, a join link).
 */
export function safeNextPath(value: string | null): string | null {
  if (!value || !value.startsWith("/") || value.startsWith("//") || value.includes("\\")) return null;
  return value;
}

/** `/login?next=/join/abc` — keeps the destination across the hop between the two auth pages. */
export function withNext(path: string, next: string | null): string {
  const safe = safeNextPath(next);
  return safe ? `${path}?next=${encodeURIComponent(safe)}` : path;
}
