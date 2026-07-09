"use client";

import { useEffect, useRef, useState } from "react";
import { useTranslations } from "next-intl";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { recipeImageApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";

interface RecipeImageUploaderProps {
  recipeId: number;
}

/**
 * Recipe photo upload/remove inside the recipe editor — mirrors AvatarUploader,
 * including relying on the fetched blob (not a parent-supplied flag) to decide
 * whether a photo exists, so it stays correct across an upload/remove without
 * needing the editor's `recipe` prop to be refreshed mid-session.
 */
export function RecipeImageUploader({ recipeId }: RecipeImageUploaderProps) {
  const t = useTranslations("nutrition.recipeEditor");
  const { show } = useToast();
  const queryClient = useQueryClient();
  const fileInputRef = useRef<HTMLInputElement>(null);

  const { data: blob, isLoading } = useQuery({
    queryKey: queryKeys.recipes.image(recipeId),
    queryFn: () => recipeImageApi.get(recipeId),
    staleTime: 5 * 60 * 1000,
  });

  // Create and revoke the object URL together in one effect (not a useMemo
  // paired with a separate revoke-on-cleanup effect) — under React StrictMode
  // in dev, effects run mount→cleanup→mount, and a cleanup that isn't paired
  // with its own re-creation revokes the URL a still-mounted <img> is using,
  // breaking it with net::ERR_FILE_NOT_FOUND. Coupling both in one effect
  // means the synthetic remount creates a fresh URL rather than reusing (and
  // outliving) the just-revoked one.
  const [objectUrl, setObjectUrl] = useState<string | null>(null);
  useEffect(() => {
    if (!blob) {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setObjectUrl(null);
      return;
    }
    const url = URL.createObjectURL(blob);
    setObjectUrl(url);
    return () => URL.revokeObjectURL(url);
  }, [blob]);

  const uploadMutation = useMutation({
    mutationFn: (file: File) => recipeImageApi.upload(recipeId, file),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.recipes.image(recipeId) });
      queryClient.invalidateQueries({ queryKey: queryKeys.recipes.all() });
      show(t("photoUpdated"), "success");
    },
    onError: () => show(t("photoUploadFailed"), "error"),
  });

  const removeMutation = useMutation({
    mutationFn: () => recipeImageApi.remove(recipeId),
    onSuccess: () => {
      queryClient.setQueryData(queryKeys.recipes.image(recipeId), null);
      queryClient.invalidateQueries({ queryKey: queryKeys.recipes.all() });
      show(t("photoRemoved"), "success");
    },
    onError: () => show(t("photoRemoveFailed"), "error"),
  });

  const busy = uploadMutation.isPending || removeMutation.isPending;

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    e.target.value = ""; // allow re-selecting the same file again later
    if (file) uploadMutation.mutate(file);
  };

  return (
    <div className="flex items-center gap-4">
      <div
        className="relative w-32 h-32 rounded-[var(--r-md)] flex items-center justify-center shrink-0 overflow-hidden"
        style={{ background: "var(--surface-container)" }}
      >
        {objectUrl ? (
          // Blob object URLs aren't compatible with next/image's optimizer.
          // eslint-disable-next-line @next/next/no-img-element
          <img src={objectUrl} alt="" className="w-full h-full object-cover" />
        ) : (
          <span className="material-symbols-rounded text-4xl" style={{ color: "var(--secondary)" }}>
            menu_book
          </span>
        )}
        {busy && (
          <div
            className="absolute inset-0 flex items-center justify-center"
            style={{ background: "rgba(0,0,0,.35)" }}
          >
            <span className="material-symbols-rounded animate-spin text-white text-lg">
              progress_activity
            </span>
          </div>
        )}
      </div>

      <div className="flex gap-2">
        <button
          type="button"
          disabled={busy || isLoading}
          onClick={() => fileInputRef.current?.click()}
          className="h-9 px-4 rounded-[var(--r-input)] text-sm font-semibold transition-opacity disabled:opacity-60"
          style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }}
        >
          {t("changePhoto")}
        </button>
        {blob && (
          <button
            type="button"
            disabled={busy}
            onClick={() => removeMutation.mutate()}
            className="h-9 px-4 rounded-[var(--r-input)] text-sm font-semibold transition-opacity disabled:opacity-60"
            style={{ color: "var(--error)" }}
          >
            {t("removePhoto")}
          </button>
        )}
      </div>

      <input
        ref={fileInputRef}
        type="file"
        accept="image/jpeg,image/png"
        className="hidden"
        onChange={handleFileChange}
      />
    </div>
  );
}
