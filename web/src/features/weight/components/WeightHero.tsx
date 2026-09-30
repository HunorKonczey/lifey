"use client";

import { useTranslations } from "next-intl";
import { Card, DeltaChip } from "@/components/ds";
import { useFormat } from "@/lib/format/useFormat";
import { monthThird, type WeightHeroData } from "../weightHero";

/**
 * The weight page's hero (W4.1, W4-A, client-018): "ma", **69,6 kg** at 72 px, what changed this week and since the
 * first weigh-in (goal-aware colours), the start → goal band with where you are on it, "Még 4,6 kg · a mostani
 * tempóval dec. közepére" (the date only when the W1.6 projection can name one), and the 7-day average and pace.
 * Without a goal there is no band and no "még"; with one entry there are no deltas and no average.
 */
export function WeightHero({ hero, now = new Date() }: { hero: WeightHeroData; now?: Date }) {
  const t = useTranslations("weight");
  const fmt = useFormat();
  const goalDirection = hero.goalKg == null ? undefined : hero.goalKg < hero.start.weight ? "lower" : "higher";
  const eta = hero.projection?.state === "onTrack" ? hero.projection.etaDate : undefined;
  // "72 kg", not "72,0 kg": a whole number reads cleaner on the band (the tile on the dashboard does the same).
  const kg = (v: number) => (Number.isInteger(v) ? fmt.integer(v, "kg") : fmt.weight(v));
  const month = (d: Date) => new Intl.DateTimeFormat(fmt.locale, { month: "short" }).format(d);

  return (
    <Card variant="hero" className="flex flex-col gap-5" style={{ padding: 28 }} data-testid="weight-hero">
      <div>
        <p className="type-body-s" style={{ color: "var(--text-3)" }}>
          {fmt.relativeDay(hero.latest.date, now)}
        </p>
        <p className="tabular" style={{ color: "var(--text)" }}>
          <span className="type-display-xl" data-testid="weight-hero-number">
            {fmt.weightNumber(hero.latest.weight)}
          </span>
          <span className="type-title ml-2" style={{ color: "var(--text-2)" }}>
            kg
          </span>
        </p>
      </div>

      {(hero.weekDelta != null || hero.sinceStart != null) && (
        <div className="flex flex-wrap gap-2">
          {hero.weekDelta != null && <DeltaChip value={hero.weekDelta} unit={t("heroWeekUnit")} goalDirection={goalDirection} size="medium" />}
          {hero.sinceStart != null && (
            <DeltaChip value={hero.sinceStart} unit={t("heroSinceUnit", { date: fmt.shortDate(hero.start.date) })} goalDirection={goalDirection} size="medium" />
          )}
        </div>
      )}

      {hero.goalKg != null && (
        <div className="flex flex-col gap-2" data-testid="weight-band">
          <div className="type-body-s flex justify-between" style={{ color: "var(--text-2)" }}>
            <span>{t("heroStart", { weight: kg(hero.start.weight) })}</span>
            <span>{t("heroGoal", { weight: kg(hero.goalKg) })}</span>
          </div>
          {hero.progress != null && (
            <div
              role="progressbar"
              aria-valuemin={0}
              aria-valuemax={100}
              aria-valuenow={Math.round(hero.progress * 100)}
              aria-label={t("heroBandAria")}
              className="relative"
              style={{ height: 8, borderRadius: "var(--r-pill)", background: "var(--nested)" }}
            >
              <div style={{ width: `${hero.progress * 100}%`, height: "100%", borderRadius: "var(--r-pill)", background: "var(--metric-weight)" }} />
              <span
                aria-hidden
                style={{
                  position: "absolute",
                  top: "50%",
                  left: `${hero.progress * 100}%`,
                  width: 16,
                  height: 16,
                  transform: "translate(-50%, -50%)",
                  borderRadius: "var(--r-pill)",
                  background: "var(--metric-weight)",
                  boxShadow: "0 0 0 4px var(--card)",
                }}
              />
            </div>
          )}
          <p className="type-body" style={{ fontWeight: 700 }} data-testid="weight-remaining">
            {hero.reached ? t("heroReached") : t("heroRemaining", { kg: fmt.weight(hero.remainingKg ?? 0) })}
            {eta && (
              <span style={{ fontWeight: 500, color: "var(--text-2)" }}>
                {" · "}
                {t("heroEta", { month: month(eta), part: monthThird(eta) })}
              </span>
            )}
          </p>
        </div>
      )}

      {(hero.average7 != null || hero.pace != null) && (
        <dl className="grid grid-cols-2 gap-3">
          {hero.average7 != null && (
            <div className="rounded-[var(--r-card)] p-3" style={{ background: "var(--nested)" }}>
              <dt className="type-label" style={{ color: "var(--text-3)" }}>
                {t("heroAverage")}
              </dt>
              <dd className="type-body tabular" style={{ fontWeight: 800 }}>
                {fmt.weight(hero.average7)}
              </dd>
            </div>
          )}
          {hero.pace != null && (
            <div className="rounded-[var(--r-card)] p-3" style={{ background: "var(--nested)" }}>
              <dt className="type-label" style={{ color: "var(--text-3)" }}>
                {t("heroPace")}
              </dt>
              <dd className="type-body tabular" style={{ fontWeight: 800 }}>
                {fmt.signedDelta(hero.pace, { digits: 2, unit: t("heroPaceUnit") })}
              </dd>
            </div>
          )}
        </dl>
      )}
    </Card>
  );
}
