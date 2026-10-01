"use client";

import { useQuery } from "@tanstack/react-query";
import { trainerApi } from "../api";
import { Avatar, colorForSeed } from "@/components/ds";
import { queryKeys } from "@/lib/api/queryKeys";

/**
 * Object URLs cached by client id, kept alive for the life of the tab instead
 * of being revoked on unmount. Revoking on unmount broke the browser's
 * back/forward cache: navigating back with the mouse/keyboard back button
 * restores the previous page's DOM (including the old <img src="blob:...">)
 * without re-running effects, so a URL revoked on the way out showed as a
 * broken image until a full reload. One URL per client id is a negligible
 * amount of memory to hold onto for a session.
 */
const avatarUrlCache = new Map<number, { blob: Blob; url: string }>();

function objectUrlFor(clientId: number, blob: Blob | null | undefined): string | null {
  if (!blob) return null;
  const cached = avatarUrlCache.get(clientId);
  if (cached && cached.blob === blob) return cached.url;
  if (cached) URL.revokeObjectURL(cached.url);
  const url = URL.createObjectURL(blob);
  avatarUrlCache.set(clientId, { blob, url });
  return url;
}

export function initialsFor(email: string) {
  const local = email.split("@")[0] ?? email;
  const parts = local.split(/[._-]/).filter(Boolean);
  const chars = parts.length >= 2 ? [parts[0][0], parts[1][0]] : [local.slice(0, 2)];
  return chars.join("").toUpperCase().slice(0, 2);
}

/**
 * The client's real name when their profile has one, otherwise a name derived
 * from the email. Deriving it always (the old behaviour) lost every accent —
 * "Réka Tóth" showed up as "Reka Toth".
 */
export function clientDisplayName(c: { clientEmail: string; clientFirstName?: string | null; clientLastName?: string | null }) {
  const full = [c.clientFirstName, c.clientLastName].filter((p) => p && p.trim()).join(" ").trim();
  return full || nameFor(c.clientEmail);
}

export function nameFor(email: string) {
  const local = email.split("@")[0] ?? email;
  return local
    .split(/[._-]/)
    .filter(Boolean)
    .map((p) => p.charAt(0).toUpperCase() + p.slice(1))
    .join(" ");
}

interface ClientAvatarProps {
  clientId: number;
  email: string;
  size?: number;
}

export function ClientAvatar({ clientId, email, size = 42 }: ClientAvatarProps) {
  const { data: blob } = useQuery({
    queryKey: queryKeys.trainerClientData.avatar(clientId),
    queryFn: () => trainerApi.clientAvatar(clientId),
    staleTime: 5 * 60 * 1000,
  });

  const objectUrl = objectUrlFor(clientId, blob);

  // The DS avatar: the per-client metric hue, the photo over it when there is one.
  return <Avatar name={nameFor(email)} email={email} size={size} color={colorForSeed(String(clientId))} src={objectUrl ?? undefined} />;
}
