const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/auth');
const { asyncHandler } = require('../middleware/errorHandler');
const db = require('../config/db');

// GET /api/settings - Retrieve user settings from userSettings collection
router.get('/', authenticate, asyncHandler(async (req, res) => {
  const userId = req.user.id;
  if (!db.db) return res.json({});
  const settingsDoc = await db.db.collection('userSettings').doc(userId).get();
  if (settingsDoc.exists) {
    return res.json({ id: settingsDoc.id, ...settingsDoc.data() });
  }
  res.json({
    id: userId,
    theme: 'system',
    accentColor: '#3b82f6',
    enableGestures: true,
    enableVoice: true,
    autoSave: true,
    soundEffects: false,
    highContrast: false,
    gridLines: true
  });
}));

// PUT /api/settings - Update user settings in userSettings collection
router.put('/', authenticate, asyncHandler(async (req, res) => {
  const userId = req.user.id;
  const updates = {
    ...req.body,
    updated_at: new Date().toISOString()
  };
  if (db.db) {
    await db.db.collection('userSettings').doc(userId).set(updates, { merge: true });
  }
  res.json({ success: true, message: 'User settings updated', settings: updates });
}));

// DELETE /api/settings - Reset user settings
router.delete('/', authenticate, asyncHandler(async (req, res) => {
  const userId = req.user.id;
  if (db.db) {
    await db.db.collection('userSettings').doc(userId).delete();
  }
  res.json({ success: true, message: 'User settings reset' });
}));

module.exports = router;
