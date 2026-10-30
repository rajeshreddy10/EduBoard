const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/auth');
const { asyncHandler } = require('../middleware/errorHandler');
const db = require('../config/db');

// GET /rooms - Active whiteboard collaboration rooms for the user
router.get('/rooms', authenticate, asyncHandler(async (req, res) => {
  if (!db.db) return res.json([]);
  const snap = await db.db.collection('whiteboards').where('owner_id', '==', req.user.id).get();
  const rooms = snap.docs.map(doc => {
    const data = doc.data();
    return {
      id: doc.id,
      whiteboard_id: doc.id,
      name: data.title || 'Collaboration Room',
      room_code: data.room_code || data.access_code || doc.id.slice(0, 6).toUpperCase(),
      whiteboard_title: data.title || 'Untitled Board',
      created_at: data.created_at || new Date().toISOString()
    };
  });
  res.json(rooms);
}));

// POST /rooms - Assign or generate a collaboration room code for a whiteboard
router.post('/rooms', authenticate, asyncHandler(async (req, res) => {
  const { whiteboardId, name } = req.body;
  const roomCode = Math.random().toString(36).slice(2, 8).toUpperCase();
  const targetId = whiteboardId || require('uuid').v4();

  if (db.db) {
    await db.db.collection('whiteboards').doc(targetId).set({
      id: targetId,
      room_code: roomCode,
      title: name || 'Collaboration Room',
      owner_id: req.user.id,
      updated_at: new Date().toISOString()
    }, { merge: true });
  }

  res.status(201).json({ id: targetId, roomCode, whiteboardId: targetId });
}));

// POST /rooms/join (Strictly resolves against whiteboards and saves collaborator subcollection)
router.post('/rooms/join', authenticate, asyncHandler(async (req, res) => {
  const { roomCode } = req.body;
  if (!roomCode) return res.status(400).json({ error: 'Room code required' });

  const code = roomCode.toUpperCase().trim();
  let boardDoc = null;

  if (db.db) {
    // 1. Query whiteboards by room_code
    const snapCode = await db.db.collection('whiteboards').where('room_code', '==', code).get();
    if (!snapCode.empty) {
      boardDoc = snapCode.docs[0];
    } else {
      // 2. Query whiteboards by access_code
      const snapAccess = await db.db.collection('whiteboards').where('access_code', '==', code).get();
      if (!snapAccess.empty) {
        boardDoc = snapAccess.docs[0];
      } else {
        // 3. Fallback direct whiteboard ID
        const docDirect = await db.db.collection('whiteboards').doc(roomCode.trim()).get();
        if (docDirect.exists) boardDoc = docDirect;
      }
    }
  }

  if (!boardDoc) {
    return res.status(404).json({ error: 'Whiteboard session not found or inactive' });
  }

  // Register in whiteboards/{boardId}/collaborators/{userId} sub-collection
  const collabRef = db.db.collection('whiteboards').doc(boardDoc.id).collection('collaborators').doc(req.user.id);
  await collabRef.set({
    user_id: req.user.id,
    permission: 'edit',
    is_online: true,
    last_active_at: new Date().toISOString()
  }, { merge: true });

  res.json({ roomId: boardDoc.id, whiteboardId: boardDoc.id });
}));

// GET /room/:id/participants (Reads from whiteboards/{id}/collaborators sub-collection)
router.get('/room/:id/participants', authenticate, asyncHandler(async (req, res) => {
  if (!db.db) return res.json([]);
  const collabSnap = await db.db.collection('whiteboards').doc(req.params.id).collection('collaborators').get();
  const participants = collabSnap.docs.map(d => ({ id: d.id, ...d.data() }));
  res.json(participants);
}));

module.exports = router;
