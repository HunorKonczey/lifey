"use client";

import { useState } from "react";
import { Button } from "../../Button";
import { Card } from "../../Card";
import { DelayedSkeleton } from "../../states/DelayedSkeleton";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import { Skeleton } from "@/components/status/Skeleton";

/** D-W0.17 — EmptyState/ErrorState restyled to DS-05, plus DelayedSkeleton
 *  (only appears after 300ms, static under reduced motion). Switch the
 *  gallery's EN/HU toggle above to see both languages — these already pull
 *  their copy from next-intl, same as before the restyle. */
export function StatesSection() {
  const [showSkeleton, setShowSkeleton] = useState(false);

  return (
    <div className="flex flex-col gap-6">
      <Card>
        <p className="type-body-s mb-3" style={{ color: "var(--text-3)" }}>
          EmptyState
        </p>
        <EmptyState
          icon="restaurant"
          title="No meals logged yet"
          body="Log your first meal to see today's totals and start building your history."
          action={<Button size="default">Log a meal</Button>}
          secondaryAction={
            <Button variant="secondary" size="default">
              Browse recipes
            </Button>
          }
          color="var(--m-kcal)"
        />
      </Card>

      <Card>
        <p className="type-body-s mb-3" style={{ color: "var(--text-3)" }}>
          ErrorState — full
        </p>
        <ErrorState entity="workouts" onRetry={() => {}} code="ECONNABORTED: timeout of 10000ms exceeded" />
      </Card>

      <Card className="flex flex-col gap-3">
        <p className="type-body-s" style={{ color: "var(--text-3)" }}>
          ErrorState — inline
        </p>
        <ErrorState inline onRetry={() => {}} code="500 Internal Server Error" />
      </Card>

      <Card className="flex flex-col gap-3 max-w-sm">
        <p className="type-body-s" style={{ color: "var(--text-3)" }}>
          DelayedSkeleton — nothing renders for 300ms, then a table skeleton
        </p>
        <Button variant="secondary" onClick={() => setShowSkeleton((s) => !s)}>
          {showSkeleton ? "Hide" : "Show"} loading
        </Button>
        {showSkeleton && (
          <DelayedSkeleton>
            <Skeleton variant="table" />
          </DelayedSkeleton>
        )}
      </Card>
    </div>
  );
}
