const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/auth');
const { asyncHandler } = require('../middleware/errorHandler');
const db = require('../config/db');
const { v4: uuidv4 } = require('uuid');

// Firestore single-batch limit — deleting in 450-doc chunks keeps every
// mutation safely under the 500-operation atomic batch cap.
const BATCH_CHUNK = 450;

/** HTTP-status-aware error (handled by errorHandler via err.status). */
function httpError(status, message) {
  const err = new Error(message);
  err.status = status;
  return err;
}

/**
 * Access-control helpers (defense in depth: these routes are also covered by
 * the hardened firestore.rules for direct client access; the backend keeps its
 * own checks so no authenticated user can read or mutate someone else's data
 * through the REST API).
 */
function isOwnerBoard(boardData, userId) {
  if (!boardData) return false;
  return boardData.owner_id === userId || boardData.createdBy === userId;
}

function isSharedWith(boardData, userId) {
  if (!boardData) return false;
  if (boardData.isShared === true) return true;
  return Array.isArray(boardData.sharedWith) && boardData.sharedWith.includes(userId);
}

async function getBoardOr404(id) {
  const snap = await db.db.collection('whiteboards').doc(String(id)).get();
  if (!snap.exists) {
    throw httpError(404, 'Whiteboard not found');
  }
  const data = snap.data();
  return { id: snap.id, data };
}

/**
 * Deletes documents from a Firestore query in 450-doc chunked batches.
 * Used for board teardown (shapes, collaborators) and for purging the
 * dependent whiteboard_versions snapshots — no orphan data can outlive a board.
 */
async function deleteQueryInChunks(q, contextLabel) {
  let deleted = 0;
  // Loop until the query stops returning documents (batches resend afterwards).
  for (let round = 0; round < 10; round += 1) {
    const snap = await q.limit(BATCH_CHUNK).get();
    if (snap.empty) break;
    const batch = db.db.batch();
    snap.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    deleted += snap.size;
  }
  if (deleted > 0) {
    console.log(`[Whiteboards] Purged ${deleted} documents (${contextLabel})`);
  }
  return deleted;
}

// GET / - List user's whiteboards (owner-only — never falls back to other
// users' boards; a query failure returns 500, not the whole collection).
router.get('/', authenticate, asyncHandler(async (req, res) => {
  if (!db.db) return res.json([]);
  try {
    // Owner + legacy createdBy projections run concurrently (matches the
    // mobile/web read paths) and are de-duplicated by id.
    const [ownerSnap, legacySnap] = await Promise.all([
      db.db.collection('whiteboards').where('owner_id', '==', req.user.id).limit(200).get(),
      db.db.collection('whiteboards').where('createdBy', '==', req.user.id).limit(200).get(),
    ]).catch(() => [null, null]);

    const byId = new Map();
    if (ownerSnap) ownerSnap.docs.forEach(doc => byId.set(doc.id, { id: doc.id, ...doc.data() }));
    if (legacySnap) legacySnap.docs.forEach(doc => { if (!byId.has(doc.id)) byId.set(doc.id, { id: doc.id, ...doc.data() }); });

    res.json(Array.from(byId.values()));
  } catch (err) {
    console.error('[Whiteboards] List failed:', err.message);
    res.status(500).json({ error: 'Failed to load whiteboards' });
  }
}));

// GET /shared - List whiteboards shared with user (indexed single query —
// no scanning of the whole whiteboards collection, no N+1 collaborator reads).
router.get('/shared', authenticate, asyncHandler(async (req, res) => {
  if (!db.db) return res.json([]);
  try {
    const snapshot = await db.db.collection('whiteboards')
      .where('sharedWith', 'array-contains', req.user.id)
      .limit(100)
      .get();
    const sharedBoards = snapshot.docs
      .filter(doc => doc.data().owner_id !== req.user.id)
      .map(doc => ({ id: doc.id, ...doc.data() }));
    res.json(sharedBoards);
  } catch (err) {
    console.error('[Whiteboards] Shared list failed:', err.message);
    res.json([]);
  }
}));

// GET /public - List public whiteboards
router.get('/public', asyncHandler(async (req, res) => {
  if (!db.db) return res.json([]);
  try {
    const snapshot = await db.db.collection('whiteboards').where('is_public', '==', true).limit(50).get();
    const whiteboards = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    res.json(whiteboards);
  } catch (err) {
    res.json([]);
  }
}));

// GET /:id - Retrieve whiteboard details with shapes and collaborators
// (owner or a shared member only).
router.get('/:id', authenticate, asyncHandler(async (req, res) => {
  if (!db.db) return res.status(404).json({ error: 'Database unavailable' });
  const { id, data } = await getBoardOr404(req.params.id);
  if (!isOwnerBoard(data, req.user.id) && !isSharedWith(data, req.user.id)) {
    return res.status(403).json({ error: 'Access denied' });
  }

  // Retrieve shapes from sub-collection: whiteboards/{id}/shapes
  const shapesSnap = await db.db.collection('whiteboards').doc(id).collection('shapes').limit(600).get();
  const shapes = shapesSnap.docs.map(doc => ({ id: doc.id, ...doc.data() }));

  // Retrieve collaborators from sub-collection: whiteboards/{id}/collaborators
  const collabSnap = await db.db.collection('whiteboards').doc(id).collection('collaborators').limit(100).get();
  const collaborators = collabSnap.docs.map(doc => ({ id: doc.id, ...doc.data() }));

  res.json({ id, ...data, shapes, collaborators });
}));

// POST / - Create a new whiteboard
router.post('/', authenticate, asyncHandler(async (req, res) => {
  if (!db.db) return res.status(503).json({ error: 'Database unavailable' });
  const { title, description, background_color, width, height } = req.body;
  const id = uuidv4();
  const payload = {
    id,
    title: title || 'Untitled Board',
    description: description || '',
    owner_id: req.user.id,
    createdBy: req.user.id,
    background_color: background_color || '#ffffff',
    width: width || 1920,
    height: height || 1080,
    total_shapes: 0,
    total_versions: 0,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString()
  };

  await db.db.collection('whiteboards').doc(id).set(payload);
  res.status(201).json({ id, message: 'Whiteboard created' });
}));

// PUT /:id - Update whiteboard metadata (owner or collaborator only)
router.put('/:id', authenticate, asyncHandler(async (req, res) => {
  if (!db.db) return res.status(503).json({ error: 'Database unavailable' });
  const { data } = await getBoardOr404(req.params.id);
  const isCollaborator = Array.isArray(data.sharedWith) && data.sharedWith.includes(req.user.id);
  if (!isOwnerBoard(data, req.user.id) && !isCollaborator) {
    return res.status(403).json({ error: 'Access denied' });
  }

  const { title, description, background_color, background_image, is_public, allow_comments, allow_export } = req.body;
  const updates = {
    last_edited_by: req.user.id,
    updated_at: new Date().toISOString()
  };

  if (title !== undefined) updates.title = title;
  if (description !== undefined) updates.description = description;
  if (background_color !== undefined) updates.background_color = background_color;
  if (background_image !== undefined) updates.background_image = background_image;
  if (is_public !== undefined) updates.is_public = is_public;
  if (allow_comments !== undefined) updates.allow_comments = allow_comments;
  if (allow_export !== undefined) updates.allow_export = allow_export;

  // Merge preserves createdAt/owner_id — only whitelisted metadata fields move.
  await db.db.collection('whiteboards').doc(req.params.id).set(updates, { merge: true });
  res.json({ message: 'Whiteboard updated' });
}));

// DELETE /:id - Delete whiteboard and ALL dependent records (owner only).
// Shapes + collaborators sub-collections + whiteboard_versions snapshots are
// purged in chunked batches so no orphan cloud data outlives the board.
router.delete('/:id', authenticate, asyncHandler(async (req, res) => {
  if (!db.db) return res.status(503).json({ error: 'Database unavailable' });
  const { id, data } = await getBoardOr404(req.params.id);
  if (!isOwnerBoard(data, req.user.id)) {
    return res.status(403).json({ error: 'Only the board owner can delete it' });
  }

  const boardRef = db.db.collection('whiteboards').doc(id);

  // 1. Version snapshots (whiteboard_versions.whiteboard_id == board id)
  await deleteQueryInChunks(
    db.db.collection('whiteboard_versions').where('whiteboard_id', '==', id),
    `versions of board ${id}`
  );

  // 2. Shapes sub-collection
  await deleteQueryInChunks(
    boardRef.collection('shapes'),
    `shapes of board ${id}`
  );

  // 3. Collaborators sub-collection
  await deleteQueryInChunks(
    boardRef.collection('collaborators'),
    `collaborators of board ${id}`
  );

  // 4. Board document
  await boardRef.delete();

  res.json({ message: 'Whiteboard deleted' });
}));

// POST /:id/share - Generate share link and access code (owner only)
router.post('/:id/share', authenticate, asyncHandler(async (req, res) => {
  if (!db.db) return res.status(503).json({ error: 'Database unavailable' });
  const { data } = await getBoardOr404(req.params.id);
  if (!isOwnerBoard(data, req.user.id)) {
    return res.status(403).json({ error: 'Only the board owner can share it' });
  }
  const shareLink = uuidv4().slice(0, 8);
  const accessCode = Math.random().toString(36).slice(2, 8).toUpperCase();
  await db.db.collection('whiteboards').doc(req.params.id).set({
    share_link: shareLink,
    access_code: accessCode,
    room_code: accessCode,
    updated_at: new Date().toISOString()
  }, { merge: true });
  res.json({ shareLink, accessCode });
}));

// POST /:id/duplicate - Duplicate whiteboard and its shapes sub-collection
// (owner or shared member). Copies never inherit share links/codes.
router.post('/:id/duplicate', authenticate, asyncHandler(async (req, res) => {
  if (!db.db) return res.status(503).json({ error: 'Database unavailable' });
  const { id, data } = await getBoardOr404(req.params.id);
  if (!isOwnerBoard(data, req.user.id) && !isSharedWith(data, req.user.id)) {
    return res.status(403).json({ error: 'Access denied' });
  }

  const boardRef = db.db.collection('whiteboards').doc(id);
  const newId = uuidv4();
  const newPayload = {
    ...data,
    id: newId,
    title: `${data.title || 'Untitled Board'} (Copy)`,
    owner_id: req.user.id,
    createdBy: req.user.id,
    // A duplicate starts unshared — never inherit anyone's share tokens.
    isShared: false,
    sharedWith: [],
    share_link: null,
    access_code: null,
    room_code: null,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString()
  };

  await db.db.collection('whiteboards').doc(newId).set(newPayload);

  // Copy shapes sub-collection (chunked for big boards)
  let copiedShapes = 0;
  for (let round = 0; round < 10; round += 1) {
    const shapesSnap = await boardRef.collection('shapes')
      .limit(BATCH_CHUNK)
      // offset skips the already-copied pages on subsequent rounds
      .offset(round * BATCH_CHUNK)
      .get();
    if (shapesSnap.empty) break;
    const copyBatch = db.db.batch();
    shapesSnap.docs.forEach(doc => {
      const newShapeId = uuidv4();
      const newShapeRef = db.db.collection('whiteboards').doc(newId).collection('shapes').doc(newShapeId);
      copyBatch.set(newShapeRef, {
        ...doc.data(),
        id: newShapeId,
        created_by: req.user.id,
        created_at: new Date().toISOString()
      });
    });
    await copyBatch.commit();
    copiedShapes += shapesSnap.size;
  }

  res.status(201).json({ id: newId, shapesCopied: copiedShapes, message: 'Whiteboard duplicated' });
}));

async function canWriteShapes(boardId, userId, forCreate = true) {
  const { data } = await getBoardOr404(boardId);
  if (isOwnerBoard(data, userId)) return true;
  const collabSnap = await db.db.collection('whiteboards').doc(boardId)
    .collection('collaborators').doc(userId).get();
  if (collabSnap.exists) return true;
  // Shared (link) boards allow adding shapes while enabled
  return forCreate && isSharedWith(data, userId);
}

// POST /:id/shapes - Add shape to whiteboards/{id}/shapes sub-collection
router.post('/:id/shapes', authenticate, asyncHandler(async (req, res) => {
  if (!db.db) return res.status(503).json({ error: 'Database unavailable' });
  if (!(await canWriteShapes(req.params.id, req.user.id))) {
    return res.status(403).json({ error: 'Access denied' });
  }
  const { type, data, style, z_index } = req.body;
  const id = uuidv4();
  const shapeData = {
    id,
    type: type || 'freehand',
    data: data || {},
    style: style || {},
    z_index: z_index || 0,
    created_by: req.user.id,
    created_at: new Date().toISOString()
  };

  await db.db.collection('whiteboards').doc(req.params.id).collection('shapes').doc(id).set(shapeData);
  res.status(201).json({ id });
}));

// PUT /:id/shapes/:shapeId - Update shape in whiteboards/{id}/shapes sub-collection
router.put('/:id/shapes/:shapeId', authenticate, asyncHandler(async (req, res) => {
  if (!db.db) return res.status(503).json({ error: 'Database unavailable' });
  if (!(await canWriteShapes(req.params.id, req.user.id))) {
    return res.status(403).json({ error: 'Access denied' });
  }
  const shapeRef = db.db.collection('whiteboards').doc(req.params.id).collection('shapes').doc(req.params.shapeId);
  const shapeSnap = await shapeRef.get();
  if (!shapeSnap.exists) return res.status(404).json({ error: 'Shape not found' });

  const updates = { ...req.body, updated_at: new Date().toISOString() };
  await shapeRef.set(updates, { merge: true });

  await db.db.collection('whiteboards').doc(req.params.id).set({
    last_edited_by: req.user.id,
    updated_at: new Date().toISOString()
  }, { merge: true });

  res.json({ message: 'Shape updated' });
}));

// DELETE /:id/shapes/:shapeId - Delete shape from whiteboards/{id}/shapes sub-collection
router.delete('/:id/shapes/:shapeId', authenticate, asyncHandler(async (req, res) => {
  if (!db.db) return res.status(503).json({ error: 'Database unavailable' });
  if (!(await canWriteShapes(req.params.id, req.user.id))) {
    return res.status(403).json({ error: 'Access denied' });
  }
  const shapeRef = db.db.collection('whiteboards').doc(req.params.id).collection('shapes').doc(req.params.shapeId);
  const shapeSnap = await shapeRef.get();
  if (!shapeSnap.exists) return res.status(404).json({ error: 'Shape not found' });

  await shapeRef.delete();
  res.json({ message: 'Shape deleted' });
}));

// POST /:id/versions - Create restore point in whiteboard_versions collection
// (owner only; version number is allocated inside a Firestore transaction so
// concurrent saves can never produce duplicate version numbers).
router.post('/:id/versions', authenticate, asyncHandler(async (req, res) => {
  if (!db.db) return res.status(503).json({ error: 'Database unavailable' });
  const { id, data } = await getBoardOr404(req.params.id);
  if (!isOwnerBoard(data, req.user.id)) {
    return res.status(403).json({ error: 'Access denied' });
  }

  const shapesSnap = await db.db.collection('whiteboards').doc(id).collection('shapes').limit(600).get();
  const shapes = shapesSnap.docs.map(d => ({ id: d.id, ...d.data() }));

  const idResult = await db.db.runTransaction(async (tx) => {
    const boardRef = db.db.collection('whiteboards').doc(id);
    const txBoard = await tx.get(boardRef);
    const currentTotal = txBoard.exists ? (txBoard.data().total_versions || 0) : 0;
    const versionNumber = currentTotal + 1;
    const versionId = uuidv4();
    const versionPayload = {
      id: versionId,
      whiteboard_id: id,
      version_number: versionNumber,
      owner_id: req.user.id,
      snapshot: shapes,
      created_by: req.user.id,
      description: req.body.description || `Version ${versionNumber}`,
      created_at: new Date().toISOString()
    };

    tx.set(db.db.collection('whiteboard_versions').doc(versionId), versionPayload);
    tx.set(boardRef, {
      total_versions: versionNumber,
      updated_at: new Date().toISOString()
    }, { merge: true });

    return { versionId, versionNumber };
  });

  res.status(201).json({ id: idResult.versionId, versionNumber: idResult.versionNumber });
}));

// GET /:id/versions - List snapshot history from whiteboard_versions collection
router.get('/:id/versions', authenticate, asyncHandler(async (req, res) => {
  if (!db.db) return res.status(404).json({ error: 'Database unavailable' });
  const { data } = await getBoardOr404(req.params.id);
  if (!isOwnerBoard(data, req.user.id) && !isSharedWith(data, req.user.id)) {
    return res.status(403).json({ error: 'Access denied' });
  }

  const versionsSnap = await db.db.collection('whiteboard_versions')
    .where('whiteboard_id', '==', req.params.id)
    .limit(50)
    .get();
  const versions = versionsSnap.docs.map(d => {
    const v = d.data();
    return {
      id: d.id,
      version_number: v.version_number,
      created_by: v.created_by,
      description: v.description,
      created_at: v.created_at
    };
  });
  versions.sort((a, b) => (b.version_number || 0) - (a.version_number || 0));
  res.json(versions);
}));

// POST /:id/restore/:versionId - Restore canvas from whiteboard_versions collection
// (owner only; the version must belong to the SAME board — cross-board restores
// are rejected, which prevents pointer/id corruption between records).
router.post('/:id/restore/:versionId', authenticate, asyncHandler(async (req, res) => {
  if (!db.db) return res.status(503).json({ error: 'Database unavailable' });
  const { id, data } = await getBoardOr404(req.params.id);
  if (!isOwnerBoard(data, req.user.id)) {
    return res.status(403).json({ error: 'Access denied' });
  }

  const versionDoc = await db.db.collection('whiteboard_versions').doc(req.params.versionId).get();
  if (!versionDoc.exists) return res.status(404).json({ error: 'Version not found' });
  const versionData = versionDoc.data();
  if (versionData.whiteboard_id !== id) {
    return res.status(400).json({ error: 'Version does not belong to this whiteboard' });
  }

  const { snapshot } = versionData;
  const boardShapesRef = db.db.collection('whiteboards').doc(id).collection('shapes');

  // Clear current shapes (chunked so oversized boards cannot break the batch)
  await deleteQueryInChunks(boardShapesRef, `shapes of board ${id} (restore precondition)`);

  // Restore snapshot shapes (chunked writes)
  if (Array.isArray(snapshot)) {
    for (let i = 0; i < snapshot.length; i += BATCH_CHUNK) {
      const chunk = snapshot.slice(i, i + BATCH_CHUNK);
      const batch = db.db.batch();
      chunk.forEach(shape => {
        const shapeId = shape.id || uuidv4();
        const ref = boardShapesRef.doc(shapeId);
        batch.set(ref, { ...shape, id: shapeId, updated_at: new Date().toISOString() });
      });
      await batch.commit();
    }
  }

  await db.db.collection('whiteboards').doc(id).set({
    last_edited_by: req.user.id,
    updated_at: new Date().toISOString()
  }, { merge: true });

  res.json({ message: 'Version restored' });
}));

module.exports = router;
