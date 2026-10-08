import { RootDocument, rootMetadata } from "@/components/RootDocument";

export const metadata = rootMetadata;

/** The root layout of this route group (LIF-142); its own layouts further down do the real work. */
export default function GroupRootLayout({ children }: { children: React.ReactNode }) {
  return <RootDocument lang="en">{children}</RootDocument>;
}
