"use client";

import { useQuery } from "@tanstack/react-query";
import { superAdminApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";

const PALETTE = ["#C49A6C", "#8AA0B4", "#B08AC8", "#D8B35A", "#6FA8C4", "#9DAE6B", "#E0915A"];

/**
 * Object URLs cached by user id for the life of the tab (same rationale as
 * ClientAvatar's cache: revoking on unmount breaks the back/forward cache).
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

function colorFor(seed: number) {
  return PALETTE[seed % PALETTE.length];
}

interface UserAvatarProps {
  userId: number;
  email: string;
  hasAvatar: boolean;
  size?: number;
}

export function UserAvatar({ userId, email, hasAvatar, size = 34 }: UserAvatarProps) {
  const { data: blob } = useQuery({
    queryKey: queryKeys.superAdminUsers.avatar(userId),
    queryFn: () => superAdminApi.userAvatar(userId),
    enabled: hasAvatar,
    staleTime: 5 * 60 * 1000,
  });

  const objectUrl = objectUrlFor(userId, blob);

  return (
    <div
      className="rounded-full flex items-center justify-center font-extrabold shrink-0 overflow-hidden"
      style={{ width: size, height: size, background: colorFor(userId), color: "#161611", fontSize: size * 0.36 }}
    >
      {objectUrl ? (
        // Blob object URLs aren't compatible with next/image's optimizer.
        // eslint-disable-next-line @next/next/no-img-element
        <img src={objectUrl} alt="" className="w-full h-full object-cover" />
      ) : (
        email.charAt(0).toUpperCase()
      )}
    </div>
  );
}
