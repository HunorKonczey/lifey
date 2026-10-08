import type { Metadata } from "next";
import { Plus_Jakarta_Sans } from "next/font/google";
import { DeferredTelemetry } from "@/components/status/DeferredTelemetry";
import { SITE_URL } from "@/lib/site";
import "@/app/globals.css";

const plusJakarta = Plus_Jakarta_Sans({
  subsets: ["latin"],
  weight: ["400", "500", "600", "700", "800"],
  display: "swap",
  variable: "--font-jakarta",
});

/** The site-wide metadata. Every root layout (one per route group) exports it as its own `metadata`. */
export const rootMetadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: "Lifey",
  description: "Personal fitness and nutrition tracker",
};

/**
 * The document every page renders into: `<html>`, the theme script, the icon font and `<body>`. Each route group has its
 * own root layout that wraps its pages in this one, so `lang` is right in the server-rendered HTML — the marketing tree
 * passes the locale of the URL, the signed-in app and its auth pages "en" (their language is decided on the client; see
 * `DocumentLang`). Moved here from `app/layout.tsx` for LIF-142.
 */
export function RootDocument({ lang, children }: Readonly<{ lang: string; children: React.ReactNode }>) {
  return (
    <html lang={lang} className={`${plusJakarta.variable} h-full`} suppressHydrationWarning>
      {/* FOUC prevention: set data-theme before first paint */}
      {/* The document's own <head> (this is the root layout, not a pages-router page). */}
      {/* eslint-disable-next-line @next/next/no-head-element */}
      <head>
        <script
          dangerouslySetInnerHTML={{
            __html: `
              (function(){
                try {
                  var stored = localStorage.getItem('lifey-theme');
                  var theme = stored === 'light' || stored === 'dark' ? stored
                    : window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark';
                  document.documentElement.setAttribute('data-theme', theme);
                } catch(e) {
                  document.documentElement.setAttribute('data-theme', 'dark');
                }
              })();
            `,
          }}
        />
        {/* Material Symbols is an icon font loaded globally via <link> by design
            (next/font doesn't support variable icon fonts well). */}
        {/* eslint-disable-next-line @next/next/no-page-custom-font */}
        <link
          rel="stylesheet"
          href="https://fonts.googleapis.com/css2?family=Material+Symbols+Rounded:opsz,wght,FILL,GRAD@20..48,100..700,0..1,-50..200&display=swap"
        />
      </head>
      <body className="min-h-full antialiased bg-bg text-fg" suppressHydrationWarning>
        {children}
        {/* Vercel's scripts are blocked by our dev CSP and meaningless off Vercel,
            so `next dev` would log two errors per page for nothing. */}
        {process.env.NODE_ENV === "production" && <DeferredTelemetry />}
      </body>
    </html>
  );
}
