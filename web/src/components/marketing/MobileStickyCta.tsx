"use client";

import { useEffect, useState } from "react";
import Link from "next/link";

const SCROLL_THRESHOLD_PX = 400;

/**
 * Mobile-only sticky bottom CTA (design/Lifey Landing.dc.html, L03) — three
 * states: hidden at the top, visible after scrolling, hidden again once the
 * footer (id="site-footer") is in view or an input is focused, so it never
 * covers the legal links or a form field.
 *
 * The canvas's visible state echoes the currently-scrolled-past section's
 * headline; there's no real section content until Prompt 4's home page, so
 * this renders the plain CTA + reassurance line for now — a `headline` prop
 * can be threaded through once there's something to echo.
 */
export function MobileStickyCta({ cta, noCard }: { cta: string; noCard: string }) {
  const [pastThreshold, setPastThreshold] = useState(false);
  const [footerVisible, setFooterVisible] = useState(false);
  const [inputFocused, setInputFocused] = useState(false);

  useEffect(() => {
    const onScroll = () => setPastThreshold(window.scrollY > SCROLL_THRESHOLD_PX);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  useEffect(() => {
    const footer = document.getElementById("site-footer");
    if (!footer) return;
    const observer = new IntersectionObserver(([entry]) => setFooterVisible(entry.isIntersecting), {
      rootMargin: "0px 0px -10% 0px",
    });
    observer.observe(footer);
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    const isFormField = (el: EventTarget | null) =>
      el instanceof HTMLElement && ["INPUT", "TEXTAREA", "SELECT"].includes(el.tagName);
    const onFocusIn = (e: FocusEvent) => {
      if (isFormField(e.target)) setInputFocused(true);
    };
    const onFocusOut = (e: FocusEvent) => {
      if (isFormField(e.target)) setInputFocused(false);
    };
    document.addEventListener("focusin", onFocusIn);
    document.addEventListener("focusout", onFocusOut);
    return () => {
      document.removeEventListener("focusin", onFocusIn);
      document.removeEventListener("focusout", onFocusOut);
    };
  }, []);

  const visible = pastThreshold && !footerVisible && !inputFocused;

  return (
    <div
      id="mobile-sticky-cta"
      className="md:hidden fixed left-0 right-0 bottom-0 z-30 px-4 pt-3 transition-transform duration-200"
      style={{
        background: "var(--surface)",
        borderTop: "1px solid var(--outline)",
        paddingBottom: "calc(env(safe-area-inset-bottom, 0px) + 20px)",
        transform: visible ? "translateY(0)" : "translateY(100%)",
      }}
      aria-hidden={!visible}
    >
      <Link
        href="/register"
        tabIndex={visible ? 0 : -1}
        className="h-13 rounded-pill flex items-center justify-center text-base font-extrabold"
        style={{ background: "var(--primary)", color: "var(--bg)" }}
      >
        {cta}
      </Link>
      <div className="text-center text-[11.5px] mt-2" style={{ color: "var(--muted)" }}>
        {noCard}
      </div>
    </div>
  );
}
