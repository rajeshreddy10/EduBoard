"use client";

import React, { useEffect } from "react";
import { useRouter } from "next/navigation";
import { Compass } from "lucide-react";

/**
 * Global not-found page — doubles as the static-hosting deep-link fallback.
 *
 * GitHub Pages can only serve pre-rendered files, so deep links like
 * `/{repo}/dashboard/boards/<boardId>` land here. This page detects that
 * pattern and forwards the visitor to the correct studio route while keeping
 * the SAME board id (`?id=<boardId>`), so the original board still opens.
 * On SSR hosts (Vercel) the dynamic routes render normally and this page is
 * only reached for genuinely unknown URLs.
 */
export default function NotFound() {
  const router = useRouter();

  useEffect(() => {
    const rawPath = window.location.pathname.replace(/\/+$/, '');
    const base = (process.env.NEXT_PUBLIC_BASE_PATH || '').replace(/\/+$/, '');
    const path = base && rawPath.startsWith(base) ? rawPath.slice(base.length) : rawPath;
    const query = window.location.search || '';

    const boardMatch = path.match(/^\/dashboard\/boards\/([^/]+)(?:\/(activity|history|share))?$/);
    if (boardMatch) {
      const boardId = decodeURIComponent(boardMatch[1]);
      const view = boardMatch[2];
      const extraQuery = query ? `&${query.replace(/^\?/, '')}` : '';
      // Static-safe version view with the SAME board id.
      const target = `/dashboard/boards/${view || 'history'}?id=${encodeURIComponent(boardId)}${extraQuery}`;
      router.replace(target);
      return;
    }

    // Everything else stays on the standard 404 view.
  }, [router]);

  return (
    <div className="min-h-screen bg-[var(--bg-primary)] flex flex-col items-center justify-center gap-6 p-6 text-center">
      <div className="w-16 h-16 rounded-2xl bg-[var(--bg-secondary)] border border-[var(--border-primary)] flex items-center justify-center shadow-sm">
        <Compass className="w-7 h-7 text-[var(--color-primary-500)]" />
      </div>
      <div className="space-y-2">
        <h1 className="text-4xl font-black tracking-tight text-[var(--text-primary)]">404</h1>
        <p className="text-sm font-bold text-[var(--text-primary)]">This page could not be found.</p>
        <p className="text-xs text-[var(--text-tertiary)] max-w-sm leading-relaxed">
          If you opened a board link, it is being restored automatically. Otherwise, the
          page may have been moved or removed.
        </p>
      </div>
      <div className="flex items-center gap-3">
        <a
          href={(process.env.NEXT_PUBLIC_BASE_PATH || '') + "/dashboard"}
          className="px-4 py-2 rounded-xl bg-[var(--color-primary-500)] text-white text-xs font-bold hover:bg-[var(--color-primary-600)] transition-all shadow-sm"
        >
          Go to Dashboard
        </a>
        <a
          href={(process.env.NEXT_PUBLIC_BASE_PATH || '') + "/dashboard/boards"}
          className="px-4 py-2 rounded-xl bg-[var(--bg-secondary)] border border-[var(--border-primary)] text-xs font-bold text-[var(--text-primary)] hover:bg-[var(--bg-hover)] transition-all"
        >
          Saved History
        </a>
      </div>
    </div>
  );
}
