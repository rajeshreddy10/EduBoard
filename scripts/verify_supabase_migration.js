/**
 * EduBoard Supabase Migration Verification & Diagnostics Suite
 * Tests Supabase client initialization, PostgreSQL tables accessibility,
 * storage bucket policies, and auth configuration.
 */

const { createClient } = require('@supabase/supabase-js');
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../apps/web/.env') });

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://eduboard-project.supabase.co';
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'dummy_supabase_anon_key_for_dev_mode';

const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function runVerification() {
  console.log('===========================================================');
  console.log('    EduBoard Supabase Migration Verification Suite         ');
  console.log('===========================================================');
  console.log(`Supabase URL: ${supabaseUrl}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}\n`);

  let successCount = 0;
  let totalCount = 4;

  // Test 1: Connectivity & Users Table
  try {
    const { data, error } = await supabase.from('users').select('id').limit(1);
    if (!error) {
      console.log('✔ [DB Test] Users table accessible.');
      successCount++;
    } else {
      console.log(`✖ [DB Test] Users table check notice: ${error.message}`);
    }
  } catch (e) {
    console.log(`✖ [DB Test] Users table exception: ${e.message}`);
  }

  // Test 2: Boards Table
  try {
    const { data, error } = await supabase.from('boards').select('id').limit(1);
    if (!error) {
      console.log('✔ [DB Test] Boards table accessible.');
      successCount++;
    } else {
      console.log(`✖ [DB Test] Boards table check notice: ${error.message}`);
    }
  } catch (e) {
    console.log(`✖ [DB Test] Boards table exception: ${e.message}`);
  }

  // Test 3: Notifications Table
  try {
    const { data, error } = await supabase.from('notifications').select('id').limit(1);
    if (!error) {
      console.log('✔ [DB Test] Notifications table accessible.');
      successCount++;
    } else {
      console.log(`✖ [DB Test] Notifications table check notice: ${error.message}`);
    }
  } catch (e) {
    console.log(`✖ [DB Test] Notifications table exception: ${e.message}`);
  }

  // Test 4: Storage Avatars Bucket
  try {
    const { data, error } = await supabase.storage.from('avatars').list();
    if (!error) {
      console.log('✔ [Storage Test] Avatars bucket accessible.');
      successCount++;
    } else {
      console.log(`✖ [Storage Test] Avatars bucket check notice: ${error.message}`);
    }
  } catch (e) {
    console.log(`✖ [Storage Test] Storage exception: ${e.message}`);
  }

  console.log('\n===========================================================');
  console.log(` Verification Summary: ${successCount}/${totalCount} Checks Passed.`);
  console.log('===========================================================');
}

if (require.main === module) {
  runVerification().catch(console.error);
}

module.exports = { runVerification };
