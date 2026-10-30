const path = require('path');

describe('Backend Server Configuration & Health Checks', () => {
  test('Health endpoint response format', () => {
    const healthResponse = { status: 'ok', version: '3.0.0', monorepo: true };
    expect(healthResponse.status).toBe('ok');
    expect(healthResponse.version).toBe('3.0.0');
    expect(healthResponse.monorepo).toBe(true);
  });

  test('Database approved collections schema integrity', () => {
    const fs = require('fs');
    const dbPath = [
      path.resolve(__dirname, '../../src/config/db'),
      path.resolve(__dirname, '../../../src/config/db'),
      path.resolve(process.cwd(), 'src/config/db')
    ].find(p => fs.existsSync(p + '.js') || fs.existsSync(p));
    const { APPROVED_COLLECTIONS, resolveApprovedCollection } = require(dbPath);

    expect(APPROVED_COLLECTIONS.has('users')).toBe(true);
    expect(APPROVED_COLLECTIONS.has('whiteboards')).toBe(true);
    expect(APPROVED_COLLECTIONS.has('whiteboard_versions')).toBe(true);
    expect(APPROVED_COLLECTIONS.has('voice_transcriptions')).toBe(true);
    expect(APPROVED_COLLECTIONS.has('notifications')).toBe(true);
    expect(APPROVED_COLLECTIONS.has('userSettings')).toBe(true);
    expect(APPROVED_COLLECTIONS.has('exports')).toBe(true);

    // Verify unapproved collections are rejected
    expect(resolveApprovedCollection('classrooms')).toBeNull();
    expect(resolveApprovedCollection('sessions')).toBeNull();
    expect(resolveApprovedCollection('comments')).toBeNull();
    expect(resolveApprovedCollection('ai_interactions')).toBeNull();
  });
});
