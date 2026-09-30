"use client";

import { useDateStore } from "@/lib/hooks/useDateStore";
import { GridItem, PageGrid } from "@/components/ds";
import { OnboardingBanner } from "@/components/app/OnboardingBanner";
import { Skeleton } from "@/components/status/Skeleton";
import { ErrorState } from "@/components/status/ErrorState";
import { useDashboardData } from "@/features/dashboard/useDashboardData";
import { HeroSection } from "@/features/dashboard/components/HeroSection";
import { RecommendedSection } from "@/features/dashboard/components/RecommendedSection";
import { TilesSection } from "@/features/dashboard/components/TilesSection";
import { WeekSection } from "@/features/dashboard/components/WeekSection";
import { RecentWorkoutsSection } from "@/features/dashboard/components/RecentWorkoutsSection";

/**
 * The dashboard is composition only (W1.1): `useDashboardData` owns the
 * queries, each section owns its card, and `PageGrid` places them — the
 * canvas' three layouts come from spans and orders, not per-width markup.
 *
 * 1440/1280 (12 cols): hero 8 | workout 4 · tiles 12 · week 8 | recent 4.
 * 1024 (8 cols):       hero 8 · tiles 8 · workout 4 | recent 4 · week 8.
 * 390 (4 cols):        hero · workout · tiles · recent · week, one column.
 */
export default function DashboardPage() {
  const { date } = useDateStore();
  const data = useDashboardData(date);

  if (data.isLoading) {
    return (
      <div className="flex flex-col gap-4">
        <Skeleton variant="card" className="h-40" />
        <div className="grid grid-cols-3 gap-4">
          <Skeleton variant="card" className="h-32" />
          <Skeleton variant="card" className="h-32" />
          <Skeleton variant="card" className="h-32" />
        </div>
        <div className="grid grid-cols-3 gap-4">
          <Skeleton variant="card" className="h-40" />
          <Skeleton variant="card" className="h-40" />
          <Skeleton variant="card" className="h-40" />
        </div>
      </div>
    );
  }

  if (data.hasError) return <ErrorState onRetry={data.refetchCore} />;

  return (
    <div className="flex flex-col gap-4">
      <OnboardingBanner />
      <PageGrid>
        <GridItem span={{ base: 4, md: 8, xl: 8 }} order={{ base: 0 }}>
          <HeroSection data={data} />
        </GridItem>
        <GridItem span={{ base: 4, md: 4, xl: 4 }} order={{ base: 1, md: 2, xl: 1 }}>
          <RecommendedSection data={data} />
        </GridItem>
        <GridItem span={{ base: 4, md: 8, xl: 12 }} order={{ base: 2, md: 1, xl: 2 }}>
          <TilesSection data={data} />
        </GridItem>
        <GridItem span={{ base: 4, md: 4, xl: 4 }} order={{ base: 3, xl: 4 }}>
          <RecentWorkoutsSection data={data} />
        </GridItem>
        <GridItem span={{ base: 4, md: 8, xl: 8 }} order={{ base: 4, xl: 3 }}>
          <WeekSection data={data} />
        </GridItem>
      </PageGrid>
    </div>
  );
}
