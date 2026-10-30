# EduBoard Manual Acceptance Test Matrix

This matrix complements the automated Selenium, Appium, Locust, and DAST test suites with hardware and sensory validation protocols.

## Hardware Validation Protocols

| TC ID | Module | Scenario | Device / Environment | Pass Criteria |
| :--- | :--- | :--- | :--- | :--- |
| **TC-MAN-001** | DrawSpace Canvas | Stylus Pressure Dynamics | Samsung Galaxy Tab S9 (S-Pen) | Line width thickens smoothly under varying tip pressure |
| **TC-MAN-002** | DrawSpace Canvas | Palm Rejection Sensitivity | iPad / Android 12" Tablet | Resting palm on canvas does not generate spurious strokes |
| **TC-MAN-003** | DocCanvas Studio | Multi-page PDF Pan & Zoom | 100+ Page Lecture PDF | Smooth 60 FPS viewport zooming and paging without OOM |
| **TC-MAN-004** | Voice Board | Microphone Hardware Handshake | External USB Condenser Mic | Speech recognition starts immediately without echo |
| **TC-MAN-005** | Offline Sync | Network Drop & Reconnect | Airplane Mode Toggle | Local board changes queued and synced upon WiFi reconnect |
| **TC-MAN-006** | Hardware Keyboard | Alt+V Voice Toggle Shortcut | Physical Desktop / Bluetooth Keyboard | Toggling Alt+V starts/stops transcription cleanly |
| **TC-MAN-007** | Display Adaptation | Foldable & Dual Screen Reflow | Galaxy Z Fold 5 / Pixel Fold | Canvas reflows seamlessly across fold hinge angle changes |
