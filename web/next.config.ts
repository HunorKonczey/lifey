import type { NextConfig } from "next";

// Derive the backend origins (scheme + host) from the configured base URLs so
// the CSP connect-src allows calls to them (and nothing else).
function originOf(value: string | undefined): string | null {
  if (!value) return null;
  try {
    return new URL(value).origin;
  } catch {
    return null;
  }
}

/**
 * Everything the browser is allowed to call: the main API, plus the chat
 * service since the split (docs/chat/44-chat-service-extraction-plan.md §7.1).
 *
 * <p><b>Why NEXT_PUBLIC_CHAT_BASE_URL is effectively required on the web,</b>
 * even though the chat's URL is otherwise resolved at runtime from
 * `/client-config`. A CSP header is fixed at build time, so an origin the build
 * never heard of is blocked by the browser no matter what the config endpoint
 * says. The runtime lookup still buys the thing it was built for — pointing the
 * chat back at the main API is a server-side change with no redeploy — but
 * moving the chat to a *different host* needs this variable updated and the web
 * rebuilt.
 */
function connectOrigins(): string {
  const api = originOf(process.env.NEXT_PUBLIC_API_BASE_URL) ?? "http://localhost:8080";
  const chat = originOf(process.env.NEXT_PUBLIC_CHAT_BASE_URL);
  return [...new Set([api, ...(chat ? [chat] : [])])].join(" ");
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
  `connect-src 'self' ${connectOrigins()} https://accounts.google.com${process.env.NODE_ENV === "production" ? "" : " ws:"}`,
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
