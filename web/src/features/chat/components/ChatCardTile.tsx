"use client";

import { useTranslations } from "next-intl";
import { Card, Icon, RecordChip } from "@/components/ds";
import { useFormat } from "@/lib/format/useFormat";
import {
  distanceKm,
  durationMinutes,
  isCardio,
  isKnownCard,
  prDelta,
  prUnit,
  recordCount,
} from "../card";
import type { MessageCardResponse } from "../types";

/**
 * A shared workout or personal record, drawn as a card of its own in the thread
 * (docs/chat/83-chat-result-card-plan.md §4) — read-only on the web: the web has
 * no per-session page to open it on, so the tile is a snapshot.
 *
 * It replaces the text bubble rather than sitting in one (a card inside a bubble
 * is the nested box the design system forbids). Own cards keep a primary hairline
 * so the two sides still read. Numbers are formatted here, for the reader, never
 * taken pre-formatted from the sender (§7 "Locale").
 */
export function ChatCardTile({
  card,
  own,
  caption,
  ariaLabel,
}: {
  card: MessageCardResponse;
  own: boolean;
  /** The message body, when the sender added a note. */
  caption: string | null;
  /** Prefix for the screen-reader label (sender and time), supplied by the bubble. */
  ariaLabel: (spoken: string) => string;
}) {
  const t = useTranslations("chat");
  const fmt = useFormat();
  const known = isKnownCard(card);

  const cardio = isCardio(card);
  const workout = card.kind === "WORKOUT" ? card.workout : null;
  const pr = card.kind === "PR" ? card.pr : null;

  const kindLabel = !known
    ? t("cardUnsupported")
    : pr
      ? t("cardRecord")
      : cardio
        ? t("cardCardio")
        : t("cardWorkout");
  const title = pr
    ? pr.exerciseName
    : workout
      ? (workout.title?.trim() || (cardio ? t("cardUntitledCardio") : t("cardUntitledWorkout")))
      : "";

  const summaryParts: string[] = [];
  if (workout) {
    const minutes = durationMinutes(workout.durationSeconds);
    if (minutes != null) summaryParts.push(t("cardMinutes", { count: minutes }));
    const km = distanceKm(workout.distanceMeters);
    if (cardio && km != null) summaryParts.push(t("cardDistance", { value: fmt.number(km, 2) }));
    if (!cardio && workout.volumeKg != null && workout.volumeKg > 0)
      summaryParts.push(t("cardVolume", { volume: fmt.number(workout.volumeKg, 0) }));
    if (!cardio && workout.exerciseCount != null && workout.exerciseCount > 0)
      summaryParts.push(t("cardExercises", { count: workout.exerciseCount }));
  }

  const unit = pr ? prUnit(pr) : null;
  const prValue = pr && unit ? `${fmt.number(pr.value, 1)} ${unit === "reps" ? t("cardReps") : "kg"}` : null;
  const delta = pr ? prDelta(pr) : null;
  const prKind = pr
    ? pr.prType === "MAX_WEIGHT"
      ? t("cardKindHeaviest")
      : pr.prType === "ESTIMATED_ONE_RM"
        ? t("cardKindOneRm")
        : t("cardKindReps", { weight: fmt.number(pr.weightKg ?? 0, 1) })
    : null;

  const records = recordCount(card);
  const spoken = !known
    ? t("cardUnsupported")
    : t("cardSemantics", {
        kind: kindLabel,
        summary: [title, prValue, prKind, ...summaryParts].filter(Boolean).join(", "),
      });
  const color = pr ? "var(--record)" : cardio ? "var(--heart)" : "var(--primary)";

  return (
    <Card
      variant="card"
      role="group"
      aria-label={ariaLabel(spoken)}
      className="w-full"
      style={{
        maxWidth: 320,
        border: own ? "1px solid color-mix(in srgb, var(--primary) 55%, transparent)" : undefined,
      }}
    >
      <div className="flex items-center gap-3">
        <span
          className="grid place-items-center shrink-0"
          style={{
            width: 36,
            height: 36,
            borderRadius: 14,
            background: `color-mix(in srgb, ${known ? color : "var(--text-2)"} var(--chip-tint), transparent)`,
            color: known ? color : "var(--text-2)",
          }}
        >
          <Icon name={!known ? "help" : pr ? "trophy" : cardio ? "directions_run" : "fitness_center"} size={20} />
        </span>
        <span
          className="type-body-s truncate"
          style={{
            color: known ? "var(--text-2)" : "var(--text)",
            fontWeight: 800,
            letterSpacing: "0.06em",
            textTransform: known ? "uppercase" : undefined,
          }}
        >
          {kindLabel}
        </span>
      </div>

      {known && (
        <>
          <p className="mt-3" style={{ color: "var(--text)", fontWeight: 700, fontSize: 17, lineHeight: 1.3 }}>
            {title}
          </p>

          {pr && prValue && (
            <>
              <p className="mt-2 flex items-baseline gap-2">
                <span className="num" style={{ fontSize: 30, fontWeight: 800, color: "var(--text)" }}>{prValue}</span>
                {delta != null && (
                  <span className="num" style={{ fontSize: 14, fontWeight: 700, color: "var(--improvement)" }}>
                    +{fmt.number(delta, 1)} {unit === "reps" ? t("cardReps") : "kg"}
                  </span>
                )}
              </p>
              <p className="type-body-s mt-1" style={{ color: "var(--text-2)" }}>{prKind}</p>
            </>
          )}

          {summaryParts.length > 0 && (
            <p className="type-body-s mt-1" style={{ color: "var(--text-2)" }}>{summaryParts.join(" · ")}</p>
          )}
          {records > 0 && <RecordChip className="mt-3" label={t("cardRecords", { count: records })} />}

          {caption && <p className="mt-3 whitespace-pre-wrap break-words" style={{ color: "var(--text)", fontSize: 14.5 }}>{caption}</p>}

          <p className="type-body-s mt-3" style={{ color: "var(--text-3)" }}>
            {fmt.shortDate(new Date(card.occurredAt))}
          </p>
        </>
      )}
    </Card>
  );
}
