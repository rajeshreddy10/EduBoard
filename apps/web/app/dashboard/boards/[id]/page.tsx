import React from "react";
import SavedBoardRedirectClient from "./SavedBoardRedirectClient";

/**
 * Board deep-link route.
 *
 * `/dashboard/boards/<id>` resolves an EXISTING board record (React context →
 * localStorage → Firestore) and forwards the SAME board id to the correct
 * studio route. Board ids are user-created and unbounded, so the export
 * prerenders ONE canonical page (the `default` "continue last session"
 * entry) and every REAL board deep link is resolved client-side:
 *
 * - Static export (GitHub Pages): unknown ids are served by 404.html
 *   (app/not-found.tsx), which forwards to the static resolve view with
 *   `?id=<boardId>` on the static sibling routes.
 * - Dynamic hosts (Vercel / local): ids beyond the seeded one are rendered
 *   on demand at runtime.
 */
export function generateStaticParams() {
  return [{ id: 'default' }];
}

export default function SavedBoardRedirectPage() {
  return <SavedBoardRedirectClient />;
}
