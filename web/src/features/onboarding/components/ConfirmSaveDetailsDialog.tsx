"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { useMutation } from "@tanstack/react-query";
import { Dialog } from "@/components/ui/Dialog";
import { userDetailsApi } from "@/features/onboarding/api";
import type {
  ActivityLevel, Gender, PrimaryGoal, UserDetailsField, UserDetailsResponse,
} from "@/features/onboarding/types";
import type { UserDetailsFormValues } from "@/features/onboarding/schemas";

interface FieldDiff {
  field: UserDetailsField;
  label: string;
  from: string;
  to: string;
}

interface ConfirmSaveDetailsDialogProps {
  open: boolean;
  original: UserDetailsResponse;
  pending: UserDetailsFormValues;
  currentWeightKg: number;
  onConfirm: (fields: UserDetailsField[]) => void;
  onClose: () => void;
  saving?: boolean;
}

export function ConfirmSaveDetailsDialog({
  open, original, pending, currentWeightKg, onConfirm, onClose, saving,
}: ConfirmSaveDetailsDialogProps) {
  const t = useTranslations("settings");
  const o = useTranslations("onboarding");
  const d = useTranslations("dashboard");

  const genderLabel = (g: Gender) => o(`gender_${g}`);
  const activityLabel = (a: ActivityLevel) => o(`activity_${a}`);
  const goalLabel = (g: PrimaryGoal) => o(`goal_${g}`);

  const diffs: FieldDiff[] = [];
  if (pending.gender !== original.gender) {
    diffs.push({ field: "GENDER", label: o("gender"), from: genderLabel(original.gender), to: genderLabel(pending.gender) });
  }
  if (pending.birthDate !== original.birthDate) {
    diffs.push({ field: "BIRTH_DATE", label: o("birthDate"), from: original.birthDate, to: pending.birthDate });
  }
  if (pending.heightCm !== original.heightCm) {
    diffs.push({ field: "HEIGHT_CM", label: o("height"), from: `${original.heightCm} cm`, to: `${pending.heightCm} cm` });
  }
  if (pending.activityLevel !== original.activityLevel) {
    diffs.push({
      field: "ACTIVITY_LEVEL", label: o("activityLevel"),
      from: activityLabel(original.activityLevel), to: activityLabel(pending.activityLevel),
    });
  }
  if (pending.primaryGoal !== original.primaryGoal) {
    diffs.push({
      field: "PRIMARY_GOAL", label: o("primaryGoal"),
      from: goalLabel(original.primaryGoal), to: goalLabel(pending.primaryGoal),
    });
  }
  const pendingTargetWeight = pending.targetWeightKg ?? null;
  if (pendingTargetWeight !== original.targetWeightKg) {
    diffs.push({
      field: "TARGET_WEIGHT_KG", label: o("targetWeightOptional"),
      from: original.targetWeightKg != null ? `${original.targetWeightKg} kg` : "—",
      to: pendingTargetWeight != null ? `${pendingTargetWeight} kg` : "—",
    });
  }

  const [selected, setSelected] = useState<Set<UserDetailsField>>(new Set(diffs.map((f) => f.field)));

  // Reset selection to "all changed fields" whenever the dialog is (re)opened
  // with a fresh diff — seeded from render (React-recommended pattern for
  // syncing state to a changing prop, same as the profile form seeding above)
  // rather than an effect, so it doesn't trigger a spurious extra render.
  const [seededOpen, setSeededOpen] = useState(false);
  if (open && !seededOpen) {
    setSeededOpen(true);
    setSelected(new Set(diffs.map((f) => f.field)));
  } else if (!open && seededOpen) {
    setSeededOpen(false);
  }

  const previewMutation = useMutation({ mutationFn: userDetailsApi.suggestGoals });
  const preview = previewMutation.data ?? null;

  useEffect(() => {
    if (!open) return;
    const merged = {
      gender: selected.has("GENDER") ? pending.gender : original.gender,
      birthDate: selected.has("BIRTH_DATE") ? pending.birthDate : original.birthDate,
      heightCm: selected.has("HEIGHT_CM") ? pending.heightCm : original.heightCm,
      activityLevel: selected.has("ACTIVITY_LEVEL") ? pending.activityLevel : original.activityLevel,
      primaryGoal: selected.has("PRIMARY_GOAL") ? pending.primaryGoal : original.primaryGoal,
    };
    previewMutation.mutate({ ...merged, weightKg: currentWeightKg });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, selected, currentWeightKg]);

  const toggle = (field: UserDetailsField) => {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(field)) next.delete(field); else next.add(field);
      return next;
    });
  };

  return (
    <Dialog open={open} onClose={onClose} title={t("confirmSaveTitle")}>
      <div className="flex flex-col gap-4">
        {diffs.length === 0 ? (
          <p className="text-sm" style={{ color: "var(--on-surface-variant)" }}>{t("confirmSaveNoChanges")}</p>
        ) : (
          <>
            <p className="text-xs" style={{ color: "var(--on-surface-variant)" }}>{t("confirmSaveIntro")}</p>
            <div className="flex flex-col gap-2">
              {diffs.map((diff) => (
                <label key={diff.field}
                  className="flex items-start gap-3 p-3 rounded-[var(--r-card)] cursor-pointer"
                  style={{ background: "var(--surface-container)" }}>
                  <input type="checkbox" className="mt-1"
                    checked={selected.has(diff.field)}
                    onChange={() => toggle(diff.field)} />
                  <div className="flex flex-col gap-0.5">
                    <span className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>{diff.label}</span>
                    <span className="text-sm">{diff.from} → {diff.to}</span>
                  </div>
                </label>
              ))}
            </div>

            <div>
              <p className="text-xs font-semibold mb-2" style={{ color: "var(--on-surface-variant)" }}>
                {t("recalculatedGoals")}
              </p>
              {previewMutation.isPending || !preview ? (
                <p className="text-sm py-4 text-center" style={{ color: "var(--on-surface-variant)" }}>
                  {o("calculating")}
                </p>
              ) : (
                <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                  {[
                    { label: d("calories"), value: preview.calories, unit: "kcal", color: "var(--metric-kcal)" },
                    { label: d("protein"), value: preview.proteinGrams, unit: "g", color: "var(--metric-protein)" },
                    { label: d("carbs"), value: preview.carbsGrams, unit: "g", color: "var(--metric-carbs)" },
                    { label: d("fat"), value: preview.fatGrams, unit: "g", color: "var(--metric-fat)" },
                    { label: d("water"), value: preview.waterLiters, unit: "L", color: "var(--metric-water)" },
                  ].map((m) => (
                    <div key={m.label} className="flex flex-col gap-0.5 p-2.5 rounded-[var(--r-card)]"
                      style={{ background: "var(--surface-container)" }}>
                      <span className="text-[10px] font-semibold" style={{ color: m.color }}>{m.label}</span>
                      <span className="text-sm font-bold tabular">{m.value} {m.unit}</span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </>
        )}

        <div className="flex gap-3 mt-2">
          <button onClick={onClose}
            className="h-10 px-5 rounded-[var(--r-input)] font-semibold text-sm"
            style={{ background: "var(--surface-container)", color: "var(--on-surface)" }}>
            {t("confirmSaveCancel")}
          </button>
          {diffs.length > 0 && (
            <button
              onClick={() => onConfirm([...selected])}
              disabled={saving || selected.size === 0}
              className="h-10 px-5 rounded-[var(--r-input)] font-semibold text-sm transition-opacity disabled:opacity-60"
              style={{ background: "var(--primary)", color: "#1E1F18" }}>
              {saving ? t("saving") : t("confirmSaveConfirm")}
            </button>
          )}
        </div>
      </div>
    </Dialog>
  );
}
