/**
 * EduBoard Backend Database Repository Adapter (Firebase Firestore Mode)
 *
 * Strictly enforces access ONLY to the 8 approved Firestore collections & sub-collections:
 * 1. users
 * 2. whiteboards (with sub-collections: shapes, collaborators)
 * 3. whiteboard_versions
 * 4. voice_transcriptions
 * 5. notifications
 * 6. userSettings
 * 7. exports
 */

const adminRaw = require('firebase-admin');
const admin = (adminRaw && adminRaw.apps) ? adminRaw : (adminRaw && adminRaw.default && adminRaw.default.apps) ? adminRaw.default : adminRaw;
const { initializeApp: initAppModular, cert: certModular, getApps: getAppsModular } = require('firebase-admin/app');
const { getFirestore: getFirestoreModular, FieldValue: FieldValueModular } = require('firebase-admin/firestore');
const path = require('path');
const fs = require('fs');

let appInstance = null;
const existingApps = getAppsModular();
if (existingApps.length === 0) {
  try {
    let serviceAccount = null;
    const candidates = [
      process.env.FIREBASE_SERVICE_ACCOUNT_PATH,
      path.resolve(__dirname, '../../apps/api/serviceAccountKey.json'),
      path.resolve(__dirname, '../apps/api/serviceAccountKey.json'),
      path.resolve(__dirname, './serviceAccountKey.json'),
      path.resolve(process.cwd(), 'apps/api/serviceAccountKey.json'),
      path.resolve(process.cwd(), 'serviceAccountKey.json')
    ].filter(Boolean);

    for (const p of candidates) {
      if (fs.existsSync(p)) {
        try {
          serviceAccount = require(p);
          console.log(`[Firebase Admin] Successfully loaded service account credentials from: ${p}`);
          break;
        } catch (e) {
          console.warn(`[Firebase Admin] Failed to parse service account at ${p}:`, e.message);
        }
      }
    }

    if (serviceAccount) {
      appInstance = initAppModular({
        credential: certModular(serviceAccount)
      });
    } else {
      appInstance = initAppModular({
        projectId: process.env.FIREBASE_PROJECT_ID || 'eduboard-6fdcc'
      });
    }
  } catch (error) {
    console.error('Firebase Admin initialization error:', error);
  }
} else {
  appInstance = existingApps[0];
}

const db = appInstance ? getFirestoreModular(appInstance) : null;

// Ensure backward compatibility for admin.firestore calls and FieldValue
if (admin) {
  if (!admin.firestore) {
    admin.firestore = () => db;
  }
  admin.firestore.FieldValue = FieldValueModular;
}

// Approved Firestore Collections Set
const APPROVED_COLLECTIONS = new Set([
  'users',
  'whiteboards',
  'whiteboard_versions',
  'voice_transcriptions',
  'notifications',
  'userSettings',
  'exports'
]);

// Blocked extraneous/experimental collections to reject completely
const UNAPPROVED_COLLECTIONS = new Set([
  'classrooms',
  'class_polls',
  'flashcard_decks',
  'spaced_reviews',
  'sessions',
  'comments',
  'ai_interactions',
  'analytics_events',
  'voice_commands',
  'collaboration_rooms',
  'collaboration_events',
  'support_tickets'
]);

// Map legacy / SQL table names to approved Firestore collections
function resolveApprovedCollection(rawName) {
  if (!rawName) return null;
  const normalized = rawName.trim();
  const lower = normalized.toLowerCase();

  if (UNAPPROVED_COLLECTIONS.has(lower)) {
    console.warn(`[Firestore DB Adapter] Blocked rejected collection: "${rawName}". Extraneous collections are removed.`);
    return null;
  }

  if (lower === 'boards' || lower === 'whiteboards') return 'whiteboards';
  if (lower === 'users') return 'users';
  if (lower === 'whiteboard_versions' || lower === 'versions') return 'whiteboard_versions';
  if (lower === 'voice_transcriptions' || lower === 'transcriptions') return 'voice_transcriptions';
  if (lower === 'notifications') return 'notifications';
  if (lower === 'usersettings' || lower === 'user_settings') return 'userSettings';
  if (lower === 'exports') return 'exports';

  if (APPROVED_COLLECTIONS.has(normalized)) return normalized;

  console.warn(`[Firestore DB Adapter] Collection "${rawName}" is not in approved schema. Request rejected.`);
  return null;
}

async function testConnection() {
  try {
    if (!db) return false;
    await db.listCollections();
    return true;
  } catch {
    return false;
  }
}

/**
 * Universal SQL-to-Firestore Abstraction Layer
 * Strictly maps queries to the approved collections only.
 */
async function query(sql, params = []) {
  if (!db) return [];
  const cleanSql = sql.trim();
  const op = cleanSql.split(' ')[0].toUpperCase();

  // Extract table name
  const tableMatch = cleanSql.match(/FROM\s+`?(\w+)`?/i) ||
                     cleanSql.match(/INTO\s+`?(\w+)`?/i) ||
                     cleanSql.match(/UPDATE\s+`?(\w+)`?/i) ||
                     cleanSql.match(/DELETE\s+FROM\s+`?(\w+)`?/i);

  const rawTable = tableMatch ? tableMatch[1] : null;
  const collectionName = resolveApprovedCollection(rawTable);

  // If table is rejected or not approved, fail-safe return
  if (!collectionName) {
    if (op === 'SELECT') return [];
    return { affectedRows: 0 };
  }

  const collection = db.collection(collectionName);

  try {
    if (op === 'SELECT') {
      let firestoreQuery = collection;

      // Handle COUNT
      if (cleanSql.includes('COUNT')) {
        const snapshot = await collection.get();
        return [{ total: snapshot.size, count: snapshot.size }];
      }

      // Handle WHERE (simple equality only)
      const whereMatch = cleanSql.match(/WHERE\s+(.+?)(?:ORDER|LIMIT|GROUP|$)/is);
      if (whereMatch) {
        const conditions = whereMatch[1];
        const matches = [...conditions.matchAll(/`?(\w+)`?\s*=\s*\?/g)];
        matches.forEach((match, index) => {
          const col = match[1];
          const val = params[index];
          if (val !== undefined) {
            firestoreQuery = firestoreQuery.where(col, '==', val);
          }
        });
      }

      // Handle ORDER BY
      const orderMatch = cleanSql.match(/ORDER BY\s+(.+?)(?:LIMIT|OFFSET|$)/i);
      if (orderMatch) {
        const orderings = orderMatch[1].split(',');
        orderings.forEach(order => {
          const [rawCol, rawDir] = order.trim().split(/\s+/);
          const col = rawCol.replace(/^(?:w|s|wc)\./, '').replace(/`/g, '').trim();
          const dir = (rawDir || 'ASC').toUpperCase() === 'DESC' ? 'desc' : 'asc';
          try {
            firestoreQuery = firestoreQuery.orderBy(col, dir);
          } catch {}
        });
      }

      // Handle LIMIT
      const limitMatch = cleanSql.match(/LIMIT\s+(\d+)/i);
      if (limitMatch) {
        firestoreQuery = firestoreQuery.limit(parseInt(limitMatch[1]));
      }

      const snapshot = await firestoreQuery.get();
      return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

    } else if (op === 'INSERT') {
      const colsMatch = cleanSql.match(/\(([^)]+)\)/);
      if (colsMatch) {
        const cols = colsMatch[1].split(',').map(c => c.trim().replace(/`/g, ''));
        const newRow = {};
        cols.forEach((c, i) => { if (params[i] !== undefined) newRow[c] = params[i]; });

        const id = newRow.id || params[0];
        delete newRow.id;

        if (id && cleanSql.includes('ON DUPLICATE KEY UPDATE')) {
          await collection.doc(id).set({
            ...newRow,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          }, { merge: true });
          return { insertId: id, affectedRows: 1 };
        }

        if (id) {
          await collection.doc(id).set({
            ...newRow,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
          return { insertId: id, affectedRows: 1 };
        } else {
          const docRef = await collection.add({
            ...newRow,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
          return { insertId: docRef.id, affectedRows: 1 };
        }
      }

    } else if (op === 'UPDATE') {
      const setMatch = cleanSql.match(/SET\s+(.+?)(?:WHERE|$)/is);
      const whereIdMatch = cleanSql.match(/WHERE\s+`?(id|whiteboard_id|user_id)`?\s*=\s*\?/i);

      if (setMatch && whereIdMatch) {
        const sets = setMatch[1].split(',').map(s => s.trim().split('=')[0].trim().replace(/`/g, ''));
        const updateData = {};
        sets.forEach((col, i) => { if (params[i] !== undefined) updateData[col] = params[i]; });
        updateData.updatedAt = admin.firestore.FieldValue.serverTimestamp();

        const field = whereIdMatch[1];
        const val = params[params.length - 1];

        if (field === 'id') {
          await collection.doc(val).update(updateData);
          return { affectedRows: 1 };
        } else {
          const snapshot = await collection.where(field, '==', val).get();
          const batch = db.batch();
          snapshot.docs.forEach(doc => batch.update(doc.ref, updateData));
          await batch.commit();
          return { affectedRows: snapshot.size };
        }
      }

    } else if (op === 'DELETE') {
      const whereMatch = cleanSql.match(/WHERE\s+`?(id|whiteboard_id|user_id)`?\s*=\s*\?/i);
      if (whereMatch && params[0]) {
        const field = whereMatch[1];
        const val = params[0];

        if (field === 'id') {
          await collection.doc(val).delete();
          return { affectedRows: 1 };
        } else {
          const snapshot = await collection.where(field, '==', val).get();
          const batch = db.batch();
          snapshot.docs.forEach(doc => batch.delete(doc.ref));
          await batch.commit();
          return { affectedRows: snapshot.size };
        }
      }
    }

    return [];
  } catch (error) {
    console.error(`Firestore query error (${op}) on collection [${collectionName}]:`, error);
    if (op === 'SELECT') return [];
    return { affectedRows: 0 };
  }
}

/**
 * Direct Native Firestore Data Access Helpers (Enforcing Approved Schema)
 */
const firestoreRepository = {
  async find(collectionName, conditions = {}, limit = 100) {
    const approved = resolveApprovedCollection(collectionName);
    if (!db || !approved) return [];
    let q = db.collection(approved);
    Object.entries(conditions).forEach(([key, val]) => {
      if (val !== undefined) q = q.where(key, '==', val);
    });
    if (limit) q = q.limit(limit);
    const snap = await q.get();
    return snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
  },

  async findById(collectionName, id) {
    const approved = resolveApprovedCollection(collectionName);
    if (!db || !approved || !id) return null;
    const doc = await db.collection(approved).doc(String(id)).get();
    return doc.exists ? { id: doc.id, ...doc.data() } : null;
  },

  async save(collectionName, id, data) {
    const approved = resolveApprovedCollection(collectionName);
    if (!db || !approved) return null;
    const docRef = id ? db.collection(approved).doc(String(id)) : db.collection(approved).doc();
    const payload = {
      ...data,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (!id) payload.createdAt = admin.firestore.FieldValue.serverTimestamp();
    await docRef.set(payload, { merge: true });
    return { id: docRef.id, ...payload };
  },

  async remove(collectionName, id) {
    const approved = resolveApprovedCollection(collectionName);
    if (!db || !approved || !id) return false;
    await db.collection(approved).doc(String(id)).delete();
    return true;
  }
};

module.exports = {
  db,
  admin,
  testConnection,
  query,
  firestoreRepository,
  APPROVED_COLLECTIONS,
  resolveApprovedCollection
};
