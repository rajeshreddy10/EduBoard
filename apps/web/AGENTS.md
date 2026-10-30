# EduBoard — Project Guide & Architecture

## Monorepo Architecture
```
EduBoard_Web/
├── apps/
│   ├── web/                     # Next.js 16 Web Application (Port 3000)
│   │   ├── app/                 # App Router (pages: dashboard, studios, profile, settings, help)
│   │   ├── components/          # Reusable UI, layout, and studio overlays
│   │   ├── features/gesture/    # DocCanvas Document Studio
│   │   ├── lib/                 # Firebase, API client, Socket.io, store, and services
│   │   ├── public/              # Static assets, PWA manifest, service worker
│   │   └── tests/               # Jest unit/integration tests and Cypress E2E
│   └── api/                     # Express.js REST API Server (Port 3001)
│       └── index.js             # API entrypoint, CORS, security middleware, route mounts
├── src/                         # Backend Services & Logic
│   ├── config/                  # Firebase Admin SDK & Redis adapters
│   ├── controllers/             # Business logic controllers (AI, auth, etc.)
│   ├── routes/                  # Express API route modules (auth, whiteboards, export, voice, ai, analytics)
│   ├── services/                # Voice, Export (PDF, PNG, SVG, JSON), and AI services
│   └── socket/                  # Real-time board collaboration (Socket.io)
├── DEPLOYMENT.md                # Production deployment guide
└── README.md                    # Project overview & quickstart
```

## Genuine Implemented Studios & Features
- **DrawSpace Canvas (`/normal-board`)**: Full digital whiteboard with freehand drawing, stroke widths, color swatches, text overlays, vanishing laser, spotlight, 30/70 reference drawer, progressive reveal steps, teacher notes drawer, and multi-format export.
- **Voice Board AI (`/voice-control`)**: Live speech-to-text transcription powered by Web Speech API with sentence deduplication, scientific formula notation parser, and voice commands.
- **DocCanvas Studio (`/gesture-board`, `/dashboard/tools/gesture`)**: Document and PDF annotation studio with focus magnifier, vanishing laser pointer, AI Math Solver modal, vector replay scrubber, and high-resolution export.
- **Session Export**: 4 verified, production-grade export formats:
  - **PDF Document**
  - **PNG Image**
  - **SVG Vector**
  - **JSON Canvas Data**
- **Database & Authentication**: Firebase Firestore for cloud persistence and Firebase Authentication for user sessions, profile management, and security.
- **Real-Time Collaboration**: Socket.io-based multi-user board state sync, live cursors, remote laser pointer trails, and chat.

## Running Locally
```bash
# Install dependencies
npm run install:all

# Development Mode (Runs Frontend :3000 + Backend :3001 concurrently)
npm run dev

# Testing
npm test --prefix apps/web

# Production Build
npm run build --prefix apps/web
```

## API Endpoints
- `POST /api/auth/register|login|refresh|logout`
- `GET|POST /api/whiteboards`, `GET|PUT|DELETE /api/whiteboards/:id`
- `POST /api/whiteboards/:id/shapes`, `PUT|DELETE /api/whiteboards/:id/shapes/:shapeId`
- `POST /api/whiteboards/:id/share`
- `POST /api/ai/solve|explain|handwriting`
- `POST /api/collaboration/rooms|join`, `GET /api/collaboration/room/:id/participants`
- `GET /api/exports/formats` (returns PDF, PNG, SVG, JSON)
- `POST|GET|DELETE /api/exports`
- `POST /api/voice/command|transcribe`
- `GET /api/analytics/overview|boards|ai|export|collaboration`
- `GET /api/health`
- `WebSocket /socket.io` for real-time whiteboard collaboration
