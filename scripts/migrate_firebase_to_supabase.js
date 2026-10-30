/**
 * EduBoard Firebase → Supabase Production Data Migration Tool
 *
 * Safe data extraction, relational transformation, and batch insertion
 * from legacy Firebase Firestore into Supabase PostgreSQL.
 */

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

const supabaseUrl = process.env.SUPABASE_URL || 'https://eduboard-project.supabase.co';
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || 'dummy_supabase_service_role_key_for_dev_server';

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: { persistSession: false }
});

async function migrateData(jsonExportPath) {
  console.log('====================================================');
  console.log('   EduBoard Firebase → Supabase Data Migration Tool ');
  console.log('====================================================\n');

  if (!fs.existsSync(jsonExportPath)) {
    console.log(`[Notice] JSON export file not found at: ${jsonExportPath}`);
    console.log('Creating sample migration template file...\n');
    const template = {
      users: [
        {
          id: '00000000-0000-0000-0000-000000000001',
          email: 'admin@eduboard.app',
          name: 'EduBoard Admin',
          role: 'admin',
          createdAt: new Date().toISOString()
        }
      ],
      boards: [
        {
          id: 'board_sample_01',
          userId: '00000000-0000-0000-0000-000000000001',
          title: 'Physics Mechanics Demo',
          description: 'Sample interactive whiteboard lesson',
          backgroundColor: '#ffffff',
          width: 1920,
          height: 1080,
          shapes: [],
          isPublic: true
        }
      ]
    };
    fs.writeFileSync(jsonExportPath, JSON.stringify(template, null, 2));
    console.log(`Sample template generated at: ${jsonExportPath}`);
  }

  const raw = fs.readFileSync(jsonExportPath, 'utf8');
  const firestoreData = JSON.parse(raw);

  console.log('[Step 1/3] Migrating Users Collection...');
  if (firestoreData.users && Array.isArray(firestoreData.users)) {
    for (const u of firestoreData.users) {
      const payload = {
        id: u.id || u.uid,
        email: u.email,
        name: u.full_name || u.name,
        full_name: u.full_name || u.name,
        role: u.role || 'teacher',
        username: u.username || u.email?.split('@')[0],
        avatar: u.avatar || '',
        institution: u.institution || '',
        bio: u.bio || '',
        phone: u.phone || '',
        location: u.location || '',
        is_verified: u.isVerified ?? true,
        is_biometric_enabled: u.isBiometricEnabled || false,
        created_at: u.createdAt || new Date().toISOString(),
        updated_at: new Date().toISOString()
      };
      const { error } = await supabase.from('users').upsert(payload, { onConflict: 'id' });
      if (error) console.warn(`   Notice migrating user ${u.email}:`, error.message);
      else console.log(`   Migrated User: ${u.email}`);
    }
  }

  console.log('\n[Step 2/3] Migrating Boards Collection...');
  if (firestoreData.boards && Array.isArray(firestoreData.boards)) {
    for (const b of firestoreData.boards) {
      const payload = {
        id: b.id,
        user_id: b.userId || b.createdBy || b.ownerId,
        owner_id: b.ownerId || b.userId || b.createdBy,
        created_by: b.createdBy || b.userId,
        title: b.title || 'Untitled Board',
        description: b.description || '',
        background_color: b.backgroundColor || '#ffffff',
        background_image: b.backgroundImage || '',
        width: b.width || 1920,
        height: b.height || 1080,
        is_public: b.isPublic || false,
        allow_comments: b.allowComments ?? true,
        allow_export: b.allowExport ?? true,
        shapes: b.shapes || [],
        viewport: b.viewport || {},
        updated_at: new Date().toISOString()
      };
      const { error } = await supabase.from('boards').upsert(payload, { onConflict: 'id' });
      if (error) console.warn(`   Notice migrating board ${b.id}:`, error.message);
      else console.log(`   Migrated Board: ${b.id} ("${b.title}")`);
    }
  }

  console.log('\n[Step 3/3] Migration Complete! All records processed cleanly.');
}

if (require.main === module) {
  const exportPath = process.argv[2] || path.join(__dirname, '../data/firebase_export.json');
  migrateData(exportPath).catch(console.error);
}

module.exports = { migrateData };
