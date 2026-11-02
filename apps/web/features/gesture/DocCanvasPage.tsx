'use client';

import React, { useState, useRef, useEffect, useCallback } from 'react';
import {
  Pen, Eraser, Type, Highlighter, Zap, ZoomIn, Upload, Undo2, Redo2,
  RotateCcw, PanelLeft, FileText, Check, Save,
  X, MousePointer2, Eye, Film
} from 'lucide-react';
import { BoardHeader, SaveStatusType } from '@/components/layout/BoardHeader';
import { TextElementOverlay, BoardTextElement } from '@/components/board/TextElementOverlay';
import { fileImportService, ImportedFileData } from '@/lib/file-import/FileImportService';
import { DocumentViewer } from '@/components/board/DocumentViewer';
import { VanishingLaserOverlay } from '@/components/board/VanishingLaserOverlay';
import { FocusMagnifierOverlay } from '@/components/board/FocusMagnifierOverlay';
import { ReferenceDrawer } from '@/components/board/ReferenceDrawer';
import VectorReplayPlayer from '@/components/board/VectorReplayPlayer';
import { ErrorBoundary } from '@/components/ui/ErrorBoundary';
import { LASER_COLOR_MAP, LaserColorMode } from '@/components/board/PresentationPointerOverlay';

import { useAuth } from '@/lib/AuthContext';
import { useBoard } from '@/lib/BoardContext';
import { historyService } from '@/lib/services/firebaseData';
import { db } from '@/lib/firebase';
import { doc as firestoreDoc, onSnapshot } from 'firebase/firestore';
import type { Board } from '@/lib/types';

type DocTool = 'pen' | 'text' | 'eraser' | 'highlight' | 'laser' | 'magnify' | 'pointer';

interface Stroke {
  id: string;
  points: { x: number; y: number }[];
  color: string;
  width: number;
  tool: 'pen' | 'eraser' | 'highlight';
}

import { useSearchParams } from 'next/navigation';
import * as store from '@/lib/store';

const PEN_COLORS = [
  { name: 'Azure', hex: '#2563eb' },
  { name: 'Ruby', hex: '#dc2626' },
  { name: 'Emerald', hex: '#059669' },
  { name: 'Amber', hex: '#d97706' },
  { name: 'Violet', hex: '#7c3aed' },
  { name: 'Ink', hex: '#0f172a' }
];

const HIGHLIGHT_COLORS = [
  { name: 'Yellow', hex: '#fef08a' },
  { name: 'Green', hex: '#bbf7d0' },
  { name: 'Cyan', hex: '#a5f3fc' },
  { name: 'Pink', hex: '#fbcfe8' }
];

export function DocCanvasPage() {
  return (
    <ErrorBoundary fallbackTitle="DocCanvas Error" fallbackMessage="Something went wrong with the document canvas. Click reload to restore.">
      <React.Suspense fallback={<div className="h-screen w-screen bg-slate-950 flex items-center justify-center text-white text-xs font-semibold">Loading DocCanvas Studio...</div>}>
        <DocCanvasContent />
      </React.Suspense>
    </ErrorBoundary>
  );
}

function DocCanvasContent() {
  const searchParams = useSearchParams();
  const queryId = searchParams?.get('id');
  const { user } = useAuth();
  const { saveBoard, boards, setCurrentBoard } = useBoard();
  const [boardId, setBoardId] = useState<string>(() => queryId || `doccanvas_${Date.now()}`);
  const [boardTitle, setBoardTitle] = useState<string>('DocCanvas Annotator');
  const [statusMessage, setStatusMessage] = useState<string | null>(null);

  // Document & View State
  const [doc, setDoc] = useState<ImportedFileData | null>(null);
  const [docMode, setDocMode] = useState<'write' | 'scroll'>('write');

  // Tool & Canvas State
  const [tool, setTool] = useState<DocTool>('pen');
  const [color, setColor] = useState('#2563eb');
  const [highlightColor, setHighlightColor] = useState('#fef08a');
  const [strokeWidth, setStrokeWidth] = useState(4);
  const [strokes, setStrokes] = useState<Stroke[]>([]);
  const [textElements, setTextElements] = useState<BoardTextElement[]>([]);
  const [selectedTextId, setSelectedTextId] = useState<string | null>(null);

  // Core Features State
  const [isReferenceDrawerOpen, setIsReferenceDrawerOpen] = useState(false);
  const [referenceDocument, setReferenceDocument] = useState<ImportedFileData | null>(null);
  const [isReplayPlayerOpen, setIsReplayPlayerOpen] = useState(false);

  // Overlays State
  const [laserColorMode, setLaserColorMode] = useState<LaserColorMode>('red');
  const [zoomScale, setZoomScale] = useState(1);
  const [panOffset, setPanOffset] = useState({ x: 0, y: 0 });

  // History & Save State
  const [undoStack, setUndoStack] = useState<{ strokes: Stroke[]; textElements: BoardTextElement[] }[]>([]);
  const [redoStack, setRedoStack] = useState<{ strokes: Stroke[]; textElements: BoardTextElement[] }[]>([]);
  const [saveStatus, setSaveStatus] = useState<SaveStatusType>('idle');
  const [lastSavedTime, setLastSavedTime] = useState<string>('');

  const canvasRef = useRef<HTMLCanvasElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const isDrawingRef = useRef(false);
  const currentStrokeRef = useRef<{ x: number; y: number }[]>([]);
  const isMountedRef = useRef(true);
  const statusTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const logicalSizeRef = useRef({ w: 0, h: 0 });
  // Identity of the originally loaded board — preserves createdBy/createdAt on every save.
  const originalBoardRef = useRef<Board | null>(null);
  const boardIdRef = useRef<string>(boardId);
  useEffect(() => { boardIdRef.current = boardId; }, [boardId]);

  useEffect(() => {
    isMountedRef.current = true;
    return () => {
      isMountedRef.current = false;
    };
  }, []);

  // Load saved board if opening from history
  useEffect(() => {
    if (!queryId) return;
    const targetId = queryId;
    let isMounted = true;
    async function loadSavedDocCanvasBoard() {
      console.log('[History Resume: DocCanvas] Loading saved session:', targetId);
      let b = boards.find(item => item.id === targetId) || store.getBoard(targetId);
      if (!b && user?.id) {
        b = (await historyService.getHistoryItem(user.id, targetId)) || undefined;
      }
      if (b && isMounted) {
        setBoardId(b.id);
        if (b.title) setBoardTitle(b.title);
        setCurrentBoard(b);
        originalBoardRef.current = b;

        let loadedStrokes: Stroke[] = [];
        const rawStrokes = b.strokes && Array.isArray(b.strokes) ? b.strokes : null;
        if (rawStrokes && rawStrokes.length > 0) {
          loadedStrokes = rawStrokes.map((s: any) => ({
            ...s,
            width: s.width || s.strokeWidth || 3,
            color: s.color || s.colorHex || '#ffffff',
            tool: s.tool || s.type || 'pen',
          })) as any;
        } else if ((b as any).annotations && Array.isArray((b as any).annotations)) {
          loadedStrokes = (b as any).annotations.map((a: any) => ({
            id: a.id || `ann_${Date.now()}`,
            tool: a.type === 'highlight' ? 'highlight' : 'pen',
            width: a.strokeWidth || 3,
            color: a.color ? (typeof a.color === 'string' ? a.color : `#${(a.color & 0xFFFFFF).toString(16)}`) : '#ffd54f',
            points: (a.points || []).map((p: any) => ({ x: p.x || p.dx || 0, y: p.y || p.dy || 0 })),
          }));
        } else if (b.content && typeof b.content === 'string' && b.content.trim().length > 0) {
          try {
            const parsed = JSON.parse(b.content);
            const contentStrokes = Array.isArray(parsed) ? parsed : (parsed?.strokes || parsed?.annotations || []);
            loadedStrokes = contentStrokes.map((s: any) => ({
              ...s,
              width: s.width || s.strokeWidth || 3,
              color: s.color || s.colorHex || '#ffffff',
              tool: s.tool || s.type || 'pen',
            }));
          } catch {}
        }
        if (loadedStrokes.length === 0) {
          const local = store.getDrawings(targetId);
          if (local && local.length > 0) loadedStrokes = local as any;
        }

        let loadedElements: BoardTextElement[] = [];
        if (b.elements && Array.isArray(b.elements) && b.elements.length > 0) {
          loadedElements = b.elements as any;
        } else if (b.content && typeof b.content === 'string') {
          try {
            const parsed = JSON.parse(b.content);
            if (parsed && Array.isArray(parsed.elements)) loadedElements = parsed.elements;
          } catch {}
        }

        setStrokes(loadedStrokes);
        setTextElements(loadedElements);
        const docObj = (b as any).activeDocument || ((b as any).bgFile ? { name: b.title, url: (b as any).bgFile.url, type: (b as any).bgFile.type } : null);
        if (docObj) setDoc(docObj);
        console.log(`[History Resume: DocCanvas] Loaded "${b.title}" with ${loadedStrokes.length} strokes.`);
        if (isMounted) {
          showStatus(`Board restored — continuing "${b.title}" with ${loadedStrokes.length} strokes & ${loadedElements.length} annotations`, 4000);
        }
      }
    }
    loadSavedDocCanvasBoard();
    return () => { isMounted = false; };
  }, [queryId, user?.id]);

  const lastSyncSigRef = useRef<string>('');

  // Real-time Firestore sync for the active DocCanvas across Web and Mobile
  useEffect(() => {
    if (!boardId) return;
    const boardDocRef = firestoreDoc(db, 'whiteboards', boardId);
    const unsub = onSnapshot(boardDocRef, (snapshot) => {
      if (!snapshot.exists() || snapshot.metadata.hasPendingWrites) return;
      const b = snapshot.data();
      if (!b) return;

      const rawStrokes = b.strokes && Array.isArray(b.strokes) ? b.strokes : null;
      let loadedStrokes: Stroke[] = [];
      if (rawStrokes && rawStrokes.length > 0) {
        loadedStrokes = rawStrokes.map((s: any) => ({
          ...s,
          width: s.width || s.strokeWidth || 3,
          color: s.color || s.colorHex || '#ffffff',
          tool: s.tool || s.type || 'pen',
        })) as any;
      } else if (b.annotations && Array.isArray(b.annotations)) {
        loadedStrokes = b.annotations.map((a: any) => ({
          id: a.id || `ann_${Date.now()}`,
          tool: a.type === 'highlight' ? 'highlight' : 'pen',
          width: a.strokeWidth || 3,
          color: a.color ? (typeof a.color === 'string' ? a.color : `#${(a.color & 0xFFFFFF).toString(16)}`) : '#ffd54f',
          points: (a.points || []).map((p: any) => ({ x: p.x || p.dx || 0, y: p.y || p.dy || 0 })),
        }));
      }

      let loadedElements: BoardTextElement[] = [];
      if (b.elements && Array.isArray(b.elements)) {
        loadedElements = b.elements as any;
      }

      const sig = `${loadedStrokes.length}_${loadedElements.length}_${b.updatedAt || b.updated_at || ''}_${b.activeDocument?.name || b.title || ''}`;
      if (sig === lastSyncSigRef.current) return;
      lastSyncSigRef.current = sig;

      if (loadedStrokes.length > 0 || (rawStrokes && rawStrokes.length === 0 && strokes.length > 0)) {
        setStrokes(loadedStrokes);
      }
      if (loadedElements.length > 0) {
        setTextElements(loadedElements);
      }
      if (b.title && b.title !== 'DocCanvas Annotator') {
        setBoardTitle(b.title);
      }
      const docObj = b.activeDocument || (b.bgFile ? { id: `doc_${Date.now()}`, name: b.title || 'Document', url: b.bgFile.url, dataUrl: b.bgFile.url, type: b.bgFile.type, mimeType: b.bgFile.type === 'pdf' ? 'application/pdf' : 'image/png', size: 0 } : null);
      if (docObj) {
        setDoc((prev) => {
          if (!prev || (prev as any).url !== (docObj as any).url || prev.name !== docObj.name) {
            return docObj as ImportedFileData;
          }
          return prev;
        });
      }
    }, (err) => {
      console.warn('[DocCanvas] Real-time snapshot listener notice:', err);
    });

    return () => unsub();
  }, [boardId]);

  const showStatus = useCallback((message: string, duration = 2500) => {
    if (!isMountedRef.current) return;
    setStatusMessage(message);
    if (statusTimerRef.current) clearTimeout(statusTimerRef.current);
    statusTimerRef.current = setTimeout(() => {
      if (isMountedRef.current) setStatusMessage(null);
    }, duration);
  }, []);

  const saveSnapshot = useCallback(() => {
    setUndoStack((prev) => [...prev, { strokes, textElements }]);
    setRedoStack([]);
  }, [strokes, textElements]);

  const handleUndo = useCallback(() => {
    if (undoStack.length === 0) return;
    const previous = undoStack[undoStack.length - 1];
    setRedoStack((prev) => [...prev, { strokes, textElements }]);
    setStrokes(previous.strokes);
    setTextElements(previous.textElements);
    setUndoStack((prev) => prev.slice(0, -1));
  }, [undoStack, strokes, textElements]);

  const handleRedo = useCallback(() => {
    if (redoStack.length === 0) return;
    const next = redoStack[redoStack.length - 1];
    setUndoStack((prev) => [...prev, { strokes, textElements }]);
    setStrokes(next.strokes);
    setTextElements(next.textElements);
    setRedoStack((prev) => prev.slice(0, -1));
  }, [redoStack, strokes, textElements]);

  const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    try {
      const imported = await fileImportService.importFile(file);
      setDoc(imported);
      setDocMode('write');
      showStatus(`Opened document: ${imported.name}`);
    } catch (err) {
      console.error('File import failed:', err);
      showStatus('Failed to import file. Please try another format.');
    }
  };

  /** Unified payload builder for manual + auto saves (identity preserved). */
  const buildBoardPayload = useCallback((): Board => {
    const loaded = originalBoardRef.current;
    const now = new Date();
    const annotationsList = strokes.map((s) => ({
      id: s.id,
      pageIndex: 1,
      type: s.tool === 'highlight' ? 'highlight' : 'pen',
      strokeWidth: s.width,
      color: s.color,
      createdAt: now.toISOString(),
      points: s.points.map((p) => ({ x: p.x, y: p.y })),
    }));

    return {
      id: boardIdRef.current,
      title: doc ? `DocCanvas: ${doc.name}` : (loaded?.title && boardTitle === 'DocCanvas Annotator' ? loaded.title : (boardTitle || 'DocCanvas Annotator')),
      description: `Document annotation session with ${strokes.length} strokes and ${textElements.length} text annotations.`,
      createdBy: loaded?.createdBy && !(loaded.createdBy === 'guest' || loaded.createdBy === 'u1') ? loaded.createdBy : (user?.id || loaded?.createdBy || 'guest'),
      createdAt: loaded?.createdAt || now.toISOString(),
      updatedAt: now.toISOString(),
      isShared: loaded?.isShared || false,
      sharedWith: loaded?.sharedWith,
      width: 1920,
      height: 1080,
      zoom: 100,
      isInfiniteCanvas: true,
      studio: 'doccanvas',
      category: 'docAnnotation',
      strokes: strokes as any,
      elements: textElements as any,
      annotations: annotationsList as any,
      total_shapes: strokes.length + textElements.length,
      ...(doc ? {
        bgFile: { url: doc.dataUrl || (doc as any).url, type: doc.type },
        activeDocument: doc as any,
      } : {}),
    } as Board;
  }, [strokes, textElements, doc, boardTitle, user?.id]);

  const handleSave = async () => {
    setSaveStatus('saving');
    try {
      const now = new Date();
      const timeStr = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
      const boardPayload = buildBoardPayload();

      lastSyncSigRef.current = `${strokes.length}_${textElements.length}_${boardPayload.updatedAt}_${doc?.name || boardTitle}`;

      await saveBoard(boardPayload);
      if (user?.id) {
        await historyService.saveBoardVersion(user.id, boardIdRef.current, boardPayload);
      }

      setSaveStatus('saved');
      setLastSavedTime(timeStr);
      showStatus('Document annotations saved successfully!');
      setTimeout(() => setSaveStatus('idle'), 4000);
    } catch (err) {
      console.error('Failed to save DocCanvas:', err);
      setSaveStatus('error');
      setTimeout(() => setSaveStatus('idle'), 4000);
    }
  };

  // Track unsaved changes for manual save (AutoSave removed — user presses Save button)
  useEffect(() => {
    if (strokes.length === 0 && textElements.length === 0 && !doc) return;
    setSaveStatus('unsaved');
  }, [strokes, textElements, doc]);

  // Redraw Canvas
  const redrawCanvas = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const dpr = window.devicePixelRatio || 1;
    ctx.setTransform(dpr * zoomScale, 0, 0, dpr * zoomScale, panOffset.x * dpr, panOffset.y * dpr);
    const { w, h } = logicalSizeRef.current;
    ctx.clearRect(0, 0, w, h);
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';

    for (const stroke of strokes) {
      if (stroke.points.length < 2) continue;
      ctx.beginPath();

      if (stroke.tool === 'eraser') {
        ctx.strokeStyle = '#ffffff';
        ctx.lineWidth = stroke.width * 4;
        ctx.globalCompositeOperation = 'destination-out';
      } else if (stroke.tool === 'highlight') {
        ctx.strokeStyle = stroke.color;
        ctx.lineWidth = stroke.width * 5;
        ctx.globalAlpha = 0.4;
        ctx.globalCompositeOperation = 'source-over';
      } else {
        ctx.strokeStyle = stroke.color;
        ctx.lineWidth = stroke.width;
        ctx.globalAlpha = 1.0;
        ctx.globalCompositeOperation = 'source-over';
      }

      ctx.moveTo(stroke.points[0].x, stroke.points[0].y);
      for (let i = 1; i < stroke.points.length; i++) {
        ctx.lineTo(stroke.points[i].x, stroke.points[i].y);
      }
      ctx.stroke();
      ctx.globalAlpha = 1.0;
    }
    ctx.globalCompositeOperation = 'source-over';
  }, [strokes, zoomScale, panOffset]);

  useEffect(() => {
    redrawCanvas();
  }, [redrawCanvas]);

  useEffect(() => {
    const handleResize = () => {
      const canvas = canvasRef.current;
      if (!canvas) return;
      const target = canvas.parentElement || containerRef.current;
      if (!target) return;
      const rect = target.getBoundingClientRect();
      if (rect.width === 0 || rect.height === 0) return;
      const dpr = window.devicePixelRatio || 1;
      logicalSizeRef.current = { w: rect.width, h: rect.height };
      canvas.width = rect.width * dpr;
      canvas.height = rect.height * dpr;
      canvas.style.width = `${rect.width}px`;
      canvas.style.height = `${rect.height}px`;
      redrawCanvas();
    };

    handleResize();
    window.addEventListener('resize', handleResize);
    const parentEl = canvasRef.current?.parentElement;
    const observer = parentEl ? new ResizeObserver(() => handleResize()) : null;
    if (parentEl && observer) {
      observer.observe(parentEl);
    }
    return () => {
      window.removeEventListener('resize', handleResize);
      if (observer) observer.disconnect();
    };
  }, [redrawCanvas, doc]);

  const getCanvasCoords = (e: React.PointerEvent<HTMLCanvasElement>) => {
    const canvas = canvasRef.current;
    if (!canvas) return { x: 0, y: 0 };
    const rect = canvas.getBoundingClientRect();
    return {
      x: (e.clientX - rect.left - panOffset.x) / zoomScale,
      y: (e.clientY - rect.top - panOffset.y) / zoomScale,
    };
  };

  const handlePointerDown = (e: React.PointerEvent<HTMLCanvasElement>) => {
    if (docMode === 'scroll' || tool === 'pointer' || tool === 'laser' || tool === 'magnify') return;

    const pt = getCanvasCoords(e);

    if (tool === 'text') {
      saveSnapshot();
      const newText: BoardTextElement = {
        id: `text_${Date.now()}`,
        x: pt.x,
        y: pt.y,
        text: 'Click to type annotation...',
        fontSize: 18,
        color: color,
      };
      setTextElements(prev => [...prev, newText]);
      setSelectedTextId(newText.id);
      return;
    }

    isDrawingRef.current = true;
    currentStrokeRef.current = [pt];
  };

  const handlePointerMove = (e: React.PointerEvent<HTMLCanvasElement>) => {
    if (!isDrawingRef.current || docMode === 'scroll' || tool === 'laser' || tool === 'magnify' || tool === 'text') return;
    const pt = getCanvasCoords(e);
    const points = currentStrokeRef.current;
    points.push(pt);

    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx || points.length < 2) return;
    const dpr = window.devicePixelRatio || 1;
    ctx.setTransform(dpr * zoomScale, 0, 0, dpr * zoomScale, panOffset.x * dpr, panOffset.y * dpr);
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    ctx.beginPath();

    if (tool === 'eraser') {
      ctx.strokeStyle = '#ffffff';
      ctx.lineWidth = strokeWidth * 4;
      ctx.globalCompositeOperation = 'destination-out';
    } else if (tool === 'highlight') {
      ctx.strokeStyle = highlightColor;
      ctx.lineWidth = strokeWidth * 5;
      ctx.globalAlpha = 0.4;
      ctx.globalCompositeOperation = 'source-over';
    } else {
      ctx.strokeStyle = color;
      ctx.lineWidth = strokeWidth;
      ctx.globalAlpha = 1.0;
      ctx.globalCompositeOperation = 'source-over';
    }

    const p1 = points[points.length - 2];
    const p2 = points[points.length - 1];
    ctx.moveTo(p1.x, p1.y);
    ctx.lineTo(p2.x, p2.y);
    ctx.stroke();
    ctx.globalAlpha = 1.0;
    ctx.globalCompositeOperation = 'source-over';
  };

  const handlePointerUp = () => {
    if (!isDrawingRef.current) return;
    isDrawingRef.current = false;
    const points = [...currentStrokeRef.current];
    currentStrokeRef.current = [];
    if (points.length < 2 || tool === 'laser' || tool === 'magnify' || tool === 'text') return;

    saveSnapshot();

    const newStroke: Stroke = {
      id: `stroke_${Date.now()}_${Math.random().toString(36).substr(2, 4)}`,
      points,
      color: tool === 'highlight' ? highlightColor : color,
      width: strokeWidth,
      tool: tool === 'eraser' ? 'eraser' : tool === 'highlight' ? 'highlight' : 'pen',
    };

    setStrokes(prev => [...prev, newStroke]);
  };

  const handleFitBoard = () => {
    setZoomScale(1);
    setPanOffset({ x: 0, y: 0 });
    showStatus('Reset document view');
  };

  return (
    <div className="flex flex-col h-screen w-screen overflow-hidden bg-slate-950 text-slate-100">
      {/* Header Bar */}
      <BoardHeader
        title={doc ? `DocCanvas: ${doc.name}` : 'DocCanvas Studio'}
        onSave={handleSave}
        saveStatus={saveStatus}
        lastSavedTime={lastSavedTime}
      >
        {/* Reference Drawer Toggle */}
        <button
          onClick={() => setIsReferenceDrawerOpen(!isReferenceDrawerOpen)}
          className={`flex items-center gap-1 px-2.5 py-1 rounded-lg text-[11px] font-medium border transition-all cursor-pointer ${
            isReferenceDrawerOpen
              ? 'bg-indigo-500/20 text-indigo-300 border-indigo-500/30'
              : 'bg-slate-800 text-slate-300 border-slate-700 hover:bg-slate-700'
          }`}
          title="Toggle Reference Drawer"
        >
          <PanelLeft className="w-3 h-3" />
          <span>Reference</span>
        </button>

        {/* Session Replay Button */}
        <button
          onClick={() => setIsReplayPlayerOpen(true)}
          className="flex items-center gap-1 px-2.5 py-1 bg-slate-800 text-slate-300 border border-slate-700 hover:bg-slate-700 hover:text-white text-[11px] font-bold rounded-lg cursor-pointer transition-all shadow-xs"
          title="Vector Session Replay"
        >
          <Film className="w-3 h-3 text-indigo-400" />
          <span>Replay</span>
        </button>

        {/* Open Document File Action */}
        <label className="flex items-center gap-1 px-2.5 py-1 bg-indigo-600 hover:bg-indigo-500 text-white text-[11px] font-medium rounded-lg cursor-pointer transition-all shadow-xs">
          <Upload className="w-3 h-3" />
          <span>Open Document</span>
          <input
            type="file"
            onChange={handleFileUpload}
            accept=".pdf,.ppt,.pptx,.txt,.doc,.docx,.png,.jpg,.jpeg"
            className="hidden"
          />
        </label>
      </BoardHeader>

      {/* Main Studio Viewport */}
      <div className="flex flex-1 w-full h-full overflow-hidden relative bg-slate-900">
        {/* Left Side-by-Side Reference Drawer */}
        <ReferenceDrawer
          isOpen={isReferenceDrawerOpen}
          onClose={() => setIsReferenceDrawerOpen(false)}
          document={referenceDocument}
          onDocumentChange={setReferenceDocument}
        />

        {/* Right Studio Workspace */}
        <div ref={containerRef} className="relative flex-1 h-full overflow-hidden select-none flex items-center justify-center p-4">
          {doc ? (
            <DocumentViewer
              document={doc}
              docMode={docMode}
              onDocModeChange={setDocMode}
              onClose={() => setDoc(null)}
              className="w-full h-full"
            >
              {/* Overlay Canvas */}
              <canvas
                ref={canvasRef}
                onPointerDown={handlePointerDown}
                onPointerMove={handlePointerMove}
                onPointerUp={handlePointerUp}
                onPointerLeave={handlePointerUp}
                className={`absolute inset-0 z-10 touch-none ${docMode === 'scroll' ? 'pointer-events-none' : 'cursor-crosshair pointer-events-auto'}`}
              />

              {/* Text Elements Overlay */}
              {textElements.map(el => (
                <TextElementOverlay
                  key={el.id}
                  element={el}
                  isSelected={selectedTextId === el.id}
                  onSelect={setSelectedTextId}
                  onUpdate={(updated) => setTextElements(prev => prev.map(t => t.id === updated.id ? updated : t))}
                  onDelete={(id) => setTextElements(prev => prev.filter(t => t.id !== id))}
                />
              ))}
            </DocumentViewer>
          ) : (
            <div className="w-full h-full relative rounded-3xl bg-slate-950/80 border border-slate-800 shadow-2xl overflow-hidden">
              {/* Floating Non-Blocking Blank Canvas Helper Banner */}
              <div className="absolute top-4 left-1/2 -translate-x-1/2 z-20 pointer-events-none flex items-center gap-3 px-4 py-2 rounded-2xl bg-slate-900/90 border border-slate-800 backdrop-blur-md shadow-lg text-slate-300 text-xs font-semibold">
                <FileText className="w-4 h-4 text-indigo-400 shrink-0" />
                <span>Blank Canvas — Draw directly or import a document</span>
                <label className="pointer-events-auto px-3 py-1 bg-indigo-600 hover:bg-indigo-500 text-white font-bold text-[11px] rounded-xl cursor-pointer transition-all flex items-center gap-1.5 shadow-sm">
                  <Upload className="w-3 h-3" />
                  <span>Open File</span>
                  <input
                    type="file"
                    onChange={handleFileUpload}
                    accept=".pdf,.ppt,.pptx,.txt,.doc,.docx,.png,.jpg,.jpeg"
                    className="hidden"
                  />
                </label>
              </div>

              {/* Blank Interactive Canvas Overlay */}
              <canvas
                ref={canvasRef}
                onPointerDown={handlePointerDown}
                onPointerMove={handlePointerMove}
                onPointerUp={handlePointerUp}
                onPointerLeave={handlePointerUp}
                className="absolute inset-0 z-10 touch-none cursor-crosshair pointer-events-auto"
              />

              {textElements.map(el => (
                <TextElementOverlay
                  key={el.id}
                  element={el}
                  isSelected={selectedTextId === el.id}
                  onSelect={setSelectedTextId}
                  onUpdate={(updated) => setTextElements(prev => prev.map(t => t.id === updated.id ? updated : t))}
                  onDelete={(id) => setTextElements(prev => prev.filter(t => t.id !== id))}
                />
              ))}
            </div>
          )}

          {/* Interactive Overlays */}
          <VanishingLaserOverlay isActive={tool === 'laser'} color={LASER_COLOR_MAP[laserColorMode]} />
          <FocusMagnifierOverlay isActive={tool === 'magnify'} containerRef={containerRef} sourceCanvasRef={canvasRef} />
          


          {/* Toast Notification */}
          {statusMessage && (
            <div className="absolute top-6 left-1/2 -translate-x-1/2 z-50 bg-slate-900 text-white px-4 py-2 rounded-xl text-xs font-semibold shadow-xl border border-slate-700 animate-fade-in">
              {statusMessage}
            </div>
          )}

          {/* Studio HUD Toolbar */}
          <div className="absolute bottom-6 left-1/2 -translate-x-1/2 z-40 flex items-center gap-2 p-2 rounded-2xl bg-slate-900/90 border border-slate-800 backdrop-blur-md shadow-2xl transition-all">
            
            {/* Main Annotation Tools */}
            {[
              { id: 'pen', icon: Pen, label: 'Pen Mode' },
              { id: 'text', icon: Type, label: 'Text Typing' },
              { id: 'eraser', icon: Eraser, label: 'Eraser' },
              { id: 'highlight', icon: Highlighter, label: 'Highlight' },
              { id: 'laser', icon: Zap, label: 'Laser Pointer' },
              { id: 'magnify', icon: ZoomIn, label: 'Magnify Lens' },
              { id: 'pointer', icon: MousePointer2, label: 'Select Mode' },
            ].map(t => (
              <button
                key={t.id}
                onClick={() => setTool(t.id as DocTool)}
                className={`p-2.5 rounded-xl transition-all cursor-pointer ${
                  tool === t.id
                    ? 'bg-indigo-600 text-white shadow-lg shadow-indigo-600/30'
                    : 'text-slate-400 hover:text-slate-100 hover:bg-slate-800'
                }`}
                title={t.label}
              >
                <t.icon className="w-4 h-4" />
              </button>
            ))}

            <div className="w-px h-6 bg-slate-800" />

            {/* Pen Color Swatches */}
            {tool === 'pen' && (
              <div className="flex items-center gap-1.5 px-1">
                {PEN_COLORS.map(c => (
                  <button
                    key={c.hex}
                    onClick={() => setColor(c.hex)}
                    className={`w-5 h-5 rounded-full border-2 transition-transform cursor-pointer ${
                      color === c.hex ? 'scale-125 border-white shadow-md' : 'border-transparent hover:scale-110'
                    }`}
                    style={{ backgroundColor: c.hex }}
                    title={c.name}
                  />
                ))}
              </div>
            )}

            {/* Highlight Color Swatches */}
            {tool === 'highlight' && (
              <div className="flex items-center gap-1.5 px-1">
                {HIGHLIGHT_COLORS.map(c => (
                  <button
                    key={c.hex}
                    onClick={() => setHighlightColor(c.hex)}
                    className={`w-5 h-5 rounded-full border-2 transition-transform cursor-pointer ${
                      highlightColor === c.hex ? 'scale-125 border-white shadow-md' : 'border-transparent hover:scale-110'
                    }`}
                    style={{ backgroundColor: c.hex }}
                    title={`Highlighter ${c.name}`}
                  />
                ))}
              </div>
            )}

            {/* Laser Color Selection */}
            {tool === 'laser' && (
              <div className="flex items-center gap-1.5 px-1">
                {(['red', 'green', 'blue', 'yellow'] as LaserColorMode[]).map(m => (
                  <button
                    key={m}
                    onClick={() => setLaserColorMode(m)}
                    className={`w-5 h-5 rounded-full border-2 transition-transform cursor-pointer ${
                      laserColorMode === m ? 'scale-125 border-white shadow-md' : 'border-transparent'
                    }`}
                    style={{ backgroundColor: LASER_COLOR_MAP[m] }}
                    title={`Laser ${m}`}
                  />
                ))}
              </div>
            )}

            <div className="w-px h-6 bg-slate-800" />

            {/* Undo / Redo */}
            <button
              onClick={handleUndo}
              disabled={undoStack.length === 0}
              className="p-2.5 rounded-xl text-slate-400 disabled:opacity-30 hover:bg-slate-800 hover:text-white cursor-pointer transition-colors"
              title="Undo"
            >
              <Undo2 className="w-4 h-4" />
            </button>
            <button
              onClick={handleRedo}
              disabled={redoStack.length === 0}
              className="p-2.5 rounded-xl text-slate-400 disabled:opacity-30 hover:bg-slate-800 hover:text-white cursor-pointer transition-colors"
              title="Redo"
            >
              <Redo2 className="w-4 h-4" />
            </button>

            {/* Fit Viewport */}
            <button
              onClick={handleFitBoard}
              className="p-2.5 rounded-xl text-slate-400 hover:text-white hover:bg-slate-800 cursor-pointer transition-colors"
              title="Reset View"
            >
              <RotateCcw className="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>

      {/* Phase 2: Vector Session Replay Scrubber */}
      <VectorReplayPlayer
        isOpen={isReplayPlayerOpen}
        onClose={() => setIsReplayPlayerOpen(false)}
        shapes={strokes}
        onApplyShapeSnapshot={(snap) => setStrokes(snap)}
      />
    </div>
  );
}

export default DocCanvasPage;
