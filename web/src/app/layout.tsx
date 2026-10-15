import type { Metadata } from "next";
import localFont from "next/font/local";
import { DeferredTelemetry } from "@/components/status/DeferredTelemetry";
import { SITE_URL } from "@/lib/site";
import "./globals.css";

// Self-hosted (the variable "latin" file Google serves, SIL OFL - see fonts/OFL.txt) rather than `next/font/google`: the dev server's
// Google path fetches the CSS at request time and failed in CI intermittently ("next/font/google queries have exactly one entry"),
// taking the e2e suites down with it. A local file has no network in dev, in CI or at build time. Same family, same weights (200-800
// covers the 400-800 the app uses), same CSS variable.
const plusJakarta = localFont({
  src: "./fonts/PlusJakartaSans-latin.woff2",
  weight: "200 800",
  display: "swap",
  variable: "--font-jakarta",
});

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: "Lifey",
  description: "Personal fitness and nutrition tracker",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" className={`${plusJakarta.variable} h-full`} suppressHydrationWarning>
      {/* FOUC prevention: set data-theme before first paint */}
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
