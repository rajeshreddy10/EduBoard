const { initializeApp, cert, getApps } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');
const path = require('path');
const fs = require('fs');

const serviceAccount = require('./apps/api/serviceAccountKey.json');

const app = getApps().length === 0 ? initializeApp({
  credential: cert(serviceAccount),
  storageBucket: serviceAccount.project_id + '.firebasestorage.app'
}) : getApps()[0];

const db = getFirestore(app);
const bucket = getStorage(app).bucket();

async function runAudit() {
  console.log('=== FIREBASE AUDIT REPORT ===');
  console.log('Project ID:', serviceAccount.project_id);

  // 1. List all collections
  const collections = await db.listCollections();
  console.log('\n--- ROOT FIRESTORE COLLECTIONS (' + collections.length + ') ---');
  for (const col of collections) {
    const snap = await col.get();
    console.log(`\nCollection: [${col.id}] -> ${snap.size} documents`);
    const docIds = snap.docs.map(d => d.id);
    console.log(`   Sample Doc IDs (${docIds.length}):`, docIds.slice(0, 10));
  }

  // 2. Deep inspect "users" collection
  console.log('\n--- USERS COLLECTION DETAILS ---');
  const usersSnap = await db.collection('users').get();
  usersSnap.forEach(doc => {
    const data = doc.data();
    console.log(`\nDoc ID: "${doc.id}"`);
    console.log(`   email: "${data.email}"`);
    console.log(`   name: "${data.name || data.full_name}"`);
    console.log(`   address: "${data.address}"`);
    console.log(`   organization: "${data.organization || data.institution}"`);
    console.log(`   phone: "${data.phone || data.phoneNumber || data.phone_number}"`);
    console.log(`   location: "${data.location}"`);
    console.log(`   bio: "${data.bio}"`);
    console.log(`   avatar: "${(data.avatar || data.avatarUrl || '').substring(0, 50)}..."`);
    console.log(`   updated_at: "${data.updated_at || data.updatedAt}"`);
  });

  // 3. Inspect Firebase Storage
  console.log('\n--- FIREBASE STORAGE AUDIT ---');
  try {
    const [files] = await bucket.getFiles({ maxResults: 100 });
    console.log(`Found ${files.length} files in default storage bucket:`);
    files.forEach(f => {
      console.log(`   File: ${f.name} (${f.metadata.size} bytes, type: ${f.metadata.contentType})`);
    });
  } catch (err) {
    console.log('Storage inspection error:', err.message);
  }
}

runAudit().then(() => {
  console.log('\n=== AUDIT COMPLETE ===');
  process.exit(0);
}).catch(err => {
  console.error('Audit failed:', err);
  process.exit(1);
});
