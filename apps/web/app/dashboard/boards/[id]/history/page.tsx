import React from "react";
import HistoryClient from "./HistoryClient";

// Board ids are unbounded — strategy note in `boards/[id]/page.tsx`.
export function generateStaticParams() {
  return [{ id: 'default' }];
}

export default function BoardHistoryPage() {
  return <HistoryClient />;
}
