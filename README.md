# EduBoard: Cross-Platform Educational Whiteboard & Document Studio

[![EduBoard CI/CD Pipeline](https://github.com/rajeshreddy10/EduBoard/actions/workflows/deploy.yml/badge.svg)](https://github.com/rajeshreddy10/EduBoard/actions/workflows/deploy.yml)
[![Deployment: GitHub Pages](https://img.shields.io/badge/Deployment-GitHub%20Pages-blue?logo=github)](https://rajeshreddy10.github.io/EduBoard/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Tests: 1,410 Passed](https://img.shields.io/badge/Automated%20Tests-1%2C410%20PASS-brightgreen.svg)](tests/)

---

## Overview

**EduBoard** is a modern, enterprise-grade educational collaboration platform designed to eliminate friction in digital classrooms, lecture halls, and hybrid teaching environments. By unifying an advanced freehand drawing engine, multi-format document annotation studio, and real-time speech-to-text transcription board into a single, cohesive ecosystem across **Web (Next.js)** and **Mobile (Flutter Android)**, EduBoard provides educators and students with an intuitive, lag-free teaching workspace.

EduBoard bridges the gap between traditional tactile blackboards and modern digital pedagogy—featuring stylus pressure sensitivity, progressive lesson reveals, teacher teleprompter notes, and cross-platform state synchronization without intrusive auto-save disruption.

---

## Key Features

### 1. DrawSpace Canvas (`/normal-board`)
* **Vector Drawing Engine**: Freehand pen, smart eraser, and geometric shape tools (Lines, Rectangles, Circles, Arrows, Triangles) powered by high-frequency vector interpolation.
* **Stylus & Pressure Sensitivity**: Full hardware support for digitizers and active pens (e.g., S-Pen, Apple Pencil, Wacom), adjusting stroke width dynamically with tip pressure.
* **Curated Pedagogical Palette**: High-contrast, colorblind-friendly colors (Ink, Ruby, Amber, Emerald, Azure, Violet) alongside custom RGBA color selection.
* **Progressive Step Reveal**: Lesson stage manager allowing teachers to group complex equations or diagrams into sequential reveal steps, eliminating student cognitive overload.
* **Reference Drawer (70/30 Split)**: Side-by-side dockable drawer allowing educators to inspect lesson notes, textbooks, and diagrams while simultaneously drawing on the main canvas.
* **Teacher Teleprompter**: Private, student-hidden notes overlay pinned to active board coordinates.

### 2. DocCanvas Studio (`/gesture-board`)
* **Universal Document Compatibility**: Native parsing and rendering for PDF, DOCX, PPTX, TXT, and high-resolution images.
* **Direct Page Surface Annotation**: Highlight, annotate, and stamp notes directly on rendered document pages with smooth page scrolling and jumping.
* **Multi-Format Export**: Export annotated coursework to searchable PDF, SVG, PNG, or JSON session formats.
* **Optimized Mobile Experience**: Streamlined for Android tablets and phones with unnecessary math/replay bloat removed for maximum annotation responsiveness.

### 3. Voice Board (`/voice-control`)
* **Real-Time Speech-to-Text**: Low-latency transcription engine converting spoken lectures into structured whiteboard text live on screen.
* **Clean Distraction-Free Canvas**: Completely solid, wallpaper-free background ensuring maximum legibility for transcribed notes.
* **Anti-Duplication Filter**: Intelligent stream-deduplication ensuring no repeated sentences, hallucinated filler words, or recognition echoes.
* **Synchronous Multi-Modal Teaching**: Write or draw on the whiteboard while speaking simultaneously.

### 4. Cross-Platform Architecture & Manual Save Guarantee
* **Zero Accidental Saves**: Autosave removed across all board modules—boards persist strictly when the educator presses the **Save** button.
* **Exact State Reopening**: Saved board IDs, timestamps, and exact vector strokes load identically across both Web and Android.

---

## Screenshots & Interface Showcase

| Desktop DrawSpace Whiteboard | Desktop Collaborative Classroom |
|:---:|:---:|
| ![DrawSpace Whiteboard](apps/web/public/screenshots/desktop-board.png) | ![Collaborative Classroom](apps/web/public/screenshots/desktop-classroom.png) |

| Mobile Whiteboard Studio | Mobile Lecture & Document View |
|:---:|:---:|
| ![Mobile Whiteboard](apps/web/public/screenshots/mobile-board.png) | ![Mobile Lecture View](apps/web/public/screenshots/mobile-lecture.png) |

---

## Tech Stack

### Frontend (Web Application)
* **Framework:** Next.js 16.2.4 (App Router, React 19)
* **Language:** TypeScript 5.7
* **Styling:** Tailwind CSS v4 & Lucide Icons
* **Rendering:** HTML5 Canvas, SVG Vector Engine, Web Workers

### Frontend (Mobile Application)
* **Framework:** Flutter 3.24.x (Dart 3.5)
* **Target Platforms:** Android (Phones, Foldables, Tablets)
* **Architecture:** Clean Architecture with Riverpod v3 State Management
* **Styling:** Material 3 Adaptive Design with Light & Dark Theme Support

### Backend & Microservices
* **Runtime:** Node.js (v20 LTS), Express.js REST API
* **Real-Time Collaboration:** Socket.IO WebSocket Engine
* **Microservices:** Voice Processing Service, Export Engine, AI Teleprompter Assistant

### Database & Cloud Infrastructure
* **Cloud Database:** Google Cloud Firestore (NoSQL, Realtime Document Streams)
* **Cloud Storage:** Firebase Storage (Secure asset and annotated document storage)
* **Security Rules:** Granular Security Rules for Firestore and Storage

### Authentication
* **Provider:** Firebase Authentication (Secure Email & Password authentication across Web and Mobile)

### Hosting & Deployment
* **Web Hosting:** GitHub Pages (Automated static export via GitHub Actions)
* **Mobile Distribution:** Android APK & Android App Bundle (AAB)

### State Management
* **Web:** React Context API + Local Storage fallback
* **Mobile:** Flutter Riverpod (StateNotifier, AsyncNotifier with auto-dispose)

### Development Tools
* **Language Toolchains:** TypeScript, Dart, Python 3.11/3.13
* **Test Runners:** Pytest, Selenium WebDriver, Appium 2.x (UiAutomator2), Locust, OWASP ZAP

---

## Setup Instructions

### Prerequisites
* **Node.js**: v20.x or higher
* **npm**: v10.x or higher
* **Flutter SDK**: v3.24.x or higher
* **Android Studio**: Android SDK Platform 34, JDK 17
* **Python**: v3.11+ with `pip`

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/rajeshreddy10/EduBoard.git
   cd EduBoard_PDD
   ```

2. **Install Web & Root Monorepo Dependencies:**
   ```bash
   npm install
   ```

3. **Install Mobile Dependencies:**
   ```bash
   cd apps/mobile/flutter
   flutter pub get
   cd ../../..
   ```

4. **Install Python Quality & Test Dependencies:**
   ```bash
   pip install -r tests/selenium/requirements.txt
   pip install -r tests/load/requirements.txt
   ```

### Environment Variables

Copy `.env.example` to `.env` in both the root and `apps/web/`:
```bash
cp .env.example .env
cp apps/web/.env.example apps/web/.env.local
```

Configure your Firebase client credentials:
```ini
NEXT_PUBLIC_FIREBASE_API_KEY=your-api-key
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=your-app.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=your-project-id
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=your-app.firebasestorage.app
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=your-sender-id
NEXT_PUBLIC_FIREBASE_APP_ID=your-app-id
```

### Local Development

* **Start the Web Application:**
  ```bash
  npm run dev
  # Open http://localhost:3000 in your browser
  ```

* **Start the Flutter Mobile App:**
  ```bash
  cd apps/mobile/flutter
  flutter run
  ```

* **Start the Node.js API Backend:**
  ```bash
  npm run start:api
  ```

### Build Instructions

* **Build Web for Production (Static Export):**
  ```bash
  npm run build:web
  # Static HTML output generated in apps/web/out/
  ```

* **Build Android Mobile Debug APK:**
  ```bash
  cd apps/mobile/flutter
  flutter build apk --debug
  ```

### Production Deployment

The web application automatically builds and deploys to **GitHub Pages** whenever changes are pushed to `main` via the GitHub Actions CI/CD pipeline (`.github/workflows/deploy.yml`).

---

## Design Principles

* **Scalable Architecture:** Clean separation of concerns between presentation layers, business logic controllers, and cloud data repositories.
* **Modular Design:** Reusable component library (`BoardHeader`, `NavigationDrawer`, `DocCanvas`, `InteractiveCanvas`).
* **Maintainability:** Strongly-typed contracts across TypeScript interfaces and Dart immutable models.
* **Reusability:** Cross-platform payload schema ensuring web canvas strokes deserialize seamlessly into mobile painter paths.
* **Responsive UI:** Adaptive layout supporting viewports from 360px phones to 4K ultra-wide interactive classroom displays.
* **Security Best Practices:** Content Security Policy (CSP), strict input sanitization, zero hardcoded secrets, and OWASP Top 10 compliance verified via automated DAST.
* **Performance Optimization:** 60 FPS requestAnimationFrame canvas rendering, sub-100ms vector simplification, and static pre-rendering.
* **Clean Code Practices:** Zero linter warnings (`flutter analyze`, ESLint) and strict adherence to Material 3 guidelines.

---

## Project Structure

```text
EduBoard_PDD/
├── .github/
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md
│   │   └── feature_request.md
│   ├── workflows/
│   │   └── deploy.yml              # Unified Parallel CI/CD & Deploy Pipeline
│   └── pull_request_template.md
├── apps/
│   ├── api/                        # Express API & Microservices
│   ├── mobile/
│   │   └── flutter/                # Production Flutter Android Application
│   │       ├── android/            # Native Gradle & Android Manifest
│   │       ├── lib/
│   │       │   ├── core/           # Routing, Theme, Constants
│   │       │   ├── features/       # DrawSpace, DocCanvas, Voice, Dashboard
│   │       │   ├── models/         # Whiteboard, Stroke, User Data Models
│   │       │   └── repositories/   # Cloud Firestore & Storage Adapters
│   │       └── pubspec.yaml
│   └── web/                        # Production Next.js 16 Web Application
│       ├── app/                    # Next.js App Router Pages
│       ├── components/             # Reusable UI & Board Widgets
│       ├── features/               # DocCanvas, Gesture, DrawSpace Engines
│       └── lib/                    # Firebase Auth & Realtime Context
├── test-cases/                     # Pre-Populated Excel Test Registries (350+ Each)
│   ├── appium_test_cases.xlsx      # 355 Mobile Test Cases
│   ├── dast_test_cases.xlsx        # 350 Security Audit Cases
│   ├── load_test_cases.xlsx        # 350 Performance SLA Cases
│   └── selenium_test_cases.xlsx    # 355 Web E2E Test Cases
├── tests/                          # Automated Quality Assurance Frameworks
│   ├── appium/                     # Mobile Test Suite & UiAutomator2 POM
│   ├── dast/                       # OWASP ZAP & Security Scanner
│   ├── load/                       # Locust Concurrency & Load Plans
│   ├── reports/                    # Multi-Suite Excel Bundlers
│   ├── selenium/                   # Web E2E Test Suite & Chrome Headless POM
│   ├── unit/                       # Core Algorithm Unit Tests
│   ├── integration/                # Cross-Platform Integration Tests
│   └── manual-test-cases/          # Hardware Stylus & Tablet Matrix
├── CHANGELOG.md
├── CODE_OF_CONDUCT.md
├── CONTRIBUTING.md
├── LICENSE
├── package.json
├── README.md
└── SECURITY.md
```

---

## Testing

EduBoard maintains an exhaustive automated testing pyramid comprising **1,410 unique test cases** across four parallel dimensions:

```text
                           ┌─────────────────────────┐
                           │      PUSH TO MAIN       │
                           └────────────┬────────────┘
                                        │
             ┌──────────────────────────┼──────────────────────────┐
             │                          │                          │
             ▼                          ▼                          ▼
      ┌──────────────┐           ┌──────────────┐           ┌──────────────┐
      │   SELENIUM   │           │    APPIUM    │           │ LOAD TESTING │
      │  WEB TESTING │           │  MOBILE TEST │           │   WEB ONLY   │
      │  (355 Cases) │           │  (355 Cases) │           │  (350 Cases) │
      └──────┬───────┘           └──────┬───────┘           └──────┬───────┘
             │                          │                          │
             └──────────────────────────┼──────────────────────────┘
                                        │
                                  ┌─────▼─────┐
                                  │    DAST   │
                                  │  SECURITY │
                                  │(350 Checks)
                                  └─────┬─────┘
                                        │
                               ALL FOUR TESTS PASS
                                        │
                                        ▼
                             ┌─────────────────────┐
                             │    BUNDLE REPORTS   │
                             │(FINAL_SUMMARY.xlsx) │
                             └──────────┬──────────┘
                                        │
                                        ▼
                             ┌─────────────────────┐
                             │ DEPLOY TO GH PAGES  │
                             │ (apps/web/out -> SPA│
                             └─────────────────────┘
```

### 1. Selenium Web Testing (355 Cases)
* Headless Chrome automated tests covering authentication, forms, drawing canvas, document tools, responsive viewports (Desktop, Tablet, Mobile), and static route deployability.
* Execution: `pytest tests/selenium/test_selenium.py`

### 2. Appium Mobile Testing (355 Cases)
* Mobile UI automation targeting Android devices and tablets, validating multi-touch gestures, stylus pressure, screen rotation, memory leaks, and offline resilience.
* Execution: `pytest tests/appium/test_appium.py`

### 3. Load & Performance Testing (350 Scenarios)
* Concurrency testing simulating Student, Teacher, and Administrator traffic profiles up to 500 concurrent virtual users with strict p95 latency thresholds (< 3000ms).
* Execution: `pytest tests/load/test_load.py` & `locust -f tests/load/locustfile.py`

### 4. DAST Security Auditing (350 Checks)
* Dynamic application security testing evaluating SQLi, NoSQL injection, reflected/stored XSS, clickjacking, CSP headers, HSTS, and IDOR access control.
* Execution: `pytest tests/dast/test_dast.py`

### Unified Test Reports
Reports are consolidated into `final_reports/FINAL_TEST_SUMMARY.xlsx` and `FINAL_TEST_SUMMARY.html` with a **100.0% Pass Rate**.

---

## Deployment

### GitHub Pages Setup
* The Next.js web application is configured for static export (`output: 'export'`) with asset path resolution via `next.config.ts`.
* Client-side routing is preserved across browser refreshes using `apps/web/app/not-found.tsx` generating `404.html` SPA fallbacks.

### Live Production URL
* **GitHub Pages:** [https://rajeshreddy10.github.io/EduBoard/](https://rajeshreddy10.github.io/EduBoard/)

---

## Future Enhancements
* Real-time WebRTC collaborative video mesh alongside the interactive canvas.
* Offline Bluetooth peer-to-peer classroom sync for environments without active internet.
* AI-assisted handwriting equation conversion into LaTeX math objects.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
