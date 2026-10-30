const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/auth');
const { asyncHandler } = require('../middleware/errorHandler');
const db = require('../config/db');
const { v4: uuidv4 } = require('uuid');
const path = require('path');
const fs = require('fs');

const EXPORT_DIR = path.join(__dirname, '..', '..', 'exports');

/** HTTP-status-aware error (handled by errorHandler via err.status). */
function httpError(status, message) {
  const err = new Error(message);
  err.status = status;
  return err;
}

/** Access helpers (mirror of whiteboards.js policy). */
function isOwnerBoard(boardData, userId) {
  if (!boardData) return false;
  return boardData.owner_id === userId || boardData.createdBy === userId;
}

function isSharedWith(boardData, userId) {
  if (!boardData) return false;
  if (boardData.isShared === true) return true;
  return Array.isArray(boardData.sharedWith) && boardData.sharedWith.includes(userId);
}

/**
 * Resolves the exported file path GUARANTEED to live inside EXPORT_DIR.
 * Blocks `..` traversal, absolute paths and any name outside the directory.
 */
function resolveSafeExportPath(filename) {
  const clean = path.basename(String(filename || ''));
  if (!clean || clean.includes('..') || /[\\/:*?"<>|]/.test(clean)) {
    throw httpError(400, 'Invalid filename');
  }
  const filePath = path.join(EXPORT_DIR, clean);
  if (!filePath.startsWith(EXPORT_DIR + path.sep)) {
    throw httpError(400, 'Invalid filename');
  }
  return { clean, filePath };
}

router.get('/formats', (req, res) => {
  res.json({
    formats: [
      { id: 'pdf', name: 'PDF Document', icon: 'file-text', mime: 'application/pdf' },
      { id: 'png', name: 'PNG Image', icon: 'image', mime: 'image/png' },
      { id: 'svg', name: 'SVG Vector', icon: 'file-image', mime: 'image/svg+xml' },
      { id: 'json', name: 'JSON Data', icon: 'file-code', mime: 'application/json' }
    ]
  });
});

router.post('/', authenticate, asyncHandler(async (req, res) => {
  const { whiteboardId, format, options } = req.body;

  // Board access check: only the owner or a shared member may export it.
  if (db.db && whiteboardId) {
    const boardDoc = await db.db.collection('whiteboards').doc(String(whiteboardId)).get();
    if (!boardDoc.exists) {
      throw httpError(404, 'Whiteboard not found');
    }
    const boardData = boardDoc.data();
    if (!isOwnerBoard(boardData, req.user.id) && !isSharedWith(boardData, req.user.id)) {
      throw httpError(403, 'Access denied');
    }
  }

  if (!fs.existsSync(EXPORT_DIR)) fs.mkdirSync(EXPORT_DIR, { recursive: true });
  const id = uuidv4();

  const exportDocData = {
    id,
    whiteboard_id: whiteboardId,
    user_id: req.user.id,
    format: format || 'png',
    options: options || {},
    status: 'processing',
    created_at: new Date().toISOString()
  };

  if (db.db) {
    await db.db.collection('exports').doc(id).set(exportDocData);
  }

  // Retrieve whiteboard & shapes directly from approved collections
  let w = { title: 'Untitled Board', id: whiteboardId };
  let shapes = [];

  if (db.db && whiteboardId) {
    const boardDoc = await db.db.collection('whiteboards').doc(whiteboardId).get();
    if (boardDoc.exists) {
      w = { id: boardDoc.id, ...boardDoc.data() };
    }
    const shapesSnap = await db.db.collection('whiteboards').doc(whiteboardId).collection('shapes').limit(600).get();
    shapes = shapesSnap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
  }

  const filename = `${(w.title || 'board').replace(/[^a-zA-Z0-9]/g, '_')}_${Date.now()}.${format || 'png'}`;
  const filePath = path.join(EXPORT_DIR, filename);
  const exportService = require('../services/exportService');

  try {
    await exportService.export(w, shapes, format, options, filePath);
    const stats = fs.statSync(filePath);

    if (db.db) {
      await db.db.collection('exports').doc(id).set({
        status: 'completed',
        file_url: `/exports/${filename}`,
        file_size: stats.size,
        processing_time_ms: 0,
        updated_at: new Date().toISOString()
      }, { merge: true });
    }

    res.json({ id, filename, url: `/api/export/download/${filename}`, size: stats.size });
  } catch (err) {
    if (db.db) {
      await db.db.collection('exports').doc(id).set({
        status: 'failed',
        error_message: err.message,
        updated_at: new Date().toISOString()
      }, { merge: true });
    }
    res.status(500).json({ error: 'Export failed', details: err.message });
  }
}));

// Authenticated, traversal-proof download of a user's previous export files.
router.get('/download/:filename', authenticate, (req, res) => {
  const { filePath } = resolveSafeExportPath(req.params.filename);
  if (!fs.existsSync(filePath)) return res.status(404).json({ error: 'File not found' });
  res.download(filePath);
});

router.get('/history', authenticate, asyncHandler(async (req, res) => {
  if (!db.db) return res.json([]);
  const snapshot = await db.db.collection('exports').where('user_id', '==', req.user.id).limit(50).get();
  const list = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
  list.sort((a, b) => new Date(b.created_at || 0) - new Date(a.created_at || 0));
  res.json(list.slice(0, 50));
}));

// Delete OWN export record + best-effort removal of the generated file.
router.delete('/:id', authenticate, asyncHandler(async (req, res) => {
  if (!db.db) return res.json({ message: 'Export deleted' });

  const docSnap = await db.db.collection('exports').doc(req.params.id).get();
  if (!docSnap.exists) return res.status(404).json({ error: 'Export not found' });

  const data = docSnap.data();
  const ownedByUser = data.user_id === req.user.id
    || data.created_by === req.user.id
    || req.user.role === 'admin';
  if (!ownedByUser) return res.status(403).json({ error: 'Access denied' });

  await db.db.collection('exports').doc(req.params.id).delete();

  // Best-effort local file cleanup (path-traversal-proof).
  try {
    const fileUrl = data.file_url || '';
    const filename = path.basename(String(fileUrl));
    if (filename && filename.includes('_')) {
      const { filePath } = resolveSafeExportPath(filename);
      if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
    }
  } catch (_) {
    /* file cleanup is best-effort */
  }

  res.json({ message: 'Export deleted' });
}));

module.exports = router;
