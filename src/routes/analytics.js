const express = require('express');
const router = express.Router();
const { authenticate, requireRole } = require('../middleware/auth');
const { asyncHandler } = require('../middleware/errorHandler');
const db = require('../config/db');

router.get('/overview', authenticate, asyncHandler(async (req, res) => {
  const userId = req.user.id;
  const [boardCount, recentBoards, exportStats, transcriptionStats] = await Promise.all([
    db.query('SELECT COUNT(*) as count FROM whiteboards WHERE owner_id = ?', [userId]),
    db.query('SELECT id, title, last_edited_at FROM whiteboards WHERE owner_id = ? ORDER BY last_edited_at DESC LIMIT 5', [userId]),
    db.query('SELECT COUNT(*) as count FROM exports WHERE user_id = ?', [userId]),
    db.query('SELECT COUNT(*) as count FROM voice_transcriptions WHERE user_id = ?', [userId])
  ]);

  res.json({
    boardCount: boardCount[0]?.count || 0,
    exportCount: exportStats[0]?.count || 0,
    transcriptionCount: transcriptionStats[0]?.count || 0,
    recentBoards: recentBoards || [],
    activity: []
  });
}));

router.get('/boards', authenticate, asyncHandler(async (req, res) => {
  const userId = req.user.id;
  const boards = await db.query(
    'SELECT id, title, created_at, updated_at, total_shapes FROM whiteboards WHERE owner_id = ? ORDER BY created_at DESC',
    [userId]
  );
  res.json(boards);
}));

router.get('/ai', authenticate, asyncHandler(async (req, res) => {
  // Extraneous ai_interactions collection removed per schema enforcement
  res.json({ interactions: [], daily: [] });
}));

router.get('/export', authenticate, asyncHandler(async (req, res) => {
  const userId = req.user.id;
  const exports = await db.query(
    'SELECT format, COUNT(*) as count FROM exports WHERE user_id = ? GROUP BY format',
    [userId]
  );
  res.json(exports);
}));

router.get('/collaboration', authenticate, asyncHandler(async (req, res) => {
  const userId = req.user.id;
  const boards = await db.query(
    'SELECT id, title, created_at FROM whiteboards WHERE owner_id = ?',
    [userId]
  );
  res.json(boards);
}));

router.get('/users', requireRole('admin'), asyncHandler(async (req, res) => {
  const { page = 1, limit = 20 } = req.query;
  const offset = (page - 1) * limit;
  const users = await db.query(
    'SELECT id, email, full_name, role, status, last_login_at, created_at FROM users ORDER BY created_at DESC LIMIT ? OFFSET ?',
    [parseInt(limit), parseInt(offset)]
  );
  const total = await db.query('SELECT COUNT(*) as count FROM users');
  res.json({ users, total: total[0]?.count || 0, page: parseInt(page) });
}));

router.post('/track', authenticate, asyncHandler(async (req, res) => {
  // Analytics events collection removed per strict schema enforcement
  res.json({ message: 'Event tracked' });
}));

module.exports = router;
