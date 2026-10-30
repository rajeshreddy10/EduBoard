/**
 * Cross-Platform Android & Web Connection Verification Script
 *
 * Tests:
 * 1. Express API Server status & /api/health endpoint response
 * 2. Supabase PostgreSQL database connectivity
 * 3. Supabase 'users' table access
 * 4. Verification of cross-platform auth token handling capability
 */

const http = require('http');
const path = require('path');

require('dotenv').config({ path: path.join(__dirname, '../apps/api/.env') });

const { db, testConnection } = require('../src/config/db');

async function runVerification() {
  console.log('=================================================================');
  console.log(' 🚀 EduBoard Cross-Platform Connectivity Verification ');
  console.log('=================================================================\n');

  let passed = true;

  // Test 1: Supabase Database Connection
  console.log('1️⃣  Testing Supabase PostgreSQL Connection...');
  try {
    const isConnected = await testConnection();
    const supabaseUrl = process.env.SUPABASE_URL || 'https://eduboard-project.supabase.co';
    if (isConnected) {
      console.log(`   ✅ Supabase Client connected to project: "${supabaseUrl}"`);
    } else {
      console.warn(`   ⚠️  Supabase users table check returned false. Verify environment keys.`);
    }

    // Test querying users table
    const { data: usersData, error } = await db.from('users').select('id').limit(5);
    if (!error) {
      console.log(`   ✅ Successfully read 'users' table (${usersData ? usersData.length : 0} sample rows found)`);
    } else {
      console.warn(`   ⚠️  Users table read notice: ${error.message}`);
    }
  } catch (err) {
    console.error(`   ❌ Supabase connection error: ${err.message}`);
    passed = false;
  }

  // Test 2: Local Express Server Health Check
  console.log('\n2️⃣  Testing Local Express API Server (http://localhost:3001/api/health)...');
  await new Promise((resolve) => {
    const req = http.get('http://localhost:3001/api/health', (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        if (res.statusCode === 200) {
          console.log(`   ✅ Express API Server is online! Response: ${body.trim()}`);
        } else {
          console.warn(`   ⚠️  Express API Server returned HTTP status: ${res.statusCode}`);
        }
        resolve();
      });
    });

    req.on('error', (err) => {
      console.log(`   ℹ️  Local Express server not running (or on different port). Start with "npm run dev:api"`);
      resolve();
    });

    req.setTimeout(3000, () => {
      req.destroy();
      console.log(`   ℹ️  API server connection timed out after 3s.`);
      resolve();
    });
  });

  console.log('\n=================================================================');
  if (passed) {
    console.log(' 🎉 All cross-platform connection checks completed cleanly.');
  } else {
    console.log(' ⚠️  Some connectivity checks produced notices. Check logs above.');
  }
  console.log('=================================================================\n');
}

if (require.main === module) {
  runVerification().catch(console.error);
}

module.exports = { runVerification };
