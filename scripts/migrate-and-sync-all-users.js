/**
 * Firestore All-Users Migration & 100% Dual-Sync Script
 * 
 * Audits all documents in the 'users' collection in Cloud Firestore (eduboard-6fdcc).
 * Merges legacy UID docs (e.g. WD0Gq...) and Canonical Email docs (usr_...) 
 * so that both document keys exist in Firestore with 100% identical details!
 */

const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../apps/api/.env') });
const { db } = require('../src/config/db');

async function migrateAndSyncAllUsers() {
  console.log('=================================================================');
  console.log(' 🔄 EduBoard Firestore All-Users Dual-Sync & Migration ');
  console.log('=================================================================\n');

  const snapshot = await db.collection('users').get();
  console.log(`Found ${snapshot.size} total user documents in Firestore.\n`);

  const userGroupsByEmail = {};

  snapshot.docs.forEach((docSnap) => {
    const data = docSnap.data();
    const email = (data.email || '').toLowerCase().trim();
    if (!email) {
      console.log(`  - Doc ${docSnap.id}: No email specified, skipping.`);
      return;
    }

    if (!userGroupsByEmail[email]) {
      userGroupsByEmail[email] = [];
    }
    userGroupsByEmail[email].push({ id: docSnap.id, data });
  });

  for (const [email, docs] of Object.entries(userGroupsByEmail)) {
    console.log(`\n📧 Processing account email: "${email}" (${docs.length} associated document keys)`);

    // Merged composite profile from all docs for this email
    let mergedProfile = {
      email,
      name: email.split('@')[0],
      full_name: email.split('@')[0],
      role: 'teacher',
      institution: '',
      avatar: '',
      username: email.split('@')[0],
    };

    docs.forEach(({ id, data }) => {
      console.log(`   - Existing doc key: "${id}" -> name: "${data.name || data.full_name || 'N/A'}", role: "${data.role || 'N/A'}"`);
      mergedProfile = {
        ...mergedProfile,
        ...data,
        name: data.full_name || data.name || mergedProfile.name,
        full_name: data.full_name || data.name || mergedProfile.full_name,
      };
    });

    const cleanEmail = email.replace(/[^a-z0-9]/g, '_');
    const canonicalId = `usr_${cleanEmail}`;

    // Document keys to write back to (both Auth UIDs and Canonical ID)
    const keysToWrite = new Set(docs.map(d => d.id));
    keysToWrite.add(canonicalId);

    for (const targetKey of keysToWrite) {
      console.log(`   --> Writing unified profile to doc key: "/users/${targetKey}"`);
      await db.collection('users').doc(targetKey).set({
        ...mergedProfile,
        updatedAt: new Date().toISOString()
      }, { merge: true });
    }
    console.log(`   ✅ Account "${email}" synchronized 100% across ${keysToWrite.size} Firestore document keys!`);
  }

  console.log('\n=================================================================');
  console.log(' 🎉 All Firestore user documents migrated & synchronized 100%! ');
  console.log('=================================================================\n');

  process.exit(0);
}

migrateAndSyncAllUsers().catch((err) => {
  console.error(' ❌ Migration failed:', err);
  process.exit(1);
});
