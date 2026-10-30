const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/auth');
const { asyncHandler } = require('../middleware/errorHandler');
const db = require('../config/db');
const { v4: uuidv4 } = require('uuid');

// GET /api/notifications - List notifications for user
router.get('/', authenticate, asyncHandler(async (req, res) => {
  if (!db.db) return res.json([]);
  const snap = await db.db.collection('notifications')
    .where('userId', '==', req.user.id)
    .get();

  let notifications = snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));

  // Fallback to snake_case field user_id if needed
  if (notifications.length === 0) {
    const snapSnake = await db.db.collection('notifications')
      .where('user_id', '==', req.user.id)
      .get();
    notifications = snapSnake.docs.map(doc => ({ id: doc.id, ...doc.data() }));
  }

  notifications.sort((a, b) => new Date(b.timestamp || b.created_at || 0) - new Date(a.timestamp || a.created_at || 0));
  res.json(notifications);
}));

// POST /api/notifications - Create notification
router.post('/', authenticate, asyncHandler(async (req, res) => {
  const { title, message, type, actionable, actionUrl, targetUserId } = req.body;
  const id = uuidv4();
  const userId = targetUserId || req.user.id;

  const notif = {
    id,
    userId,
    user_id: userId,
    title: title || 'Notification',
    message: message || '',
    type: type || 'info',
    read: false,
    actionable: Boolean(actionable),
    actionUrl: actionUrl || '',
    timestamp: new Date().toISOString(),
    created_at: new Date().toISOString()
  };

  if (db.db) {
    await db.db.collection('notifications').doc(id).set(notif);
  }

  res.status(201).json(notif);
}));

// PUT /api/notifications/:id/read - Mark as read
router.put('/:id/read', authenticate, asyncHandler(async (req, res) => {
  if (db.db) {
    await db.db.collection('notifications').doc(req.params.id).set({
      read: true,
      updated_at: new Date().toISOString()
    }, { merge: true });
  }
  res.json({ message: 'Notification marked as read' });
}));

// PUT /api/notifications/read-all - Mark all as read
router.put('/read-all', authenticate, asyncHandler(async (req, res) => {
  if (db.db) {
    const snap = await db.db.collection('notifications')
      .where('userId', '==', req.user.id)
      .where('read', '==', false)
      .get();

    const batch = db.db.batch();
    snap.docs.forEach(doc => {
      batch.update(doc.ref, { read: true, updated_at: new Date().toISOString() });
    });
    await batch.commit();
  }
  res.json({ message: 'All notifications marked as read' });
}));

// DELETE /api/notifications/:id - Delete notification
router.delete('/:id', authenticate, asyncHandler(async (req, res) => {
  if (db.db) {
    await db.db.collection('notifications').doc(req.params.id).delete();
  }
  res.json({ message: 'Notification deleted' });
}));

module.exports = router;
