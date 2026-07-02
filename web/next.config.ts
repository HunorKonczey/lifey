import type { NextConfig } from "next";

// Derive the API origin (scheme + host) from the configured base URL so the CSP
// connect-src allows calls to the backend (and nothing else).
function apiOrigin(): string {
  try {
    return new URL(process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:8080/api/v1").origin;
  } catch {
    return "http://localhost:8080";
  }
}

const csp = [
  `default-src 'self'`,
  // Next.js injects inline bootstrap/runtime scripts; 'unsafe-inline' is required
  // without a nonce setup. 'unsafe-eval' is dev-only (Turbopack/HMR).
  // accounts.google.com/gsi/client is the Google Identity Services button script.
  `script-src 'self' 'unsafe-inline' https://accounts.google.com/gsi/client${process.env.NODE_ENV === "production" ? "" : " 'unsafe-eval'"}`,
  `style-src 'self' 'unsafe-inline' https://fonts.googleapis.com`,
  `font-src 'self' https://fonts.gstatic.com`,
  `img-src 'self' data: blob:`,
  `connect-src 'self' ${apiOrigin()} https://accounts.google.com${process.env.NODE_ENV === "production" ? "" : " ws:"}`,
  // The GIS button renders in an iframe from accounts.google.com.
  `frame-src https://accounts.google.com`,
  `frame-ancestors 'none'`,
  `base-uri 'self'`,
  `form-action 'self'`,
].join("; ");

const securityHeaders = [
  { key: "Content-Security-Policy", value: csp },
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "X-Frame-Options", value: "DENY" },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=()" },
  // Only meaningful over HTTPS; ignored by browsers on http (dev).
  { key: "Strict-Transport-Security", value: "max-age=63072000; includeSubDomains; preload" },
];

const nextConfig: NextConfig = {
  // Self-contained server bundle for Docker / non-Vercel hosting.
  output: "standalone",
  async headers() {
    return [{ source: "/:path*", headers: securityHeaders }];
  },
};

export default nextConfig;
