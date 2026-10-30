# EduBoard Professional Deployment Guide

This document provides the final checklist to move from **Local Development** to **100% Production Ready**.

## 1. Firebase Configuration
- [ ] **Firestore Rules**: Deploy the included `firestore.rules` file via Firebase CLI (`firebase deploy --only firestore:rules`).
- [ ] **Service Account**: For the Backend (`apps/api`), go to Firebase Project Settings > Service Accounts and download a JSON key. Place it in `apps/api/serviceAccountKey.json`.
- [ ] **Authentication**: Ensure Email/Password and Google Login are enabled in the Firebase Console.

## 2. Environment Variables
- [ ] **Frontend (`apps/web/.env`)**: Change `NEXT_PUBLIC_API_URL` to your production domain (e.g., `https://api.eduboard.app/api`).
- [ ] **Backend (`apps/api/.env`)**: Update `ALLOWED_ORIGINS` to include your production frontend URL.

## 3. Real-time Scaling
- [ ] **Redis**: For high-traffic production, install a Redis instance and configure the `src/config/redis.js` to prevent Socket.io desync across multiple servers.

## 4. Hardware Support
- [ ] **HTTPS**: Both Frontend and Backend **MUST** run on HTTPS in production. Web Speech API microphone recognition and Tesseract.js OCR require secure (HTTPS) domains.

## 5. Build Command
```bash
# In the root folder
npm run install:all
npm run build
npm run start
```

## 6. Board Routing / Static Export Strategy (updated)

Board ids are user-created and unbounded, so `/dashboard/boards/[id]` (and its
`activity` / `history` / `share` sub-pages) can never be fully prerendered.

- **Vercel / Node hosts (default)**: builds run in dynamic mode and every board
  deep link is server-rendered on demand.
- **GitHub Pages (CI)**: `GITHUB_ACTIONS=true` triggers `output: 'export'`.
  The `[id]` routes prerender only the canonical `default` page; every REAL
  board deep link is served by the exported `404.html`
  (`apps/web/app/not-found.tsx`), which forwards to the static sibling views
  (`/dashboard/boards/{history|activity|share}/?id=<boardId>`, same board id).
- Firestore composite indexes required by the new rules/queries are declared
  in `firestore.indexes.json`; deploy with
  `firebase deploy --only firestore:rules,firestore:indexes`.
- The backend now enforces owner-scoped access on every whiteboard route
  (list may no longer fall back to other users' boards; `/shared` uses one
  indexed `sharedWith array-contains` query; deletes purge versions in
  chunked batches; version counters allocate inside a transaction;
  `/api/export/download` is authenticated and traversal-proof; socket
  handshakes await the async `verifyToken`).

Your application is now technically and architecturally ready for commercial use.
