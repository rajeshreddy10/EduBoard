"use client";

import React, { Suspense } from "react";
import { useSearchParams } from "next/navigation";
import ActivityClient from "../[id]/activity/ActivityClient";

/**
 * Static-host view of board activity.
 * Deep links `/{host}/dashboard/boards/<id>/activity` fall back here
 * (see app/not-found.tsx) carrying the SAME board id via `?id=`.
 */
export default function BoardActivityStaticPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs font-bold text-[var(--text-tertiary)]">Loading activity...</div>}>
      <ActivityClientWithSearch />
    </Suspense>
  );
}

function ActivityClientWithSearch() {
  const searchParams = useSearchParams();
  const boardId = searchParams?.get('id') || '';
  return <ActivityClient boardId={boardId} />;
}
