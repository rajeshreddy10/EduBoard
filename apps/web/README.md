# EduBoard 🎓✨

> **AI-Powered Smart Teaching Whiteboard, Voice Transcription & Document Annotation Platform**

![Next.js](https://img.shields.io/badge/Next.js_16-000000?style=for-the-badge&logo=next.js&logoColor=white)
![React](https://img.shields.io/badge/React_19-61DAFB?style=for-the-badge&logo=react&logoColor=black)
![Tailwind CSS](https://img.shields.io/badge/Tailwind_CSS_4-06B6D4?style=for-the-badge&logo=tailwind-css&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=node.js&logoColor=white)
![Express](https://img.shields.io/badge/Express.js-000000?style=for-the-badge&logo=express&logoColor=white)
![Socket.IO](https://img.shields.io/badge/Socket.IO-010101?style=for-the-badge&logo=socket.io&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?style=for-the-badge&logo=typescript&logoColor=white)

---

## 🌟 Overview

**EduBoard** is an intelligent digital whiteboard and teaching platform built for educators, students, and collaborative teams. It combines interactive canvas drawing, live AI speech-to-text lecture transcription, full document annotation (PDF & Word), step-by-step math derivations, and real-time collaboration into a unified workspace.

The platform runs as a responsive Next.js 16 web application and supports cross-platform packaging with Electron for desktop environments.

---

## 🎯 Implemented Features

### 1. 🖊️ DrawSpace Whiteboard (`/normal-board`)
- **Full Drawing Toolkit**: Freehand pen, smart eraser, color palettes (Ink, Ruby, Amber, Emerald, Azure, Violet), and adjustable stroke widths.
- **Text Element Overlays**: Place and edit custom text anywhere on the canvas with draggable positioning.
- **Vanishing Laser Pointer**: Temporary laser trace that automatically fades for highlighting key lecture areas.
- **Focus Spotlight Overlay**: Dim canvas background while keeping a spotlight circle on specific content.
- **30/70 Reference Drawer**: Split-screen drawer allowing teachers to view notes and lesson materials side-by-side with the active board.
- **Progressive Reveal Steps Bar**: Organize and reveal lesson steps sequentially with step groups and completion status.
- **Teacher Notes Overlay**: Private lesson notes drawer attached to canvas states.
- **Document Import**: Load PDF and DOCX files directly into canvas for background projection and markup.
- **Session Export**: Save and export boards to high-resolution PDF documents, PNG images, SVG vectors, and JSON state files.

### 2. 🎤 Voice Board AI (`/voice-control`)
- **Live Speech Transcription**: Speech-to-text capture powered by the Web Speech API and local STT fallback engine.
- **Sentence Deduplication**: Real-time algorithmic deduplication preventing repeated phrases during continuous dictation.
- **Scientific Formula Placement**: Automatically recognizes math/science keywords and places rendered formulas onto the board.
- **Voice Commands**: Hands-free control commands (e.g., "clear board", "undo", "save", "change color").
- **Canvas Text Integration**: Converts recognized speech into draggable text cards on the canvas.

### 3. 📄 DocCanvas Annotator (`/gesture-board`)
- **Document Studio**: Dedicated PDF and Word (.docx) document viewer and annotation environment.
- **Markup Tools**: Dual-mode pen and highlighter overlays with color swatches.
- **Focus Magnifier**: Zoom in on detailed diagrams, charts, or fine text passages.
- **AI Math Derivation Solver**: Modal that parses mathematical expressions and generates step-by-step derivations, explanations, and practice questions.
- **Vector Replay Player**: Replay strokes and drawing sequences step-by-step.
- **Document Export**: Download annotated documents with overlays applied.

### 4. 📊 Dashboard & Saved History (`/dashboard`, `/dashboard/boards`)
- **Studio Dashboard**: Quick access launchers, recent session metrics, and history records.
- **Board Management**: Browse, search, filter, rename, and delete saved workspaces.
- **Board Activity & Snapshots**: View audit trails of edits and restore previous versions.
- **Collaborator Sharing**: Share board sessions by email with configurable Viewer and Editor permissions.

### 5. 👤 Profile & Account Security (`/profile`, `/profile/security`)
- **Profile Customization**: Manage user details, institution, bio, teaching philosophy, and avatar.
- **Security Hub**: Firebase-authenticated password updates, active session records, and account controls.

### 6. ⚙️ System Settings & Themes (`/settings`, `/dashboard/settings/theme`)
- **Theme Studio**: Seamless toggle between Dark Mode and Light Mode with HSL theme tokens.
- **Preferences**: Display language, regional country selection, and time zone customization.
- **Notification Toggles**: Device push, email notifications, and collaboration update toggles.

### 7. 🔔 Notifications Hub (`/notifications`)
- Real-time notification feed backed by Firebase Firestore with offline fallback.
- Filter by unread, mark individual or all as read, and delete alerts.

### 8. ❓ Help & Guide Center (`/help`, `/help/faq`, `/help/tutorials`)
- Comprehensive FAQ search covering DrawSpace, Voice Board, DocCanvas, Collaboration, and Settings.
- Step-by-step video tutorial guides for each active module.

---

## 🏗️ Architecture

```text
EduBoard_Web/
├── apps/
│   ├── web/                      # Next.js 16 + React 19 Frontend
│   │   ├── app/                  # App Router Pages & Layouts
│   │   ├── components/           # UI, Board, and Layout components
│   │   ├── features/             # Studio page implementations
│   │   ├── lib/                  # AuthContext, BoardContext, API client, Socket client
│   │   └── types/                # Core TypeScript definitions
│   └── api/                      # Express.js Backend Server
├── src/                          # Backend business logic & routes
│   ├── config/                   # Firebase Admin & Redis configurations
│   ├── controllers/              # Request handlers
│   ├── middleware/               # Auth, rate limiting & error handling
│   ├── routes/                   # API routes (auth, whiteboards, ai, voice, collaboration)
│   ├── services/                 # AI pipelines, STT, export services
│   └── socket/                   # Socket.IO real-time collaboration engine
```

---

## 🚀 Quick Start

### 1. Install Dependencies
```bash
npm run install:all
```

### 2. Configure Environment
Copy `.env.example` to `.env` in `apps/web` and `apps/api`.

### 3. Start Development Servers
```bash
# Starts both Backend API (port 3001) and Frontend (port 3000)
npm run dev
```

### 4. Build for Production
```bash
npm run build:web
```

---

## 🧪 Testing

```bash
# Run unit tests
npm test --prefix apps/web
```
