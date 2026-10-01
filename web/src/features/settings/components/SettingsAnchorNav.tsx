"use client";

import { useEffect, useRef, useState } from "react";
import { useTranslations } from "next-intl";
import { Icon } from "@/components/ds";

export interface AnchorItem {
  id: string;
  label: string;
  icon: string;
}

/**
 * The sticky anchor list on the left of the one-page settings (W6-G): a click scrolls to the section, and the section
 * in view is highlighted — a scroll-spy over the section ids, so the highlight follows what the person is reading.
 */
export function SettingsAnchorNav({ items }: { items: AnchorItem[] }) {
  const t = useTranslations("settings");
  const [active, setActive] = useState(items[0]?.id);

  // Scroll-spy: the active section is the last one whose top has passed 35% of the viewport — or the last section
  // outright once the page is scrolled to its end, since a short final section can never climb that high. A click
  // pins its target for the length of the smooth scroll so the highlight does not flicker through the sections between.
  const pinned = useRef<string | null>(null);
  useEffect(() => {
    const update = () => {
      if (pinned.current) return;
      const scroller = document.scrollingElement;
      const atEnd = !!scroller && scroller.scrollTop + scroller.clientHeight >= scroller.scrollHeight - 4;
      let current = items[0]?.id;
      for (const i of items) {
        const el = document.getElementById(i.id);
        if (el && el.getBoundingClientRect().top <= window.innerHeight * 0.35) current = i.id;
      }
      setActive(atEnd && scroller && scroller.scrollHeight > scroller.clientHeight + 8 ? items[items.length - 1]?.id : current);
    };
    update();
    document.addEventListener("scroll", update, { capture: true, passive: true });
    window.addEventListener("resize", update);
    return () => {
      document.removeEventListener("scroll", update, { capture: true });
      window.removeEventListener("resize", update);
    };
  }, [items]);

  function go(id: string) {
    setActive(id);
    pinned.current = id;
    window.setTimeout(() => { pinned.current = null; }, 900);
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    document.getElementById(id)?.scrollIntoView({ behavior: reduce ? "auto" : "smooth", block: "start" });
  }

  return (
    <nav aria-label={t("sectionsAria")} className="hidden md:flex flex-col gap-1 sticky top-24 self-start">
      {items.map((i) => {
        const on = active === i.id;
        return (
          <button
            key={i.id}
            type="button"
            onClick={() => go(i.id)}
            aria-current={on ? "location" : undefined}
            className="lifey-button flex items-center gap-3 px-3.5 h-11 text-left"
            style={{
              borderRadius: "var(--r-control)",
              background: on ? "var(--primary-tint)" : "transparent",
              color: on ? "var(--on-primary-tint)" : "var(--text-2)",
              fontWeight: 700,
              fontSize: 15,
            }}
          >
            <Icon name={i.icon} size={20} fill={on ? 1 : 0} />
            {i.label}
          </button>
        );
      })}
    </nav>
  );
}
