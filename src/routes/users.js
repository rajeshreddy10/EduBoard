const express = require('express');
const router = express.Router();
const { authenticate, requireRole } = require('../middleware/auth');
const { asyncHandler } = require('../middleware/errorHandler');
const db = require('../config/db');

// GET / - List users
router.get('/', authenticate, asyncHandler(async (req, res) => {
  if (!db.db) return res.json([]);
  const snap = await db.db.collection('users').get();
  const users = snap.docs.map(doc => {
    const data = doc.data();
    delete data.password_hash;
    return { id: doc.id, ...data };
  });
  res.json(users);
}));

// GET /:id - Retrieve single user profile
router.get('/:id', authenticate, asyncHandler(async (req, res) => {
  if (!db.db) return res.status(404).json({ error: 'Database unavailable' });
  const userDoc = await db.db.collection('users').doc(req.params.id).get();
  if (!userDoc.exists) return res.status(404).json({ error: 'User not found' });

  const data = userDoc.data();
  delete data.password_hash;

  // Board count from whiteboards collection
  const boardSnap = await db.db.collection('whiteboards').where('owner_id', '==', req.params.id).get();

  res.json({
    id: userDoc.id,
    ...data,
    boardCount: boardSnap.size,
    collaboratorCount: 0
  });
}));

// PUT /:id/role - Update user role
router.put('/:id/role', requireRole('admin'), asyncHandler(async (req, res) => {
  const { role } = req.body;
  const validRoles = ['admin', 'teacher', 'student', 'viewer'];
  if (!validRoles.includes(role)) return res.status(400).json({ error: 'Invalid role' });
  if (db.db) {
    await db.db.collection('users').doc(req.params.id).set({
      role,
      updated_at: new Date().toISOString()
    }, { merge: true });
  }
  res.json({ message: 'Role updated' });
}));

// PUT /:id/status - Update user status
router.put('/:id/status', requireRole('admin'), asyncHandler(async (req, res) => {
  const { status } = req.body;
  const validStatuses = ['active', 'suspended', 'inactive'];
  if (!validStatuses.includes(status)) return res.status(400).json({ error: 'Invalid status' });
  if (db.db) {
    await db.db.collection('users').doc(req.params.id).set({
      status,
      updated_at: new Date().toISOString()
    }, { merge: true });
  }
  res.json({ message: 'Status updated' });
}));

// DELETE /:id - Delete user
router.delete('/:id', requireRole('admin'), asyncHandler(async (req, res) => {
  if (db.db) {
    await db.db.collection('users').doc(req.params.id).delete();
  }
  res.json({ message: 'User deleted' });
}));

module.exports = router;
