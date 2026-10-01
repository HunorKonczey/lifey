"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { settingsApi } from "./api";
import type { SettingsRequest, SettingsResponse } from "./types";

/**
 * The one reader/writer of `/settings` for the page's sections. `save` merges a partial change onto the loaded
 * response and sends the whole of it — fields this client doesn't model (the other push toggles) round-trip
 * untouched, as the old page did — and shows the new values at once, rolling back (and refetching) if the server says no.
 */
export function useSettings() {
  const t = useTranslations("settings");
  const { show } = useToast();
  const queryClient = useQueryClient();
  const query = useQuery({ queryKey: queryKeys.settings.all(), queryFn: settingsApi.get });

  const mutation = useMutation({
    mutationFn: (body: SettingsRequest) => settingsApi.update(body),
    onMutate: (body) => {
      queryClient.setQueryData<SettingsResponse>(queryKeys.settings.all(), body);
    },
    onSuccess: (saved) => {
      queryClient.setQueryData(queryKeys.settings.all(), saved);
      show(t("settingsSaved"), "success");
    },
    onError: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.settings.all() });
      show(t("saveSettingsFailed"), "error");
    },
  });

  const save = (patch: Partial<SettingsRequest>, options?: { onSuccess?: () => void }) => {
    if (!query.data) return;
    mutation.mutate({ ...query.data, ...patch }, { onSuccess: options?.onSuccess });
  };

  return { settings: query.data, isLoading: query.isLoading, isError: query.isError, refetch: query.refetch, save, saving: mutation.isPending };
}
