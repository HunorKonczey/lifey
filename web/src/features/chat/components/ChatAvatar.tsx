"use client";

import { useQuery } from "@tanstack/react-query";
import { queryKeys } from "@/lib/api/queryKeys";
import { chatApi } from "../api";

const PALETTE = ["#C49A6C", "#8AA0B4", "#B08AC8", "#D8B35A", "#6FA8C4", "#9DAE6B", "#E0915A"];

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

  return (
    <div
      aria-hidden
      className="rounded-full flex items-center justify-center font-extrabold shrink-0 overflow-hidden"
      style={{
        width: size,
        height: size,
        background: muted ? "var(--surface-high)" : PALETTE[userId % PALETTE.length],
        color: muted ? "var(--on-surface-variant)" : "#161611",
        fontSize: size * 0.33,
      }}
    >
      {objectUrl ? (
        // Blob object URLs aren't compatible with next/image's optimizer.
        // eslint-disable-next-line @next/next/no-img-element
        <img
          src={objectUrl}
          alt=""
          className="w-full h-full object-cover"
          // The archived row is muted as a whole; the picture follows it rather
          // than staying the one bright thing in a greyed-out line.
          style={{ opacity: muted ? 0.45 : 1 }}
        />
      ) : (
        initialsFromName(displayName)
      )}
    </div>
  );
}
