"use client";

import { GridItem, PageGrid } from "@/components/ds";

function Block({ label }: { label: string }) {
  return (
    <div
      className="type-body-s flex items-center justify-center h-16"
      style={{ background: "var(--card)", borderRadius: "var(--r-card)", color: "var(--text-2)" }}
    >
      {label}
    </div>
  );
}

/**
 * D-W0.6's `PageGrid` — the dashboard's own span/order pattern with
 * placeholders: 8 + 4 at 1280+, then the order flips at 768–1279 (tiles
 * before the side panel), one column at mobile.
 */
export function PageGridSection() {
  return (
    <PageGrid>
      <GridItem span={{ base: 4, md: 8, xl: 8 }} order={{ base: 0 }}>
        <Block label="main 8" />
      </GridItem>
      <GridItem span={{ base: 4, md: 4, xl: 4 }} order={{ base: 1, md: 2, xl: 1 }}>
        <Block label="side 4" />
      </GridItem>
      <GridItem span={{ base: 4, md: 8, xl: 12 }} order={{ base: 2, md: 1, xl: 2 }}>
        <Block label="full" />
      </GridItem>
    </PageGrid>
  );
}
