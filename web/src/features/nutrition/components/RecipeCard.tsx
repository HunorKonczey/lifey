"use client";

import type { ReactNode } from "react";
import { useTranslations } from "next-intl";
import { Button, Card, Icon, TintedChip } from "@/components/ds";
import type { MenuItemDef } from "@/components/ds/Menu";
import { RatioBar } from "@/components/ds/progress/RatioBar";
import { RowMenuButton } from "@/components/ds/RowMenuButton";
import { useFormat } from "@/lib/format/useFormat";
import { useFormat as useNumberFormat } from "@/lib/i18n/format";
import type { Macros } from "../recipeMacros";
import { recipeTint } from "../recipeTint";
import type { RecipeResponse } from "../types";

export interface RecipeCardProps {
  recipe: RecipeResponse;
  /** One serving's macros — the whole recipe divided by its servings. */
  perServing: Macros;
  /** The recipe's photo (a `RecipeThumbnail`) — the card draws the dominant-macro icon when there is none. */
  photo?: ReactNode;
  onOpen: () => void;
  onLog: () => void;
  menu: MenuItemDef[];
}

/**
 * A recipe card (W2.11, client-008/009): the photo or a 56 px icon in the dominant macro's colour, the name,
 * "4 adag · 5 hozzávaló", the **kcal per serving** large, a P/C/F ratio bar (by kcal share), the macros per
 * serving in their metric colours, "Naplózás" and a "⋯". The top part opens the editor; the actions sit outside
 * that button so nothing is nested. A recipe the user's trainer assigned carries an "Az edződtől" chip, the web's
 * counterpart of the phone's "Edzőtől" pill (LIF-104).
 */
export function RecipeCard({ recipe, perServing, photo, onOpen, onLog, menu }: RecipeCardProps) {
  const t = useTranslations("nutrition.recipesView");
  const fmt = useFormat();
  const nf = useNumberFormat();
  const tint = recipeTint(perServing);

  return (
    <Card className="flex flex-col gap-4" data-testid="recipe-card">
      <button type="button" onClick={onOpen} className="lifey-button flex flex-col gap-3 text-left" style={{ borderRadius: "var(--r-control)" }}>
        <span className="flex items-start gap-3">
          {photo ?? (
            <span
              data-testid="recipe-tint-icon"
              data-macro={tint.macro}
              className="flex shrink-0 items-center justify-center"
              style={{
                width: 56,
                height: 56,
                borderRadius: "var(--r-control)",
                background: `color-mix(in srgb, ${tint.color} var(--chip-tint), transparent)`,
              }}
            >
              <Icon name={tint.icon} size={28} fill={1} color={tint.color} />
            </span>
          )}
          <span className="min-w-0 flex-1">
            <span className="flex items-start justify-between gap-2">
              <span className="line-clamp-2" style={{ fontSize: 16, fontWeight: 800 }}>
                {recipe.name}
              </span>
              {recipe.favorite && (
                <Icon name="star" size={20} fill={1} color="var(--m-carbs)" label={t("favoriteAria")} className="shrink-0" />
              )}
            </span>
            <span className="type-body-s block" style={{ color: "var(--text-3)" }}>
              {t("servingsMeta", { servings: recipe.servings, count: recipe.ingredients.length })}
            </span>
            {recipe.originTrainerId != null && (
              <span className="mt-1.5 block" data-testid="recipe-from-trainer">
                <TintedChip label={t("fromTrainer")} color="var(--role)" icon="school" />
              </span>
            )}
          </span>
        </span>

        <span className="block">
          <span className="tabular" style={{ fontSize: 28, fontWeight: 800, lineHeight: 1.1 }}>
            {fmt.integer(perServing.calories)}
          </span>{" "}
          <span className="type-body-s" style={{ color: "var(--text-2)", fontWeight: 600 }}>
            {t("kcalPerServing")}
          </span>
        </span>

        <span className="block">
          <RatioBar
            segments={[
              { value: perServing.protein * 4, color: "var(--m-protein)" },
              { value: perServing.carbs * 4, color: "var(--m-carbs)" },
              { value: perServing.fat * 9, color: "var(--m-fat)" },
            ]}
            height={8}
          />
        </span>

        <span className="type-body-s tabular block" data-testid="recipe-macros">
          <MacroLine
            text={t("macroLine", {
              protein: nf.number(perServing.protein, 0),
              carbs: nf.number(perServing.carbs, 0),
              fat: nf.number(perServing.fat, 0),
            })}
          />
        </span>
      </button>

      <div className="flex items-center gap-2">
        <Button variant="tonal" onClick={onLog} className="flex-1">
          <Icon name="restaurant" size={18} />
          {t("log")}
        </Button>
        <RowMenuButton items={menu} label={t("rowMenuLabel", { name: recipe.name })} />
      </div>
    </Card>
  );
}

/** "F 38 g · Sz 58 g · Zs 14 g" with each part in its metric colour — the parts are the text between the dots. */
function MacroLine({ text }: { text: string }) {
  const colors = ["var(--m-protein)", "var(--m-carbs)", "var(--m-fat)"];
  return (
    <>
      {text.split(" · ").map((part, i) => (
        <span key={i}>
          {i > 0 && <span style={{ color: "var(--text-3)" }}> · </span>}
          <span style={{ color: colors[i] }}>{part}</span>
        </span>
      ))}
    </>
  );
}
