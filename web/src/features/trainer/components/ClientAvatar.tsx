"use client";

import { useQuery } from "@tanstack/react-query";
import { trainerApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";

const PALETTE = ["#C49A6C", "#8AA0B4", "#B08AC8", "#D8B35A", "#6FA8C4", "#9DAE6B", "#E0915A"];

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

function colorFor(seed: number) {
  return PALETTE[seed % PALETTE.length];
}

export function initialsFor(email: string) {
  const local = email.split("@")[0] ?? email;
  const parts = local.split(/[._-]/).filter(Boolean);
  const chars = parts.length >= 2 ? [parts[0][0], parts[1][0]] : [local.slice(0, 2)];
  return chars.join("").toUpperCase().slice(0, 2);
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

  return (
    <div
      className="rounded-full flex items-center justify-center font-extrabold shrink-0 overflow-hidden"
      style={{
        width: size,
        height: size,
        background: colorFor(clientId),
        color: "#161611",
        fontSize: size * 0.36,
      }}
    >
      {objectUrl ? (
        // Blob object URLs aren't compatible with next/image's optimizer.
        // eslint-disable-next-line @next/next/no-img-element
        <img src={objectUrl} alt="" className="w-full h-full object-cover" />
      ) : (
        initialsFor(email)
      )}
    </div>
  );
}
