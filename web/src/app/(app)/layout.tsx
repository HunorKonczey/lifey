import { RootDocument, rootMetadata } from "@/components/RootDocument";
import { ErrorBoundary } from "@/components/status/ErrorBoundary";
import { AppLayoutClient } from "./AppLayoutClient";

export const metadata = rootMetadata;

/**
 * The root layout of this route group (LIF-142): the document with `lang="en"` — the signed-in app picks its language on
 * the client, `DocumentLang` corrects the attribute afterwards. The group's own layout is a client component
 * (providers, auth gate) and cannot be a root layout itself, so it sits inside; the boundary catches what it throws.
 */
export default function AppLayout({ children }: { children: React.ReactNode }) {
  return (
    <RootDocument lang="en">
      <ErrorBoundary>
        <AppLayoutClient>{children}</AppLayoutClient>
      </ErrorBoundary>
    </RootDocument>
  );
}
