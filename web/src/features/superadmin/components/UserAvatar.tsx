"use client";

import { useQuery } from "@tanstack/react-query";
import { superAdminApi } from "../api";
import { Avatar, colorForSeed } from "@/components/ds";
import { queryKeys } from "@/lib/api/queryKeys";

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

  return <Avatar email={email} size={size} color={colorForSeed(String(userId))} src={objectUrl ?? undefined} />;
}
