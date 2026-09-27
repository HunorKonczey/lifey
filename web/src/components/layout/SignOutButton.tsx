"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { ConfirmDialog } from "@/components/ui/ConfirmDialog";

/** Sidebar sign-out icon. Asks first — a stray click used to end the session immediately. */
export function SignOutButton({ onSignOut, className = "" }: { onSignOut: () => void; className?: string }) {
  const common = useTranslations("common");
  const [confirming, setConfirming] = useState(false);

  return (
    <>
      <button
        onClick={() => setConfirming(true)}
        className={`p-1 rounded-[var(--r-sm)] transition-colors ${className}`}
        style={{ color: "var(--on-surface-variant)" }}
        aria-label={common("signOut")}
        title={common("signOut")}
      >
        <span className="material-symbols-rounded text-xl">logout</span>
      </button>
      <ConfirmDialog
        open={confirming}
        title={common("signOutConfirmTitle")}
        body={common("signOutConfirmBody")}
        confirmLabel={common("signOut")}
        onConfirm={() => {
          setConfirming(false);
          onSignOut();
        }}
        onCancel={() => setConfirming(false)}
      />
    </>
  );
}
