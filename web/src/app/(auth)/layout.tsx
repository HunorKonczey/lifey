"use client";

import { Providers } from "@/lib/providers";
import { BrandPanel, LifeyLogo } from "@/features/auth/components/BrandPanel";

/**
 * W6-A: two columns from 1024 px — the dark brand panel left, the form column right (max 440); below it the panel
 * collapses to the logo row and the form starts at the top, its main button near the thumb.
 */
export default function AuthLayout({ children }: { children: React.ReactNode }) {
  return (
    <Providers>
      <div className="min-h-screen bg-bg grid grid-cols-1 lg:grid-cols-2">
        <BrandPanel />
        <main className="flex flex-col px-6 py-8 lg:items-center lg:justify-center lg:p-12">
          <div className="lg:hidden mb-8">
            <LifeyLogo />
          </div>
          <div className="w-full max-w-[440px] mx-auto lg:mx-0 flex-1 lg:flex-none flex flex-col">{children}</div>
        </main>
      </div>
    </Providers>
  );
}
