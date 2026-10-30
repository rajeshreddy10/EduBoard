/**
 * AI Controller
 * Express request handlers for all /api/ai endpoints.
 *
 * Centralises AI request handling so routes stay thin, error messages are
 * sanitized before reaching clients, and response contracts are consistent.
 */

const db = require('../config/db');
const aiService = require('../services/aiService');
const handwritingService = require('../services/handwritingService');

const MAX_IMAGE_LENGTH = 50 * 1024 * 1024; // 50MB base64 image ceiling

// POST /api/ai/handwriting — OCR / handwriting recognition
exports.handwriting = async (req, res) => {
  const { image } = req.body || {};
  if (!image || typeof image !== 'string') {
    return res.status(400).json({ error: 'Image data required' });
  }
  if (image.length > MAX_IMAGE_LENGTH) {
    return res.status(400).json({ error: 'Image data too large' });
  }

  const result = await handwritingService.recognizeHandwriting(image);

  res.json({
    success: Boolean(result.success),
    text: result.text || '',
    model: result.model || 'fallback',
    processingTime: result.processingTime || 0,
    tokensUsed: result.tokens || 0,
    isFallback: Boolean(result.isFallback || result.model === 'offline-ocr-heuristic'),
    ...(result.error ? { error: result.error } : {}),
  });
};

// POST /api/ai/format-text — OCR / grammar cleanup
exports.formatText = async (req, res) => {
  const { text, task } = req.body || {};
  if (!text || typeof text !== 'string' || !text.trim()) {
    return res.status(400).json({ error: 'Text required' });
  }
  if (text.length > 20000) {
    return res.status(400).json({ error: 'Text too long' });
  }

  const result = await aiService.formatText(text, task);
  res.json({
    success: true,
    formatted: result.formatted || text,
    model: result.model,
    isFallback: Boolean(result.isFallback),
    processingTime: result.processingTime,
  });
};

// POST /api/ai/summarize
exports.summarize = async (req, res) => {
  const { text } = req.body || {};
  if (!text || typeof text !== 'string' || !text.trim()) {
    return res.status(400).json({ error: 'Text is required' });
  }
  const result = await aiService.summarizeText(text.slice(0, 30000));
  res.json({ success: true, text: result.text, model: result.model, provider: result.provider });
};

// POST /api/ai/translate
exports.translate = async (req, res) => {
  const { text, targetLanguage } = req.body || {};
  if (!text || typeof text !== 'string' || !text.trim()) {
    return res.status(400).json({ error: 'Text is required' });
  }
  if (!targetLanguage || typeof targetLanguage !== 'string') {
    return res.status(400).json({ error: 'targetLanguage is required' });
  }
  const result = await aiService.translateText(text.slice(0, 10000), targetLanguage);
  res.json(result);
};

// GET /api/ai/history
exports.history = async (req, res) => {
  res.json([]);
};
