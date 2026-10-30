"use client";
import React, { useState, useEffect } from "react";
import { useParams, useRouter } from "next/navigation";
import { History, ArrowLeft, RotateCcw, Clock, Loader2 } from "lucide-react";
import { useAuth } from "@/lib/AuthContext";
import { historyService } from "@/lib/services/firebaseData";
import { buildBoardUrl } from "@/lib/boardRouting";
import type { Board } from "@/lib/types";

interface VersionItem {
  id: string;
  createdAt: string;
  createdBy: string;
  title?: string;
  description?: string;
  strokes?: any[];
  elements?: any[];
}

/**
 * Board deep-link resolver only renders to the static route via `?id=` when the
 * board path is unknown; on SSR hosts the dynamic `[id]` route supplies it.
 */
export default function BoardHistory({ boardId: boardIdProp }: { boardId?: string }) {
  const params = useParams();
  const router = useRouter();
  const boardId = boardIdProp || ((params?.id as string) || '');
  const { user } = useAuth();
  const [versions, setVersions] = useState<VersionItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [restoringId, setRestoringId] = useState<string | null>(null);

  useEffect(() => {
    let isMounted = true;
    async function loadVersions() {
      if (!boardId) {
        if (isMounted) setLoading(false);
        return;
      }
      try {
        const list = await historyService.getBoardVersions(boardId) as any[];
        if (isMounted) {
          setVersions((list || []).map((v: any) => ({
            id: v.id,
            createdAt: v.created_at || v.createdAt || new Date().toISOString(),
            createdBy: v.createdBy || v.created_by || 'You',
            title: v.title || 'Manual Save Snapshot',
            description: v.description || '',
            strokes: v.strokes || [],
            elements: v.elements || [],
          })));
        }
      } catch (err) {
        console.warn("Failed to load versions:", err);
      } finally {
        if (isMounted) setLoading(false);
      }
    }
    loadVersions();
    return () => { isMounted = false; };
  }, [boardId, user?.id]);

  const handleRestore = async (version: VersionItem) => {
    setRestoringId(version.id);
    try {
      const restored = await historyService.restoreBoardVersion(boardId, version.id);
      if (restored) {
        router.replace(buildBoardUrl(restored as Board));
      }
    } catch (err) {
      console.error('Failed to restore version:', err);
      setRestoringId(null);
    }
  };

  const formatDate = (isoStr: string) => {
    try {
      const d = new Date(isoStr);
      return d.toLocaleString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
    } catch {
      return 'Recently';
    }
  };

  return (
    <div style={{ maxWidth: 800, margin: "0 auto" }} className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <History className="w-6 h-6 text-[var(--color-primary-500)]" />
            <h1 className="text-2xl font-black text-[var(--text-primary)]">Version History</h1>
          </div>
          <p className="text-xs text-[var(--text-tertiary)] font-semibold">
            {loading ? "Loading snapshots..." : `${versions.length} saved version snapshots for this session`}
          </p>
        </div>
        <button
          onClick={() => router.back()}
          className="px-4 py-2 rounded-xl bg-[var(--bg-secondary)] border border-[var(--border-primary)] text-xs font-bold text-[var(--text-primary)] hover:border-[var(--color-primary-500)] flex items-center gap-2 transition-all cursor-pointer"
        >
          <ArrowLeft size={14} />
          <span>Back to Editor</span>
        </button>
      </div>

      {loading ? (
        <div className="p-8 text-center text-xs font-bold text-[var(--text-tertiary)] flex items-center justify-center gap-2">
          <Loader2 className="w-4 h-4 animate-spin" />
          Loading version snapshots...
        </div>
      ) : versions.length === 0 ? (
        <div className="p-12 rounded-3xl bg-[var(--bg-secondary)] border border-dashed border-[var(--border-primary)] text-center space-y-3">
          <Clock className="w-12 h-12 text-[var(--text-tertiary)] mx-auto opacity-40" />
          <p className="text-sm font-bold text-[var(--text-primary)]">No version snapshots recorded yet</p>
          <p className="text-xs text-[var(--text-tertiary)]">Click the Save button in the editor header to capture your first snapshot version.</p>
        </div>
      ) : (
        <div className="space-y-4">
          {versions.map((v, idx) => (
            <div key={v.id} className="p-5 rounded-2xl bg-[var(--bg-secondary)] border border-[var(--border-primary)] shadow-sm flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div className="flex items-center gap-3 min-w-0">
                <div className={`w-3 h-3 rounded-full ${idx === 0 ? 'bg-emerald-500' : 'bg-blue-500/50'} shrink-0`} />
                <div className="min-w-0">
                  <div className="text-sm font-bold text-[var(--text-primary)] flex items-center gap-2 flex-wrap">
                    <span className="truncate">{v.title || `Snapshot ${v.id}`}</span>
                    {idx === 0 && <span className="px-2 py-0.5 rounded-full text-[9px] font-black bg-emerald-500/10 text-emerald-600 uppercase">Latest</span>}
                  </div>
                  <div className="text-xs text-[var(--text-tertiary)] font-medium mt-0.5">
                    Snapshotted {formatDate(v.createdAt)} • {(v.strokes || []).length} strokes, {(v.elements || []).length} annotations
                  </div>
                </div>
              </div>
              <button
                onClick={() => handleRestore(v)}
                disabled={restoringId === v.id}
                className="px-3 py-1.5 rounded-lg bg-[var(--bg-tertiary)] text-xs font-bold text-[var(--color-primary-500)] hover:bg-[var(--color-primary-500)] hover:text-white transition-all flex items-center gap-1 cursor-pointer shrink-0 disabled:opacity-60"
                title="Restore this snapshot into the board (same board record, same id)"
              >
                {restoringId === v.id ? <Loader2 size={12} className="animate-spin" /> : <RotateCcw size={12} />}
                <span>{restoringId === v.id ? 'Restoring...' : 'Restore'}</span>
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
