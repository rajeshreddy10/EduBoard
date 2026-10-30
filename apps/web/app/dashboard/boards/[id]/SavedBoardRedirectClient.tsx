"use client";

import React, { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { useAuth } from "@/lib/AuthContext";
import { useBoard } from "@/lib/BoardContext";
import { getBoard } from "@/lib/store";
import { historyService } from "@/lib/services/firebaseData";
import { buildBoardUrl, STUDIO_LABEL } from "@/lib/boardRouting";
import { resolveBoardStudio } from "@/lib/boardRouting";
import type { Board } from "@/lib/types";

/**
 * Canonical board deep-link resolver.
 *
 * Resolves an EXISTING board record (context → localStorage → Firestore) and
 * forwards the SAME board id to the matching studio route (`?id=`). The board
 * id is never regenerated, no new record is created, and content is never
 * reset — the studio restores the exact saved state and continues editing.
 */
export default function SavedBoardRedirectClient() {
  const params = useParams();
  const router = useRouter();
  const { user } = useAuth();
  const { boards } = useBoard();
  const boardId = (params?.id as string) || '';
  const [progress, setProgress] = useState('Looking up saved board...');

  useEffect(() => {
    let isMounted = true;

    async function loadAndRedirect() {
      if (!boardId) return;

      let b = boards.find(item => item.id === boardId) || getBoard(boardId);

      if (!b && user?.id) {
        setProgress('Fetching board from cloud...');
        try {
          const firestoreBoard = await historyService.getHistoryItem(user.id, boardId);
          if (firestoreBoard) {
            b = firestoreBoard as Board;
          }
        } catch (err) {
          console.warn("Failed to fetch board from Firestore:", err);
        }
      }

      if (!isMounted) return;

      const title = b?.title;
      const url = buildBoardUrl(b || { id: boardId });
      const studio = resolveBoardStudio(b || { id: boardId });
      setProgress(`Restoring "${title || 'saved board'}" in ${STUDIO_LABEL[studio]}...`);
      console.log(`[Board Restore] Resuming "${boardId}" via ${url} (original state, same board id).`);
      router.replace(url);
    }

    loadAndRedirect();
    return () => { isMounted = false; };
  }, [boardId, boards, user?.id, router]);

  return (
    <div className="h-screen w-screen bg-slate-950 flex flex-col items-center justify-center text-white text-xs font-semibold gap-3">
      <div className="w-8 h-8 rounded-full border-2 border-indigo-500 border-t-transparent animate-spin" />
      <span>{progress}</span>
    </div>
  );
}
