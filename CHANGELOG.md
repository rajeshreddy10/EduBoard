# Changelog

All notable changes to the EduBoard Web & Mobile system will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.2.0] - 2026-10-30

### Added
- **Unified CI/CD Quality Pipeline (`.github/workflows/deploy.yml`)**:
  - Parallel automated testing: Selenium Web (355 tests), Appium Mobile (355 tests), Load/Locust (350 tests), DAST Security (350 tests).
  - Consolidated report bundler creating `FINAL_TEST_SUMMARY.xlsx` and `FINAL_TEST_SUMMARY.html`.
  - Automatic production static deployment to GitHub Pages.
- **DrawSpace Canvas (/normal-board)**:
  - Multi-tool drawing engine (Pen, Eraser, Line, Rect, Circle, Arrow, Triangle).
  - Hexagonal color palette (Ink, Ruby, Amber, Emerald, Azure, Violet).
  - Progressive step reveal and reference drawer side-by-side reflow.
  - Manual-only save confirmation state.
- **DocCanvas Studio (/gesture-board)**:
  - Universal multi-format document picker (PDF, DOCX, PPTX, TXT, images).
  - Direct PDF page rendering and stroke overlay.
  - Removed deprecated vector replay and math solver tools per mobile specs.
- **Voice Board (/voice-control)**:
  - Real-time speech-to-text whiteboard stream.
  - Clean solid canvas background without decorative wallpaper.
  - Duplicate transcription suppression and manual save.
- **Cross-Platform State Consistency**:
  - Unified Firebase schema across Web (Next.js) and Mobile (Flutter).
  - Optimistic settings and profile saving.

### Fixed
- Fixed `FilePicker` API invocation in Flutter mobile `doccanvas_screen.dart`.
- Fixed type mismatch in `whiteboard_repository.dart`.
- Removed Google sign-in from mobile authentication per production requirements.
- Resolved deep-link 404 routing with client-side SPA fallback for static GitHub Pages hosting.

