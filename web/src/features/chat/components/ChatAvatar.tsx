"use client";

import { useQuery } from "@tanstack/react-query";
import { Avatar, colorForSeed } from "@/components/ds";
import { queryKeys } from "@/lib/api/queryKeys";
import { chatApi } from "../api";

/**
 * Monogram from the peer's display name — the fallback whenever there is no
 * picture to show, which stays the common case for accounts that never set one.
 */
export function initialsFromName(displayName: string): string {
  const parts = displayName.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "?";
  const chars = parts.length >= 2 ? [parts[0][0], parts[1][0]] : [parts[0].slice(0, 2)];
  return chars.join("").toUpperCase().slice(0, 2);
}

/**
 * Object URLs cached by user id and kept for the life of the tab, exactly as
 * `ClientAvatar` does it: revoking on unmount breaks the browser's
 * back/forward cache, which restores the old `<img src="blob:…">` without
 * re-running effects and would show it broken. One URL per peer is nothing.
 */
const avatarUrlCache = new Map<number, { blob: Blob; url: string }>();

function objectUrlFor(userId: number, blob: Blob | null | undefined): string | null {
  if (!blob) return null;
  const cached = avatarUrlCache.get(userId);
  if (cached && cached.blob === blob) return cached.url;
  if (cached) URL.revokeObjectURL(cached.url);
  const url = URL.createObjectURL(blob);
  avatarUrlCache.set(userId, { blob, url });
  return url;
}

interface ChatAvatarProps {
  userId: number;
  displayName: string;
  size?: number;
  /** Archived threads render the whole row muted, monogram included. */
  muted?: boolean;
}

export function ChatAvatar({ userId, displayName, size = 42, muted = false }: ChatAvatarProps) {
  // A picture changes about as often as someone redecorates, so this is fetched
  // once per session and left alone; the chat renders the same handful of peers
  // over and over, and one 404 per peer is the whole cost of having none.
  const { data: blob } = useQuery({
    queryKey: queryKeys.chat.peerAvatar(userId),
    queryFn: () => chatApi.peerAvatar(userId),
    staleTime: 30 * 60 * 1000,
    gcTime: 60 * 60 * 1000,
  });

  const objectUrl = objectUrlFor(userId, blob);

  // The DS monogram (a per-person hue from the metric palette, the same hashing the phone uses) with the peer's picture over it
  // when there is one; an archived row is muted as a whole, picture included.
  return (
    <span className="inline-flex shrink-0" style={{ opacity: muted ? 0.5 : 1 }}>
      <Avatar name={displayName} size={size} color={colorForSeed(displayName)} src={objectUrl ?? undefined} />
    </span>
  );
}
