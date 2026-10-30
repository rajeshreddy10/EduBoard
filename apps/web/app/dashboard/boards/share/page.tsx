"use client";

import React, { Suspense } from "react";
import { useSearchParams } from "next/navigation";
import ShareClient from "../[id]/share/ShareClient";

/**
 * Static-host view of board sharing.
 * Deep links `/{host}/dashboard/boards/<id>/share` fall back here
 * (see app/not-found.tsx) carrying the SAME board id via `?id=`.
 */
export default function ShareBoardStaticPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs font-bold text-[var(--text-tertiary)]">Loading sharing...</div>}>
      <ShareClientWithSearch />
    </Suspense>
  );
}

function ShareClientWithSearch() {
  const searchParams = useSearchParams();
  const boardId = searchParams?.get('id') || '';
  return <ShareClient boardId={boardId} />;
}
