"use client";

import { useQuery } from "@tanstack/react-query";
import { recipeImageApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";

/**
 * Object URLs cached by recipe id for the life of the tab — same rationale
 * as UserAvatar/ClientAvatar's cache: revoking on unmount breaks the
 * browser's back/forward cache.
 */
const imageUrlCache = new Map<number, { blob: Blob; url: string }>();

function objectUrlFor(recipeId: number, blob: Blob | null | undefined): string | null {
  if (!blob) return null;
  const cached = imageUrlCache.get(recipeId);
  if (cached && cached.blob === blob) return cached.url;
  if (cached) URL.revokeObjectURL(cached.url);
  const url = URL.createObjectURL(blob);
  imageUrlCache.set(recipeId, { blob, url });
  return url;
}

interface RecipeThumbnailProps {
  recipeId: number;
  hasImage: boolean;
  size?: number;
}

/** Recipe photo thumbnail, falling back to the book icon while loading, on error, or when unset. */
export function RecipeThumbnail({ recipeId, hasImage, size = 80 }: RecipeThumbnailProps) {
  const { data: blob } = useQuery({
    queryKey: queryKeys.recipes.image(recipeId),
    queryFn: () => recipeImageApi.get(recipeId),
    enabled: hasImage,
    staleTime: 5 * 60 * 1000,
  });

  const objectUrl = objectUrlFor(recipeId, blob);

  return (
    <div
      className="rounded-[var(--r-md)] flex items-center justify-center shrink-0 overflow-hidden"
      style={{ width: size, height: size, background: "var(--surface-container)" }}
    >
      {objectUrl ? (
        // Blob object URLs aren't compatible with next/image's optimizer.
        // eslint-disable-next-line @next/next/no-img-element
        <img src={objectUrl} alt="" className="w-full h-full object-cover" />
      ) : (
        <span className="material-symbols-rounded" style={{ color: "var(--secondary)", fontSize: size * 0.5 }}>
          menu_book
        </span>
      )}
    </div>
  );
}
