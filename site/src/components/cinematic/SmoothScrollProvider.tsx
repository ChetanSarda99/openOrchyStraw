"use client";

/**
 * Stub. The shared cinematic library ships a Lenis-backed smooth scroll
 * provider, but this site does not include lenis as a dep. Re-export a
 * pass-through so any accidental import compiles. If you want real
 * inertia, `npm i lenis` and copy the original from
 * ~/Projects/shared/components/cinematic/SmoothScrollProvider.tsx.
 */

import { PropsWithChildren } from "react";

export function SmoothScrollProvider({ children }: PropsWithChildren<{}>) {
  return <>{children}</>;
}
