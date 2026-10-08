import { RootDocument, rootMetadata } from "@/components/RootDocument";
import { routing } from "@/i18n/routing";

export const metadata = rootMetadata;

/** The root layout of the bare "/" route (LIF-142): it only ever redirects to the default locale. */
export default function EntryRootLayout({ children }: { children: React.ReactNode }) {
  return <RootDocument lang={routing.defaultLocale}>{children}</RootDocument>;
}
