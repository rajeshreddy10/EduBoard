/// Application-wide constants for EduBoard Mobile Native
class AppConstants {
  static const String appName = 'EduBoard';
  static const String appVersion = '1.0.0+1';
  static const String appTagline = 'Interactive Pedagogical Canvas & Digital Classroom';

  // Local Hive box keys
  static const String settingsBox = 'eduboard_settings_box';
  static const String themeBox = 'eduboard_theme_box';
  static const String whiteboardBox = 'eduboard_whiteboard_box';
  static const String notesBox = 'eduboard_notes_box';
  static const String authBox = 'eduboard_auth_box';

  // Responsive Breakpoints
  static const double mobileMaxWidth = 600.0;
  static const double tabletMaxWidth = 1024.0;

  // Animation Durations
  static const Duration quickAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 350);
  static const Duration relaxedAnimation = Duration(milliseconds: 500);

  // Canvas Constants
  static const double defaultStrokeWidth = 3.5;
  static const double minStrokeWidth = 1.0;
  static const double maxStrokeWidth = 30.0;
  static const double defaultFontSize = 18.0;
}
