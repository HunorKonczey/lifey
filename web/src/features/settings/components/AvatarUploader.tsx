"use client";

import { useEffect, useMemo, useRef } from "react";
import { useTranslations } from "next-intl";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { avatarApi } from "@/features/settings/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { useSessionStore } from "@/features/auth/store";

/** Profile picture upload/remove for the Settings profile panel — see docs/22-profile-picture-plan.md. */
export function AvatarUploader() {
  const t = useTranslations("settings");
  const { show } = useToast();
  const queryClient = useQueryClient();
  const { user } = useSessionStore();
  const fileInputRef = useRef<HTMLInputElement>(null);

  const { data: blob, isLoading } = useQuery({
    queryKey: queryKeys.settings.avatar(),
    queryFn: avatarApi.get,
    staleTime: 5 * 60 * 1000,
  });

  const objectUrl = useMemo(() => (blob ? URL.createObjectURL(blob) : null), [blob]);

  // Object URLs are only valid client-side and must be revoked once the
  // <img> stops using them, or they'd leak for the life of the tab.
  useEffect(() => {
    return () => {
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [objectUrl]);

  const uploadMutation = useMutation({
    mutationFn: (file: File) => avatarApi.upload(file),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.settings.avatar() });
      show(t("avatarUpdated"), "success");
    },
    onError: () => show(t("avatarUploadFailed"), "error"),
  });

  const removeMutation = useMutation({
    mutationFn: () => avatarApi.remove(),
    onSuccess: () => {
      queryClient.setQueryData(queryKeys.settings.avatar(), null);
      show(t("avatarRemoved"), "success");
    },
    onError: () => show(t("avatarRemoveFailed"), "error"),
  });

  const busy = uploadMutation.isPending || removeMutation.isPending;

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    e.target.value = ""; // allow re-selecting the same file again later
    if (file) uploadMutation.mutate(file);
  };

  const initial = user?.email?.charAt(0).toUpperCase() ?? "?";

  return (
    <div className="flex items-center gap-4">
      <div
        className="relative w-16 h-16 rounded-full flex items-center justify-center text-xl font-bold shrink-0 overflow-hidden"
        style={{ background: "var(--primary)", color: "#1E1F18" }}
      >
        {objectUrl ? (
          // Blob object URLs aren't compatible with next/image's optimizer.
          // eslint-disable-next-line @next/next/no-img-element
          <img src={objectUrl} alt="" className="w-full h-full object-cover" />
        ) : (
          initial
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

      <div className="flex flex-col gap-1.5">
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
        <p className="text-xs" style={{ color: "var(--muted)" }}>
          {t("avatarHint")}
        </p>
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
