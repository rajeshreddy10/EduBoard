import React from "react";
import ActivityClient from "./ActivityClient";

// Board ids are unbounded — see the strategy note in `boards/[id]/page.tsx`:
// the export prerenders only the canonical `default` page and real board
// deep links resolve through 404.html → static `?id=` view. Dynamic hosts
// render every board id on demand.
export function generateStaticParams() {
  return [{ id: 'default' }];
}

export default function BoardActivityPage() {
  return <ActivityClient />;
}
