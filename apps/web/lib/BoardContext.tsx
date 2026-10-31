'use client';

import React, { createContext, useContext, useState, useCallback, ReactNode, useRef, useEffect } from 'react';
import { Board, DrawingStroke } from '@/lib/types';
import * as store from '@/lib/store';
import { socketService } from '@/lib/socket';
import { historyService } from '@/lib/services/firebaseData';
import { useAuth } from '@/lib/AuthContext';
import { resolveBoardStudio } from '@/lib/boardRouting';
import { doc, onSnapshot } from 'firebase/firestore';
import { db } from '@/lib/firebase';

interface BoardContextType {
  currentBoard: Board | null;
  boards: Board[];
  strokes: DrawingStroke[];
  selectedTool: string;
  selectedColor: string;
  strokeWidth: number;
  opacity: number;
  zoom: number;
  offset: { x: number; y: number };
  isDrawing: boolean;
  collaborators: { userId: string; name: string; color: string; cursor?: { x: number; y: number } }[];
  undoStack: DrawingStroke[][];
  redoStack: DrawingStroke[][];
  waypoints: { id: string; name: string; x: number; y: number; zoom: number }[];
  addWaypoint: (name: string) => void;
  goToWaypoint: (id: string) => void;
  removeWaypoint: (id: string) => void;
  setCurrentBoard: (board: Board | null) => void;
  setSelectedTool: (tool: string) => void;
  setSelectedColor: (color: string) => void;
  setStrokeWidth: (width: number) => void;
  setOpacity: (opacity: number) => void;
  setZoom: (zoom: number) => void;
  setOffset: (offset: { x: number; y: number }) => void;
  setIsDrawing: (drawing: boolean) => void;
  addStroke: (stroke: DrawingStroke) => void;
  undo: () => void;
  redo: () => void;
  clearBoard: () => void;
  loadBoard: (id: string) => Promise<void>;
  createBoard: (title?: string, description?: string, template?: string) => Board;
  saveBoard: (payload?: Board) => Promise<void>;
  duplicateBoard: (source: Board) => Board | null;
  deleteBoard: (id: string) => Promise<void>;
  exportBoard: (format: 'png' | 'pdf' | 'svg' | 'json') => void;
}

const BoardContext = createContext<BoardContextType | undefined>(undefined);

export function BoardProvider({ children }: { children: ReactNode }) {
  const { user } = useAuth();
  const [currentBoard, setCurrentBoard] = useState<Board | null>(null);
  const [boards, setBoards] = useState<Board[]>([]);
  const [strokes, setStrokes] = useState<DrawingStroke[]>([]);
  const [selectedTool, setSelectedTool] = useState('pen');
  const [selectedColor, setSelectedColor] = useState('#6366f1');
  const [strokeWidth, setStrokeWidth] = useState(3);
  const [opacity, setOpacity] = useState(1);
  const [zoom, setZoom] = useState(100);
  const [offset, setOffset] = useState({ x: 0, y: 0 });
  const [isDrawing, setIsDrawing] = useState(false);
  const [undoStack, setUndoStack] = useState<DrawingStroke[][]>([]);
  const [redoStack, setRedoStack] = useState<DrawingStroke[][]>([]);
  const [waypoints, setWaypoints] = useState<{ id: string; name: string; x: number; y: number; zoom: number }[]>([]);
  const [collaborators, setCollaborators] = useState<any[]>([]);
  const strokesRef = useRef<DrawingStroke[]>([]);
  // Tracks the cloud signature of the last save to prevent duplicate Firestore writes.
  const lastCloudSignatureRef = useRef<string>('');
  // Guard so the one-time localStorage→Firestore seed doesn't loop.
  const seedSyncedRef = useRef(false);

  const addWaypoint = useCallback((name: string) => {
    const newWaypoint = {
      id: Date.now().toString(),
      name: name || `View ${waypoints.length + 1}`,
      x: offset.x,
      y: offset.y,
      zoom: zoom
    };
    setWaypoints(prev => [...prev, newWaypoint]);
    store.addActivity({ type: 'board_edited', description: `Added waypoint "${name}"` });
  }, [offset, zoom, waypoints.length]);

  const goToWaypoint = useCallback((id: string) => {
    const wp = waypoints.find(w => w.id === id);
    if (wp) {
      // Smoothly update the view
      setOffset({ x: wp.x, y: wp.y });
      setZoom(wp.zoom);
    }
  }, [waypoints]);

  const removeWaypoint = useCallback((id: string) => {
    setWaypoints(prev => prev.filter(w => w.id !== id));
  }, []);

  useEffect(() => { strokesRef.current = strokes; }, [strokes]);

  // Load user boards/history from Firestore if user logged in, else fallback to local store
  useEffect(() => {
    seedSyncedRef.current = false;
    if (user?.id) {
      const unsub = historyService.subscribeToHistory(user.id, (firestoreItems) => {
        if (firestoreItems.length > 0) {
          setBoards(firestoreItems);
        } else if (!seedSyncedRef.current) {
          // If Firestore is empty, seed with local store (once per login session)
          seedSyncedRef.current = true;
          const local = store.getBoards();
          setBoards(local);
          local.forEach(b => {
            historyService.saveHistoryItem(user.id, {
              ...b,
              createdBy: b.createdBy && b.createdBy !== 'u1' ? b.createdBy : user.id,
              createdAt: b.createdAt || new Date().toISOString(),
              studio: (b as any).studio || resolveBoardStudio(b),
            }).catch(console.error);
          });
        }
      });
      return () => { if (unsub) unsub(); };
    } else {
      setBoards(store.getBoards());
    }
  }, [user?.id]);

  useEffect(() => {
    const unsubStroke = socketService.onStroke((data) => {
      if (data.boardId === currentBoard?.id) {
        setStrokes(prev => [...prev, data.stroke]);
      }
    });
    const unsubCursor = socketService.onCursor((data) => {
      if (data.boardId === currentBoard?.id) {
        setCollaborators(prev => prev.map(c => c.userId === data.userId ? { ...c, cursor: data.position } : c));
      }
    });
    return () => { unsubStroke(); unsubCursor(); };
  }, [currentBoard?.id]);

  // Real-time Firestore sync for the active board across Web and Mobile
  useEffect(() => {
    if (!currentBoard?.id) return;
    const boardDocRef = doc(db, 'whiteboards', currentBoard.id);
    const unsubBoard = onSnapshot(boardDocRef, (snapshot) => {
      if (!snapshot.exists() || snapshot.metadata.hasPendingWrites) return;
      const data = snapshot.data();
      if (!data) return;

      const remoteStrokes = Array.isArray(data.strokes) ? data.strokes : [];
      const remoteElements = Array.isArray(data.elements) ? data.elements : [];

      const remoteSig = lastCloudSignatureKey(remoteStrokes);
      const localSig = lastCloudSignatureKey(strokesRef.current);

      if (remoteSig !== localSig && remoteStrokes.length > 0) {
        lastCloudSignatureRef.current = [
          currentBoard.id,
          data.title || currentBoard.title,
          remoteStrokes.length,
          remoteElements.length,
          JSON.stringify(remoteElements),
          data.teacherNotes?.length || 0,
          data.activeDocument?.name || '',
          remoteSig,
        ].join('|');
        setStrokes(remoteStrokes);
      }

      setCurrentBoard(prev => {
        if (!prev || prev.id !== currentBoard.id) return prev;
        return {
          ...prev,
          title: data.title || prev.title,
          description: data.description !== undefined ? data.description : prev.description,
          elements: remoteElements.length > 0 ? remoteElements : prev.elements,
          teacherNotes: data.teacherNotes !== undefined ? data.teacherNotes : (prev as any).teacherNotes,
          updatedAt: data.updatedAt || data.updated_at || prev.updatedAt,
        };
      });
    }, (err) => {
      console.warn('[Firebase Firestore] [whiteboards] Active board snapshot notice:', err);
    });

    return () => {
      unsubBoard();
    };
  }, [currentBoard?.id]);

  // Debounced auto-sync to Firestore when canvas changes on Web
  const autoSyncTimerRef = useRef<NodeJS.Timeout | null>(null);
  useEffect(() => {
    if (!currentBoard?.id || !user?.id || strokes.length === 0) return;

    if (autoSyncTimerRef.current) {
      clearTimeout(autoSyncTimerRef.current);
    }

    autoSyncTimerRef.current = setTimeout(() => {
      saveBoard().catch(err => {
        console.warn('[BoardContext] Auto-sync board notice:', err);
      });
    }, 2000);

    return () => {
      if (autoSyncTimerRef.current) {
        clearTimeout(autoSyncTimerRef.current);
      }
    };
  }, [strokes, currentBoard?.id, user?.id, saveBoard]);

  const addStroke = useCallback((stroke: DrawingStroke) => {
    setStrokes(prev => {
      setUndoStack(u => [...u, prev]);
      const next = [...prev, stroke];
      strokesRef.current = next;
      setRedoStack([]);
      return next;
    });
    if (currentBoard) socketService.sendStroke(currentBoard.id, stroke);
  }, [currentBoard]);

  const undo = useCallback(() => {
    if (undoStack.length === 0) return;
    const prev = undoStack[undoStack.length - 1];
    setUndoStack(u => u.slice(0, -1));
    setRedoStack(r => [...r, strokes]);
    setStrokes(prev);
  }, [undoStack, strokes]);

  const redo = useCallback(() => {
    if (redoStack.length === 0) return;
    const next = redoStack[redoStack.length - 1];
    setRedoStack(r => r.slice(0, -1));
    setUndoStack(u => [...u, strokes]);
    setStrokes(next);
  }, [redoStack, strokes]);

  const clearBoard = useCallback(() => {
    setUndoStack(u => [...u, strokes]);
    setStrokes([]);
    setRedoStack([]);
  }, [strokes]);

  const loadBoard = useCallback(async (id: string) => {
    let board = boards.find(b => b.id === id) || store.getBoard(id);
    if (!board && user?.id) {
      board = (await historyService.getHistoryItem(user.id, id)) || undefined;
    }
    if (board) {
      setCurrentBoard(board);
      let loadedStrokes: DrawingStroke[] = [];
      const rawStrokes = board.strokes && Array.isArray(board.strokes) ? board.strokes : null;
      if (rawStrokes && rawStrokes.length > 0) {
        loadedStrokes = rawStrokes.map((s: any) => ({
          ...s,
          width: s.width || s.strokeWidth || 3,
          color: s.color || s.colorHex || '#ffffff',
          tool: s.tool || s.type || 'pen',
        })) as any;
      } else if (board.content && typeof board.content === 'string') {
        try {
          const parsed = JSON.parse(board.content);
          const contentStrokes = Array.isArray(parsed) ? parsed : (parsed?.strokes || []);
          loadedStrokes = contentStrokes.map((s: any) => ({
            ...s,
            width: s.width || s.strokeWidth || 3,
            color: s.color || s.colorHex || '#ffffff',
            tool: s.tool || s.type || 'pen',
          }));
        } catch {}
      }
      if (loadedStrokes.length === 0) {
        const local = store.getDrawings(id);
        if (local && local.length > 0) loadedStrokes = local;
      }
      setStrokes(loadedStrokes);
      setUndoStack([]);
      setRedoStack([]);
      socketService.joinBoard(id);
    }
  }, [boards, user]);

  const createBoard = useCallback((title?: string, description?: string, template?: string) => {
    const board = store.createBoard({
      title: title || 'Untitled Board',
      description: description || '',
      createdBy: user?.id || 'u1',
      studio: 'drawspace',
      ...(template && template !== 'blank' ? { tags: [template] } : {}),
    } as any);
    if (user?.id) {
      historyService.saveHistoryItem(user.id, board).catch(console.error);
    }
    setBoards(prev => [board, ...prev.filter(b => b.id !== board.id)]);
    loadBoard(board.id);
    store.addActivity({ type: 'board_created', description: `Created session "${board.title}"` });
    return board;
  }, [loadBoard, user]);

  /**
   * Unified board save (button + auto-save share this path).
   *
   * Guarantees:
   *  - One Firestore document per board id ({merge:true}) — never forks a board.
   *  - Ownership & created-at metadata are preserved; the current user only
   *    fills gaps (owner_id remains the board's real owner).
   *  - Identical consecutive payloads skip cloud writes (no duplicate saves).
   *  - Marker: payload may carry teacher notes, elements, activeDocument.
   */
  const saveBoard = useCallback(async (payload?: Board) => {
    const targetBoard = payload || currentBoard;
    if (!targetBoard) return;

    const strokesToSave = (payload?.strokes || strokes) as any[];
    const elementsToSave = (payload?.elements || []) as any[];
    const teacherNotes = (payload as any)?.teacherNotes;

    // Content signature — identical content means no redundant write.
    const signature = [
      targetBoard.id,
      targetBoard.title,
      strokesToSave.length,
      elementsToSave.length,
      JSON.stringify(elementsToSave),
      teacherNotes?.length || 0,
      (payload as any)?.activeDocument?.name || '',
      lastCloudSignatureKey(strokesToSave),
    ].join('|');
    if (signature === lastCloudSignatureRef.current) {
      return; // duplicate save attempt — skip silently (prevents write spam)
    }
    lastCloudSignatureRef.current = signature;

    // Metadata integrity: never invent a new identity for an existing board.
    const existing = boards.find(b => b.id === targetBoard.id)
      || (currentBoard?.id === targetBoard.id ? currentBoard : undefined)
      || store.getBoard(targetBoard.id);

    const nowIso = new Date().toISOString();
    const updatedBoard: Board = {
      ...(existing || {}),
      ...targetBoard,
      content: payload?.content || JSON.stringify({ strokes: strokesToSave, elements: elementsToSave }),
      strokes: strokesToSave,
      elements: elementsToSave,
      ...((payload as any)?.teacherNotes ? { teacherNotes: teacherNotes } : {}),
      studio: ((targetBoard as any).studio
        || existing?.studio
        || resolveBoardStudio({ id: targetBoard.id, title: targetBoard.title })) as Board['studio'],
      createdAt: targetBoard.createdAt || existing?.createdAt || nowIso,
      createdBy: (targetBoard.createdBy && targetBoard.createdBy !== 'guest' && targetBoard.createdBy !== 'u1'
        ? targetBoard.createdBy
        : existing?.createdBy) || user?.id || 'guest',
      updatedAt: nowIso,
      width: targetBoard.width || 1920,
      height: targetBoard.height || 1080,
      zoom: targetBoard.zoom || 100,
    } as Board;

    store.saveDrawings(targetBoard.id, strokesToSave);
    store.updateBoard(targetBoard.id, updatedBoard as Board);

    if (user?.id) {
      await historyService.saveHistoryItem(user.id, updatedBoard);
    }

    setCurrentBoard(updatedBoard);
    setBoards(prev => {
      const idx = prev.findIndex(b => b.id === targetBoard.id);
      if (idx !== -1) {
        const next = [...prev];
        next[idx] = updatedBoard;
        return next;
      }
      return [updatedBoard, ...prev];
    });

    store.addActivity({ type: 'board_edited', description: `Saved history session "${targetBoard.title}"` });
  }, [currentBoard, strokes, boards, user]);

  /**
   * Duplicate creates an INDEPENDENT copy with a NEW id and fresh timestamps.
   * This is the only flow that is allowed to mint a new board identity.
   */
  const duplicateBoard = useCallback((source: Board): Board | null => {
    if (!source?.id) return null;
    const nowIso = new Date().toISOString();
    const studio = resolveBoardStudio(source);
    const prefix = studio === 'voiceboard' ? 'voiceboard' : studio === 'doccanvas' ? 'doccanvas' : 'drawspace';
    const copy: Board = {
      ...source,
      id: `${prefix}_${Date.now()}_${Math.random().toString(36).slice(2, 9)}`,
      title: `${source.title || 'Untitled Board'} (Copy)`,
      createdAt: nowIso,
      updatedAt: nowIso,
      createdBy: user?.id || source.createdBy || 'guest',
      isShared: false,
      sharedWith: [],
      content: source.content ? String(source.content) : undefined,
      strokes: source.strokes ? [...source.strokes] : [],
      elements: source.elements ? [...source.elements] : [],
      studio,
    } as Board;

    store.saveDrawings(copy.id, (copy.strokes || []) as any[]);
    store.upsertBoard(copy);

    if (user?.id) {
      historyService.saveHistoryItem(user.id, copy).catch(console.error);
    }
    setBoards(prev => [copy, ...prev.filter(b => b.id !== copy.id)]);
    store.addActivity({ type: 'board_created', description: `Duplicated session "${source.title}"` });
    return copy;
  }, [user]);

  /**
   * Delete removes the board record, local drawings cache AND cloud version
   * snapshots (service side uses one Firestore batch). Ownership is validated
   * before deleting to prevent data loss from broken references.
   */
  const deleteBoard = useCallback(async (id: string) => {
    if (!id) return;
    const record = boards.find(b => b.id === id);
    const ownerMatch = !record
      || record.createdBy === user?.id
      || (record as any).owner_id === user?.id
      || !user?.id; // guest cleanup of own local boards
    if (record && !ownerMatch) {
      console.warn('[BoardContext] Refusing to delete a board owned by another user:', id);
      return;
    }
    store.deleteBoard(id);
    store.clearDrawings(id); // purge stale drawing cache so the id can't resurrect with old strokes
    if (user?.id) {
      await historyService.deleteHistoryItem(user.id, id).catch(err => {
        console.error('Cloud board deletion failed (local copy removed):', err);
      });
    }
    setBoards(prev => prev.filter(b => b.id !== id));
    if (currentBoard?.id === id) {
      setCurrentBoard(null);
      setStrokes([]);
    }
    lastCloudSignatureRef.current = '';
    store.addActivity({ type: 'board_deleted', description: `Deleted session "${record?.title || id}"` });
  }, [boards, currentBoard?.id, user]);

  const exportBoard = useCallback((format: 'png' | 'pdf' | 'svg' | 'json') => {
    if (!currentBoard) return;
    store.addActivity({ type: 'export', description: `Exported "${currentBoard.title}" as ${format.toUpperCase()}` });
  }, [currentBoard]);

  return (
    <BoardContext.Provider value={{
      currentBoard, boards, strokes, selectedTool, selectedColor, strokeWidth, opacity,
      zoom, offset, isDrawing, collaborators,
      undoStack, redoStack, waypoints,
      setCurrentBoard, setSelectedTool, setSelectedColor, setStrokeWidth, setOpacity,
      setZoom, setOffset, setIsDrawing,
      addStroke, undo, redo, clearBoard, loadBoard, createBoard, saveBoard, duplicateBoard, deleteBoard, exportBoard,
      addWaypoint, goToWaypoint, removeWaypoint
    }}>
      {children}
    </BoardContext.Provider>
  );
}

function lastCloudSignatureKey(strokes: any[]): string {
  if (!strokes || strokes.length === 0) return 'empty';
  const last = strokes[strokes.length - 1];
  return `len=${strokes.length}:id=${last?.id || ''}:pts=${last?.points?.length || 0}:t=${last?.timestamp || last?.createdAt || ''}`;
}

export function useBoard() {
  const context = useContext(BoardContext);
  if (!context) throw new Error('useBoard must be used within BoardProvider');
  return context;
}
