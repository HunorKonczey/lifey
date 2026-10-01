"use client";

import { useTranslations } from "next-intl";
import { Button, Icon, Modal } from "@/components/ds";
import { formatNumber, useFormat } from "@/lib/i18n/format";
import type { CelebrationData } from "../../finishSummary";
import { formatHoursMinutes, formatKg } from "../../weekLabels";

/**
 * "Kész a Láb + core!" (W3.9, W3-C, finish-002): the trophy, "Két új rekord. Ez volt a héten a 4. edzésed.", three
 * stats (time · volume · sets), one row per record, "Összefoglaló" (opens the summary panel) and "Kész". It
 * replaces the old toast + confetti dialog and is always shown when a workout is finished. The trophy pops once
 * and the rest fades up in turn over 1.2 s (`.celebrate-trophy` / `.celebrate-in`); under reduced motion it is static.
 */
export function CelebrationModal({
  open,
  name,
  data,
  onSummary,
  onDone,
}: {
  open: boolean;
  name: string;
  data: CelebrationData | null;
  onSummary: () => void;
  onDone: () => void;
}) {
  const t = useTranslations("workouts");
  const { locale } = useFormat();
  if (!data) return null;
  const weight = (n: number) => formatNumber(n, locale, 2);
  const stagger = (k: number) => ({ "--k": k }) as React.CSSProperties;

  return (
    <Modal open={open} onClose={onDone} width={480} aria-label={t("celebrationTitle", { name })}>
      <div className="flex flex-col items-center gap-4 p-6 text-center" data-testid="celebration">
        <span
          className="celebrate-trophy flex items-center justify-center"
          style={{ width: 72, height: 72, borderRadius: "var(--r-pill)", background: "color-mix(in srgb, var(--record) var(--chip-tint), transparent)" }}
        >
          <Icon name="trophy" size={40} fill={1} color="var(--record)" />
        </span>

        <div className="celebrate-in" style={stagger(0.1)}>
          <h2 className="type-title-l">{t("celebrationTitle", { name })}</h2>
          <p className="type-body mt-1" style={{ color: "var(--text-2)" }}>
            {t("celebrationSubtitle", { records: data.records.length, n: data.weekCount })}
          </p>
        </div>

        <dl className="celebrate-in grid w-full grid-cols-3 gap-3" style={stagger(0.25)}>
          <Stat label={t("summaryTime")} value={formatHoursMinutes(data.seconds, locale)} />
          <Stat label={t("summaryVolume")} value={formatKg(data.volumeKg, locale)} />
          <Stat label={t("celebrationSets")} value={String(data.sets)} />
        </dl>

        {data.records.length > 0 && (
          <ul className="flex w-full flex-col gap-2" aria-label={t("recordsLabel")}>
            {data.records.map((r, i) => (
              <li
                key={r.exerciseId}
                className="celebrate-in flex items-center gap-2 px-3 py-2 text-left"
                style={{ ...stagger(0.4 + 0.1 * Math.min(i, 3)), borderRadius: "var(--r-control)", background: "color-mix(in srgb, var(--record) var(--chip-tint), transparent)" }}
              >
                <Icon name="trophy" size={18} fill={1} color="var(--record)" />
                <span className="type-body tabular" style={{ fontWeight: 700 }}>
                  {r.exerciseName} {weight(r.set.weight)} kg × {r.set.reps}
                </span>
              </li>
            ))}
          </ul>
        )}

        <div className="celebrate-in flex w-full justify-end gap-2 pt-1" style={stagger(0.75)}>
          <Button variant="secondary" onClick={onSummary}>
            {t("celebrationSummary")}
          </Button>
          <Button onClick={onDone}>{t("celebrationDone")}</Button>
        </div>
      </div>
    </Modal>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-[var(--r-card)] p-3" style={{ background: "var(--nested)" }}>
      <dt className="type-label" style={{ color: "var(--text-3)" }}>
        {label}
      </dt>
      <dd className="type-body tabular mt-0.5" style={{ fontWeight: 800 }}>
        {value}
      </dd>
    </div>
  );
}
