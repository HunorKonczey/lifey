import { useTranslations } from "next-intl";
import { Icon } from "@/components/ds";
import { ProgressRing } from "@/components/ds/progress/ProgressRing";
import { RecordChip } from "@/components/ds/RecordChip";

/** The Lifey mark: a rounded primary square with the leaf. */
export function LifeyLogo({ size = 40 }: { size?: number }) {
  return (
    <div className="flex items-center gap-2.5">
      <span
        className="inline-flex items-center justify-center"
        style={{ width: size, height: size, borderRadius: 13, background: "var(--primary)", color: "var(--on-primary)" }}
      >
        <Icon name="eco" size={Math.round(size * 0.55)} fill={1} />
      </span>
      <span style={{ fontSize: Math.round(size * 0.55), fontWeight: 800, letterSpacing: "-0.02em" }}>Lifey</span>
    </div>
  );
}

/**
 * W6-A's left panel: always dark (both themes), the value promise and two real components with static demo values
 * — a `ProgressRing` ("859 kcal maradt") and a record chip card. Below 1024 px the layout shows only the logo row.
 */
export function BrandPanel() {
  const t = useTranslations("auth");
  return (
    <aside
      className="dark-island hidden lg:flex flex-col gap-7 m-3 p-12 relative overflow-hidden"
      style={{ borderRadius: 30 }}
      aria-label="Lifey"
    >
      <LifeyLogo />
      <div className="flex-1" />
      <h2 className="max-w-[520px]" style={{ fontSize: 52, lineHeight: 1.05, fontWeight: 800, letterSpacing: "-0.03em" }}>
        {t("brandTitle")}
      </h2>
      <p className="max-w-[480px]" style={{ fontSize: 17, lineHeight: 1.55, color: "var(--text-2)" }}>
        {t("brandBody")}
      </p>
      <div className="flex gap-3.5 items-stretch">
        <div className="flex items-center gap-3.5 p-[18px]" style={{ background: "var(--card)", borderRadius: 22 }}>
          <ProgressRing progress={0.55} color="var(--m-kcal)" size={76} strokeWidth={12} />
          <div className="flex flex-col gap-1">
            <span className="num" style={{ fontSize: 26, fontWeight: 800, lineHeight: 1 }}>859</span>
            <span className="type-body-s" style={{ color: "var(--text-2)" }}>{t("brandKcalLeft")}</span>
          </div>
        </div>
        <div className="flex flex-col justify-center gap-1.5 p-[18px]" style={{ background: "var(--card)", borderRadius: 22 }}>
          <RecordChip label={t("brandRecord")} />
          <span className="type-body-s" style={{ color: "var(--text-2)" }}>{t("brandRecordDetail")}</span>
        </div>
      </div>
    </aside>
  );
}
