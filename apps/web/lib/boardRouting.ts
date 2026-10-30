'use client';

import type { Board } from '@/lib/types';

/**
 * Board routing & studio resolution.
 *
 * EduBoard ships to multiple hosts (Vercel SSR, GitHub Pages static export,
 * Electron). User-created board IDs are dynamic, so the `/dashboard/boards/[id]`
 * route cannot be pre-rendered for every board. All in-app "open board"
 * navigation therefore goes through the STATIC studio routes carrying the
 * SAME board id via `?id=`, which the studios use to restore the exact state.
 *
 * The `/dashboard/boards/[id]` dynamic route remains only as a canonical
 * deep-link endpoint for SSR hosts (Vercel) and is resolved client-side.
 */

export type BoardStudio = 'drawspace' | 'voiceboard' | 'doccanvas';

export const STUDIO_ROUTE: Record<BoardStudio, string> = {
  drawspace: '/normal-board',
  voiceboard: '/voice-control',
  doccanvas: '/gesture-board',
};

export const STUDIO_LABEL: Record<BoardStudio, string> = {
  drawspace: 'DrawSpace Whiteboard',
  voiceboard: 'Voice Board AI',
  doccanvas: 'DocCanvas Annotator',
};

function inferStudioFromIdentity(id: string, title?: string): BoardStudio | null {
  const idLower = (id || '').toLowerCase();
  const titleLower = (title || '').toLowerCase();

  if (idLower.startsWith('doccanvas') || idLower.startsWith('gesture') || titleLower.includes('doccanvas')) {
    return 'doccanvas';
  }
  if (idLower.startsWith('voiceboard') || idLower.startsWith('voice-') || (titleLower.includes('voice') && !titleLower.includes('drawspace'))) {
    return 'voiceboard';
  }
  if (idLower.startsWith('drawspace') || idLower.startsWith('normal')) {
    return 'drawspace';
  }
  return null;
}

/**
 * Resolve which studio a board should open in. Preference order:
 *  1. Explicit `studio` field (written by every save since v3.1).
 *  2. Board id / title identity (legacy boards and seed boards).
 *  3. Fallback — DrawSpace (generic whiteboard).
 */
export function resolveBoardStudio(board?: { id?: string; title?: string; studio?: string } | null): BoardStudio {
  if (!board) return 'drawspace';
  const explicit = (board.studio || '') as BoardStudio;
  if (explicit === 'drawspace' || explicit === 'voiceboard' || explicit === 'doccanvas') {
    return explicit;
  }
  return inferStudioFromIdentity(board.id || '', board.title) || 'drawspace';
}

/**
 * URL to open an existing board in its studio. The board id is preserved so
 * the studio restores the exact same record — never a new board/id.
 */
export function buildBoardUrl(board: { id: string; title?: string; studio?: string }): string {
  if (!board?.id) return '/normal-board';
  const route = STUDIO_ROUTE[resolveBoardStudio(board)];
  return `${route}?id=${encodeURIComponent(board.id)}`;
}

/**
 * Convenience used by list UIs (Recent Boards, History hub, search results).
 */
export function boardHref(board: Board): string {
  return buildBoardUrl(board);
}
