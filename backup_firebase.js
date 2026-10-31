const { initializeApp, cert, getApps } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const fs = require('fs');
const path = require('path');

const serviceAccount = require('./apps/api/serviceAccountKey.json');

const app = getApps().length === 0 ? initializeApp({
  credential: cert(serviceAccount)
}) : getApps()[0];

const db = getFirestore(app);

async function backup() {
  console.log('=== STARTING COMPLETE FIREBASE FIRESTORE BACKUP ===');
  const collections = await db.listCollections();
  const backupData = {
    timestamp: new Date().toISOString(),
    projectId: serviceAccount.project_id,
    collections: {}
  };

  for (const col of collections) {
    console.log(`Backing up collection [${col.id}]...`);
    const snap = await col.get();
    backupData.collections[col.id] = {};
    snap.forEach(doc => {
      backupData.collections[col.id][doc.id] = doc.data();
    });
    console.log(`   Saved ${snap.size} documents for [${col.id}]`);
  }

  const backupFilePath = path.resolve(__dirname, 'firebase_backup_2026_10_31.json');
  fs.writeFileSync(backupFilePath, JSON.stringify(backupData, null, 2));
  console.log(`\n=== BACKUP SUCCESSFULLY WRITTEN TO: ${backupFilePath} ===`);
}

backup().then(() => process.exit(0)).catch(e => { console.error('Backup failed:', e); process.exit(1); });
