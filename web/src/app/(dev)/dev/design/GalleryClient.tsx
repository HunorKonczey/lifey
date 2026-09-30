"use client";

import { useEffect, useState } from "react";
import { GalleryToolbar, type GalleryWidth } from "@/components/ds/gallery/GalleryToolbar";
import { GALLERY_SECTIONS } from "@/components/ds/gallery/registry";

export function GalleryClient() {
  const [width, setWidth] = useState<GalleryWidth>(1440);

  // Read by `e2e/ds/fixtures.ts`: the page is interactive only once this has run.
  useEffect(() => {
    document.documentElement.dataset.hydrated = "true";
  }, []);

  return (
    <div className="min-h-screen" style={{ background: "var(--bg)", color: "var(--text)" }}>
      <GalleryToolbar width={width} onWidthChange={setWidth} />
      <div className="mx-auto py-8 px-5" style={{ maxWidth: width }}>
        {GALLERY_SECTIONS.map(({ id, title, Component }) => (
          <section key={id} id={id} className="mb-10">
            <h2 className="type-title mb-4">{title}</h2>
            <Component />
          </section>
        ))}
      </div>
    </div>
  );
}
