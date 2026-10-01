"use client";

import { useState } from "react";
import { BottomNav } from "@/components/shell/BottomNav";
import { MoreSheet } from "@/components/shell/MoreSheet";
import { MobileHeader } from "@/components/shell/MobileHeader";
import {
  CLIENT_BOTTOM_NAV_ITEMS,
  CLIENT_MORE_SHEET_ITEMS,
  TRAINER_NAV_ITEMS,
  TRAINER_MORE_SHEET_ITEMS,
} from "@/components/shell/navConfig";
import type { SessionUser } from "@/features/auth/types";

const FIXTURE_USER: SessionUser = {
  id: 1,
  email: "nagy.kata@example.com",
  firstName: "Nagy",
  lastName: "Kata",
  roles: ["ROLE_USER"],
};

type Role = "client" | "trainer";

/**
 * DS-02's mobile shell below 768px (D-W0.22), standalone with fixture data —
 * `e2e/ds/mobileShell.spec.ts`'s target. Both role configs are demoed since
 * the real trainer `AppShell` wiring is W0.23, not this step, but only one
 * `BottomNav` mounts at a time — it's `position: fixed`, so two at once
 * would overlap at the same spot. `BottomNav` itself floats over the rest
 * of the page like Toast/Modal elsewhere in this gallery — expected, not a
 * bug.
 */
export function MobileShellSection() {
  const [role, setRole] = useState<Role>("client");
  const [moreOpen, setMoreOpen] = useState(false);

  const bottomItems = role === "client" ? CLIENT_BOTTOM_NAV_ITEMS : TRAINER_NAV_ITEMS;
  const moreItems = role === "client" ? CLIENT_MORE_SHEET_ITEMS : TRAINER_MORE_SHEET_ITEMS;

  return (
    <div className="flex flex-col gap-6">
      <div className="flex gap-2">
        <button
          type="button"
          onClick={() => setRole("client")}
          className="lifey-button px-3 h-8 rounded-[var(--r-pill)] type-body-s"
          style={{ background: role === "client" ? "var(--primary)" : "var(--nested)", color: role === "client" ? "var(--on-primary)" : "var(--text)" }}
        >
          Client
        </button>
        <button
          type="button"
          onClick={() => setRole("trainer")}
          className="lifey-button px-3 h-8 rounded-[var(--r-pill)] type-body-s"
          style={{ background: role === "trainer" ? "var(--primary)" : "var(--nested)", color: role === "trainer" ? "var(--on-primary)" : "var(--text)" }}
        >
          Trainer
        </button>
      </div>

      <div>
        <p className="type-label mb-2" style={{ color: "var(--text-3)" }}>MOBILE HEADER</p>
        <div style={{ background: "var(--bg)", borderRadius: "var(--r-card)", overflow: "hidden" }}>
          <MobileHeader user={FIXTURE_USER} avatarUrl={null} onLogout={() => {}} />
        </div>
      </div>

      <BottomNav items={bottomItems} moreOpen={moreOpen} onMoreClick={() => setMoreOpen((v) => !v)} />
      <MoreSheet open={moreOpen} onClose={() => setMoreOpen(false)} items={moreItems} />
    </div>
  );
}
