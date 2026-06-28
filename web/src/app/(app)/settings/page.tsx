"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { settingsApi } from "@/features/settings/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { useTheme } from "@/lib/hooks/useTheme";
import { useLocale } from "@/lib/hooks/useLocale";
import { useSessionStore } from "@/features/auth/store";
import { SegmentedControl } from "@/components/ui/SegmentedControl";
import { Skeleton } from "@/components/status/Skeleton";
import { ErrorState } from "@/components/status/ErrorState";
import type {
  SettingsResponse, UnitSystem, ThemePreference, LanguagePreference,
} from "@/features/settings/types";

type Section = "profile" | "goals" | "units" | "theme" | "language" | "security";

const SECTIONS: { value: Section; label: string; icon: string }[] = [
  { value: "profile", label: "Profile", icon: "person" },
  { value: "goals", label: "Daily goals", icon: "target" },
  { value: "units", label: "Units", icon: "straighten" },
  { value: "theme", label: "Theme", icon: "palette" },
  { value: "language", label: "Language", icon: "translate" },
  { value: "security", label: "Security", icon: "shield" },
];

const GOAL_FIELDS: { key: keyof SettingsResponse; label: string; color: string; unit: string }[] = [
  { key: "dailyCalorieGoal", label: "Calories", color: "var(--metric-kcal)", unit: "kcal" },
  { key: "dailyProteinGoal", label: "Protein", color: "var(--metric-protein)", unit: "g" },
  { key: "dailyCarbsGoal", label: "Carbs", color: "var(--metric-carbs)", unit: "g" },
  { key: "dailyFatGoal", label: "Fat", color: "var(--metric-fat)", unit: "g" },
  { key: "dailyWaterGoalLiters", label: "Water", color: "var(--metric-water)", unit: "L" },
  { key: "dailyStepGoal", label: "Steps", color: "var(--metric-steps)", unit: "" },
];

export default function SettingsPage() {
  const queryClient = useQueryClient();
  const { show } = useToast();
  const { setTheme } = useTheme();
  const { setLanguage } = useLocale();
  const { user, logoutAll } = useSessionStore();
  const [section, setSection] = useState<Section>("profile");
  const [form, setForm] = useState<SettingsResponse | null>(null);
  const [seededFrom, setSeededFrom] = useState<SettingsResponse | null>(null);

  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: queryKeys.settings.all(),
    queryFn: settingsApi.get,
  });

  // Seed editable form from query data during render (React-recommended pattern
  // for syncing state to a changing prop/source — avoids setState-in-effect).
  if (data && data !== seededFrom) {
    setSeededFrom(data);
    setForm(data);
  }

  const saveMutation = useMutation({
    mutationFn: (body: SettingsResponse) => settingsApi.update(body),
    onSuccess: (saved) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.settings.all() });
      setForm(saved);
      show("Settings saved", "success");
    },
    onError: () => show("Failed to save settings", "error"),
  });

  if (isLoading || !form) return <Skeleton variant="card" className="h-96" />;
  if (isError) return <ErrorState onRetry={refetch} />;

  const patch = (p: Partial<SettingsResponse>) => setForm((f) => f ? { ...f, ...p } : f);
  const saveImmediate = (p: Partial<SettingsResponse>) => {
    const next = { ...form, ...p };
    setForm(next);
    saveMutation.mutate(next);
  };

  return (
    <div className="flex gap-6">
      {/* Sub-nav */}
      <div className="w-[200px] shrink-0 flex flex-col gap-1">
        {SECTIONS.map((s) => (
          <button key={s.value} onClick={() => setSection(s.value)}
            className="flex items-center gap-3 px-3 py-2.5 rounded-[var(--r-card)] text-left transition-colors"
            style={{
              background: section === s.value ? "var(--primary)" : "transparent",
              color: section === s.value ? "#1E1F18" : "var(--on-surface-variant)",
            }}>
            <span className="material-symbols-rounded text-xl">{s.icon}</span>
            <span className="text-sm font-semibold">{s.label}</span>
          </button>
        ))}
      </div>

      {/* Content */}
      <div className="flex-1 min-w-0 rounded-[var(--r-lg)] p-6" style={{ background: "var(--surface)" }}>
        {section === "profile" && (
          <Panel title="Profile">
            <Field label="Email">
              <ReadonlyValue>{user?.email ?? "—"}</ReadonlyValue>
            </Field>
            <Field label="Roles">
              <ReadonlyValue>{user?.roles.join(", ") ?? "—"}</ReadonlyValue>
            </Field>
            <p className="text-xs mt-2" style={{ color: "var(--muted)" }}>
              Profile editing is not available yet.
            </p>
          </Panel>
        )}

        {section === "goals" && (
          <Panel title="Daily goals">
            <div className="grid grid-cols-2 gap-4">
              {GOAL_FIELDS.map(({ key, label, color, unit }) => (
                <div key={key} className="flex flex-col gap-1.5 p-3 rounded-[var(--r-card)]"
                  style={{ background: "var(--surface-container)" }}>
                  <label className="text-xs font-semibold" style={{ color }}>{label} {unit && `(${unit})`}</label>
                  <input type="number" min={0}
                    step={key === "dailyWaterGoalLiters" ? "0.1" : "1"}
                    value={(form[key] as number | null) ?? ""}
                    onChange={(e) => patch({ [key]: e.target.value === "" ? null : Number(e.target.value) })}
                    className="px-3 h-10 rounded-[var(--r-input)] outline-none text-sm tabular"
                    style={{ background: "var(--surface)", border: "1px solid var(--outline)" }} />
                </div>
              ))}
            </div>
            <button onClick={() => saveMutation.mutate(form)} disabled={saveMutation.isPending}
              className="mt-5 h-10 px-6 rounded-[var(--r-input)] font-semibold text-sm transition-opacity disabled:opacity-60"
              style={{ background: "var(--primary)", color: "#1E1F18" }}>
              {saveMutation.isPending ? "Saving…" : "Save changes"}
            </button>
          </Panel>
        )}

        {section === "units" && (
          <Panel title="Units">
            <SegmentedControl<UnitSystem>
              options={[{ value: "METRIC", label: "Metric" }, { value: "IMPERIAL", label: "Imperial" }]}
              value={form.unitSystem}
              onChange={(v) => saveImmediate({ unitSystem: v })}
            />
          </Panel>
        )}

        {section === "theme" && (
          <Panel title="Theme">
            <SegmentedControl<ThemePreference>
              options={[
                { value: "LIGHT", label: "Light" },
                { value: "DARK", label: "Dark" },
                { value: "SYSTEM", label: "System" },
              ]}
              value={form.theme}
              onChange={(v) => {
                setTheme(v.toLowerCase() as "light" | "dark" | "system");
                saveImmediate({ theme: v });
              }}
            />
            <p className="text-xs mt-3" style={{ color: "var(--muted)" }}>Applied immediately.</p>
          </Panel>
        )}

        {section === "language" && (
          <Panel title="Language">
            <SegmentedControl<LanguagePreference>
              options={[
                { value: "SYSTEM", label: "System" },
                { value: "ENGLISH", label: "English" },
                { value: "HUNGARIAN", label: "Magyar" },
              ]}
              value={form.language}
              onChange={(v) => { setLanguage(v); saveImmediate({ language: v }); }}
            />
          </Panel>
        )}

        {section === "security" && (
          <Panel title="Security">
            <Field label="Password">
              <ReadonlyValue>••••••••</ReadonlyValue>
            </Field>
            <p className="text-xs mb-5" style={{ color: "var(--muted)" }}>
              Password change is not available yet.
            </p>
            <button onClick={() => logoutAll()}
              className="flex items-center gap-2 h-10 px-5 rounded-[var(--r-input)] font-semibold text-sm"
              style={{ background: "color-mix(in srgb, var(--error) 15%, transparent)", color: "var(--error)" }}>
              <span className="material-symbols-rounded text-lg">logout</span>
              Sign out of all devices
            </button>
          </Panel>
        )}
      </div>
    </div>
  );
}

function Panel({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div>
      <h2 className="text-lg font-bold mb-5">{title}</h2>
      <div className="flex flex-col gap-4 max-w-lg">{children}</div>
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex flex-col gap-1">
      <label className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>{label}</label>
      {children}
    </div>
  );
}

function ReadonlyValue({ children }: { children: React.ReactNode }) {
  return (
    <div className="px-3 h-10 flex items-center rounded-[var(--r-input)] text-sm"
      style={{ background: "var(--surface-container)", border: "1px solid var(--outline)", color: "var(--on-surface-variant)" }}>
      {children}
    </div>
  );
}
