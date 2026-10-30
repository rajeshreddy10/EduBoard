"use client";

import React, { Suspense } from "react";
import { useSearchParams } from "next/navigation";
import HistoryClient from "../[id]/history/HistoryClient";

/**
 * Static-host view of board version history.
 * Deep links `/{host}/dashboard/boards/<id>/history` fall back here
 * (see app/not-found.tsx) carrying the SAME board id via `?id=`.
 */
export default function BoardHistoryStaticPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs font-bold text-[var(--text-tertiary)]">Loading version history...</div>}>
      <HistoryClientWithSearch />
    </Suspense>
  );
}

function HistoryClientWithSearch() {
  const searchParams = useSearchParams();
  const boardId = searchParams?.get('id') || '';
  return <HistoryClient boardId={boardId} />;
}
