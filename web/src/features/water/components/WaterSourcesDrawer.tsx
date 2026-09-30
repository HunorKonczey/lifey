"use client";

import { useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { Button, Icon, IconButton, NumberField, TextField } from "@/components/ds";
import { Drawer } from "@/components/ds/overlay/Drawer";
import { useFormat } from "@/lib/format/useFormat";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { useUndoableDelete } from "@/lib/hooks/useUndoableDelete";
import { waterApi } from "../api";
import type { WaterSourceResponse } from "../types";

interface Form {
  /** The source being edited; null = a new one. */
  id: number | null;
  name: string;
  volume: number;
}
const BLANK: Form = { id: null, name: "", volume: 0.25 };

/**
 * "Vízforrások kezelése" (W4.5): the saved sources — a click edits one, "＋" adds one, the bin removes one (undoable) —
 * in a drawer that asks before discarding a half-filled form (Esc / scrim / ×). The quick-add tiles and the dashboard
 * tile are built from these, most used first.
 */
export function WaterSourcesDrawer({ sources, onClose }: { sources: WaterSourceResponse[]; onClose: () => void }) {
  const t = useTranslations("water");
  const common = useTranslations("common");
  const fmt = useFormat();
  const queryClient = useQueryClient();
  const { show } = useToast();
  const undoableDelete = useUndoableDelete();
  const [form, setForm] = useState<Form>(BLANK);

  const original = form.id == null ? BLANK : (() => {
    const s = sources.find((x) => x.id === form.id);
    return s ? { id: s.id, name: s.name, volume: s.volumeLiters } : BLANK;
  })();
  const dirty = form.name.trim() !== original.name || form.volume !== original.volume;

  const saveMutation = useMutation({
    mutationFn: () => {
      const body = { name: form.name.trim(), volumeLiters: form.volume };
      return form.id == null ? waterApi.sources.create(body) : waterApi.sources.update(form.id, body);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.waterSources.all() });
      show(form.id == null ? t("sourceAdded") : t("sourceUpdated"), "success");
      setForm(BLANK);
    },
    onError: () => show(t("addSourceFailed"), "error"),
  });

  const setCached = (update: (list: WaterSourceResponse[]) => WaterSourceResponse[]) =>
    queryClient.setQueryData<WaterSourceResponse[]>(queryKeys.waterSources.all(), (old) => update(old ?? []));
  const removeSource = (source: WaterSourceResponse) => {
    if (form.id === source.id) setForm(BLANK);
    undoableDelete({
      message: t("sourceDeletedUndo", { name: source.name }),
      path: `/water-sources/${source.id}`,
      remove: () => setCached((list) => list.filter((s) => s.id !== source.id)),
      restore: () => setCached((list) => (list.some((s) => s.id === source.id) ? list : [...list, source])),
      errorMessage: t("removeFailed"),
    });
  };

  return (
    <Drawer open onClose={onClose} width={480} title={t("sourcesTitle")} isDirty={dirty}>
      <div className="flex flex-col gap-5" data-testid="water-sources-drawer">
        {sources.length === 0 ? (
          <p className="type-body-s" style={{ color: "var(--text-3)" }}>
            {t("noCustomSources")}
          </p>
        ) : (
          <ul className="flex flex-col gap-2">
            {sources.map((s) => (
              <li key={s.id} className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => setForm({ id: s.id, name: s.name, volume: s.volumeLiters })}
                  className="lifey-button flex min-w-0 flex-1 items-center justify-between gap-3 px-3 py-2.5 text-left"
                  style={{ borderRadius: "var(--r-control)", background: form.id === s.id ? "var(--primary-tint)" : "var(--nested)" }}
                >
                  <span className="type-body-s truncate" style={{ fontWeight: 700 }}>
                    {s.name}
                  </span>
                  <span className="type-body-s tabular" style={{ color: "var(--text-2)" }}>
                    {fmt.litres(s.volumeLiters)}
                  </span>
                </button>
                <IconButton icon="delete" label={t("deleteSourceNamed", { name: s.name })} size={36} onClick={() => removeSource(s)} />
              </li>
            ))}
          </ul>
        )}

        <div className="flex flex-col gap-3 pt-4" style={{ borderTop: "1px solid var(--hairline)" }}>
          <h3 className="type-title-s">{form.id == null ? t("addSource") : t("editSource")}</h3>
          <TextField label={t("sourceName")} value={form.name} onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))} placeholder={t("namePlaceholder")} />
          <NumberField label={t("sourceVolume")} value={form.volume} onChange={(volume) => setForm((f) => ({ ...f, volume }))} unit="L" step={0.05} min={0.05} max={5} maxDecimals={2} />
          <div className="flex gap-2">
            <Button className="flex-1" onClick={() => saveMutation.mutate()} disabled={!form.name.trim() || saveMutation.isPending}>
              <Icon name={form.id == null ? "add" : "check"} size={20} />
              {form.id == null ? t("addSource") : common("save")}
            </Button>
            {form.id != null && (
              <Button variant="secondary" onClick={() => setForm(BLANK)}>
                {common("cancel")}
              </Button>
            )}
          </div>
        </div>
      </div>
    </Drawer>
  );
}
