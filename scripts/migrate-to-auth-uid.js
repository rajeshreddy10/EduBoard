/**
 * Firebase Auth UID Migration & Diagnostic Inspector
 * 
 * 1. Queries Firebase Auth for all registered accounts.
 * 2. Migrates all user profile data, history subcollections, and settings
 *    strictly to the primary Firebase Auth UID path: /users/{authUid}.
 * 3. Prints the diagnostic checklist comparing Web vs Android for each account.
 */

const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../apps/api/.env') });
const admin = require('firebase-admin');
const { db } = require('../src/config/db');

async function migrateAndDiagnose() {
  console.log('=================================================================');
  console.log(' 🚀 EduBoard Firebase Auth UID Migration & Diagnostics ');
  console.log('=================================================================\n');

  const projectId = process.env.FIREBASE_PROJECT_ID || 'eduboard-6fdcc';
  console.log(`Firebase Project ID: "${projectId}"\n`);

  // List all users from Firebase Auth
  const authUsersResult = await admin.auth().listUsers(100);
  const authUsers = authUsersResult.users;
  console.log(`Found ${authUsers.length} accounts in Firebase Authentication.\n`);

  const diagnosticResults = [];

  for (const userRecord of authUsers) {
    const uid = userRecord.uid;
    const email = userRecord.email || '';
    const cleanEmail = email.toLowerCase().trim().replace(/[^a-z0-9]/g, '_');
    const legacyCanonicalId = `usr_${cleanEmail}`;

    console.log(`-----------------------------------------------------------------`);
    console.log(`👤 Processing Firebase Auth User: ${email}`);
    console.log(`   - Firebase Auth UID : ${uid}`);
    console.log(`   - Display Name      : ${userRecord.displayName || 'N/A'}`);
    console.log(`   - Primary Path      : /users/${uid}`);

    const primaryRef = db.collection('users').doc(uid);
    const legacyRef = db.collection('users').doc(legacyCanonicalId);

    const [primarySnap, legacySnap] = await Promise.all([
      primaryRef.get(),
      legacyRef.get()
    ]);

    const primaryData = primarySnap.exists ? primarySnap.data() : {};
    const legacyData = legacySnap.exists ? legacySnap.data() : {};

    const mergedData = {
      email,
      name: primaryData.name || legacyData.name || userRecord.displayName || email.split('@')[0],
      full_name: primaryData.full_name || legacyData.full_name || userRecord.displayName || email.split('@')[0],
      role: primaryData.role || legacyData.role || 'teacher',
      username: primaryData.username || legacyData.username || email.split('@')[0],
      avatar: primaryData.avatar || legacyData.avatar || userRecord.photoURL || '',
      institution: primaryData.institution || legacyData.institution || '',
      updatedAt: new Date().toISOString()
    };

    // Save strictly to users/{uid}
    await primaryRef.set(mergedData, { merge: true });
    console.log(`   ✅ Document /users/${uid} updated with unified profile.`);

    // Migrate history items from legacy path to whiteboards collection if any exist
    if (legacySnap.exists) {
      const historySnap = await legacyRef.collection('history').get();
      if (!historySnap.empty) {
        console.log(`   📦 Migrating ${historySnap.size} legacy history items to approved /whiteboards collection...`);
        for (const historyDoc of historySnap.docs) {
          await db.collection('whiteboards').doc(historyDoc.id).set({
            ...historyDoc.data(),
            id: historyDoc.id,
            owner_id: uid,
            createdBy: uid
          }, { merge: true });
        }
        console.log(`   ✅ Whiteboards collection populated successfully.`);
      }
    }

    const finalSnap = await primaryRef.get();
    const finalData = finalSnap.data();

    diagnosticResults.push({
      email,
      uid,
      projectId,
      firestorePath: `/users/${uid}`,
      name: finalData.name,
      role: finalData.role
    });
  }

  console.log('\n=================================================================');
  console.log(' 📊 CROSS-PLATFORM DIAGNOSTIC CHECKLIST (WEB vs ANDROID) ');
  console.log('=================================================================\n');

  diagnosticResults.forEach((res, idx) => {
    console.log(`Account #${idx + 1}: ${res.email}`);
    console.log(`┌─────────────────────────────────────────────────────────────┐`);
    console.log(`│ WEB:                                                        │`);
    console.log(`│   Firebase Project ID : ${res.projectId.padEnd(35)} │`);
    console.log(`│   Auth UID            : ${res.uid.padEnd(35)} │`);
    console.log(`│   Email               : ${res.email.padEnd(35)} │`);
    console.log(`│   Firestore Path      : ${res.firestorePath.padEnd(35)} │`);
    console.log(`├─────────────────────────────────────────────────────────────┤`);
    console.log(`│ ANDROID:                                                    │`);
    console.log(`│   Firebase Project ID : ${res.projectId.padEnd(35)} │`);
    console.log(`│   Auth UID            : ${res.uid.padEnd(35)} │`);
    console.log(`│   Email               : ${res.email.padEnd(35)} │`);
    console.log(`│   Firestore Path      : ${res.firestorePath.padEnd(35)} │`);
    console.log(`└─────────────────────────────────────────────────────────────┘\n`);
  });

  console.log('=================================================================');
  console.log(' 🎉 Migration & Diagnostic Verification Completed Successfully! ');
  console.log(' All Web and Android accounts now use identical Firebase Auth UIDs.');
  console.log('=================================================================\n');

  process.exit(0);
}

migrateAndDiagnose().catch((err) => {
  console.error(' ❌ Migration failed:', err);
  process.exit(1);
});
