"use client";

import { useTranslations } from "next-intl";
import { Button, Card, Icon } from "@/components/ds";
import { formatDuration } from "../../cardioFormat";
import { formatKg } from "../../weekLabels";
import { REST_STEP_SECONDS, isFinished, isUrgent, remainingFraction, remainingSeconds, type RestState } from "../../restTimer";
import { useFormat } from "@/lib/i18n/format";

/**
 * The right column of the live logger (W3.8, W3-B, live-002): "PIHENŐ", the remaining time as the hero (72/800),
 * "a 2:00-ból · utána 4. szett", −15 / +15 / Kihagyás and a draining bar — the last five seconds turn `--m-kcal`
 * and pulse (static under reduced motion). Below it "Eddig ma": volume and records so far. With the rest timer
 * switched off in Settings (`enabled = false`) only "Eddig ma" is shown.
 */
export function RestHero({
  enabled,
  state,
  now,
  onAdjust,
  onSkip,
  onPauseResume,
  volumeKg,
  records,
}: {
  enabled: boolean;
  state: RestState;
  now: number;
  onAdjust: (deltaSeconds: number) => void;
  onSkip: () => void;
  onPauseResume: () => void;
  volumeKg: number;
  records: number;
}) {
  const t = useTranslations("workouts");
  const { locale } = useFormat();
  const active = state.status !== "idle";
  const left = remainingSeconds(state, now);
  const finished = isFinished(state, now);
  const urgent = isUrgent(state, now);
  const paused = state.status === "paused";

  return (
    <aside className="flex flex-col gap-4" aria-label={t("restAria")}>
      {enabled && (
        <Card variant="hero" className="flex flex-col gap-3" data-testid="rest-hero" data-rest-status={finished ? "finished" : state.status}>
          <span className="type-section" style={{ color: "var(--text-3)" }}>
            {t("restTitle")}
          </span>

          {active ? (
            <>
              <p
                className={["tabular", urgent ? "rest-urgent" : ""].filter(Boolean).join(" ")}
                data-testid="rest-time"
                role="timer"
                aria-live="off"
                style={{ fontSize: 72, lineHeight: "76px", fontWeight: 800, letterSpacing: "-0.03em", opacity: paused ? 0.6 : 1 }}
              >
                {formatDuration(left)}
              </p>
              <p className="type-body-s" style={{ color: "var(--text-2)" }}>
                {finished
                  ? t("restDone")
                  : paused
                    ? t("restPaused")
                    : [t("restOf", { total: formatDuration(Math.round(state.totalMs / 1000)) }), state.nextSet != null ? t("restThen", { n: state.nextSet }) : null]
                        .filter(Boolean)
                        .join(" · ")}
              </p>
              <div
                className="overflow-hidden"
                style={{ height: 6, borderRadius: "var(--r-pill)", background: "var(--nested)" }}
                aria-hidden
              >
                <div
                  data-testid="rest-bar"
                  style={{
                    height: "100%",
                    width: `${Math.round(remainingFraction(state, now) * 100)}%`,
                    borderRadius: "var(--r-pill)",
                    background: urgent ? "var(--m-kcal)" : "var(--primary)",
                  }}
                />
              </div>
              <div className="flex flex-wrap gap-2">
                <Button variant="secondary" onClick={() => onAdjust(-REST_STEP_SECONDS)}>
                  {t("restMinus", { s: REST_STEP_SECONDS })}
                </Button>
                <Button variant="secondary" onClick={() => onAdjust(REST_STEP_SECONDS)}>
                  {t("restPlus", { s: REST_STEP_SECONDS })}
                </Button>
                {!finished && (
                  <Button variant="ghost" onClick={onPauseResume}>
                    <Icon name={paused ? "play_arrow" : "pause"} size={20} />
                    {paused ? t("restResume") : t("restPause")}
                  </Button>
                )}
                <Button variant="ghost" onClick={onSkip}>
                  {t("restSkip")}
                </Button>
              </div>
            </>
          ) : (
            <p className="type-body-s" style={{ color: "var(--text-2)" }}>
              {t("restIdle")}
            </p>
          )}
        </Card>
      )}

      <Card>
        <span className="type-section" style={{ color: "var(--text-3)" }}>
          {t("todaySoFar")}
        </span>
        <dl className="mt-3 grid grid-cols-2 gap-3">
          <div>
            <dt className="type-label" style={{ color: "var(--text-3)" }}>
              {t("summaryVolume")}
            </dt>
            <dd className="type-title tabular" data-testid="today-volume">
              {formatKg(volumeKg, locale)}
            </dd>
          </div>
          <div>
            <dt className="type-label" style={{ color: "var(--text-3)" }}>
              {t("recordsLabel")}
            </dt>
            <dd className="type-title tabular flex items-center gap-1" data-testid="today-records">
              {records}
              {records > 0 && <Icon name="trophy" size={20} fill={1} color="var(--record)" />}
            </dd>
          </div>
        </dl>
      </Card>
    </aside>
  );
}
