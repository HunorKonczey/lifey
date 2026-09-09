import { getTranslations } from "next-intl/server";

/**
 * A compact reproduction of the app's Settings subscription tile (69 §11:
 * "the Settings tile, four states" — this is the sponsored state), not the
 * full dashboard phone mock SponsoredBand.tsx already built for the home
 * page (68 §4.7). Reusing that component here would repeat the exact same
 * visual the reader may have just scrolled past on the way in from `/`.
 */
export async function SponsoredMock() {
  const t = await getTranslations("forTrainers.block5");

  return (
    <div
      className="rounded-lg border border-outline p-5 md:p-6"
      style={{ background: "var(--surface)", boxShadow: "0 24px 60px rgba(0,0,0,.25)" }}
    >
      <div className="text-[11px] font-extrabold tracking-wide" style={{ color: "var(--muted)" }}>
        {t("mockSectionLabel").toUpperCase()}
      </div>

      <div className="rounded-md p-3.5 mt-2.5 flex items-center gap-3" style={{ background: "var(--surface-container)" }}>
        <span
          className="w-10 h-10 rounded-md flex items-center justify-center shrink-0"
          style={{ background: "var(--secondary)", color: "var(--bg)" }}
        >
          <span className="material-symbols-rounded text-xl" style={{ fontVariationSettings: "'FILL' 1" }}>
            workspace_premium
          </span>
        </span>
        <div className="flex-1">
          <div className="text-sm font-extrabold">{t("mockTierName")}</div>
          <div className="text-[11.5px]" style={{ color: "var(--tertiary)" }}>{t("mockSponsoredBy")}</div>
        </div>
      </div>

      <div className="flex flex-col gap-2 mt-3">
        {[
          { icon: "block", label: t("mockRowAds") },
          { icon: "history", label: t("mockRowHistory") },
          { icon: "smart_toy", label: t("mockRowAi") },
        ].map((row) => (
          <div key={row.label} className="flex items-center gap-2.5 rounded-md px-3 py-2.5" style={{ background: "var(--surface-container)" }}>
            <span className="material-symbols-rounded text-lg" style={{ color: "var(--secondary)" }}>
              {row.icon}
            </span>
            <span className="text-[12.5px] font-bold flex-1">{row.label}</span>
            <span className="material-symbols-rounded text-lg" style={{ color: "var(--tertiary)", fontVariationSettings: "'FILL' 1" }}>
              check_circle
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}
