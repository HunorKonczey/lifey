"use client";

import { DateStepper } from "@/components/shell/DateStepper";

/**
 * DS-02's date stepper (D-W0.21), standalone — `TopBar` itself needs a real
 * dated route to show it (via `routeChrome`), which `/dev/design` isn't, so
 * this demos the stepper directly against the real `useDateStore`.
 */
export function DateStepperSection() {
  return (
    <div className="flex justify-center p-6" style={{ background: "var(--card)", borderRadius: "var(--r-card)" }}>
      <DateStepper />
    </div>
  );
}
