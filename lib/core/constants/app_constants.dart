// lib/core/constants/app_constants.dart

class AppConstants {
  AppConstants._();

  // Folder name for saved images
  static const String fingerDataFolder = 'Finger Data';

  // Overlay sizes
  static const double palmOverlayWidthFactor = 0.75;
  static const double palmOverlayHeightFactor = 0.55;
  static const double fingerOvalWidthFactor = 0.55;
  static const double fingerOvalHeightFactor = 0.72;

  // Luminosity thresholds
  static const double lowLightThreshold = 50.0;
  static const double brightLightThreshold = 220.0;

  // Blur detection
  static const double blurThreshold = 100.0; // Laplacian variance below this = blurred

  // Finger count
  static const int totalFingers = 5;

  // Finger names
  static const List<String> fingerNames = [
    'Thumb',
    'Index',
    'Middle',
    'Ring',
    'Little',
  ];

  // Hand sides
  static const String leftHand = 'Left_Hand';
  static const String rightHand = 'Right_Hand';

  // DB
  static const String dbName = 'palm_finger.db';
  static const int dbVersion = 1;

  // Table names
  static const String tableMinutiae = 'minutiae_records';
  static const String tableLuminosity = 'luminosity_records';
  static const String tableSessions = 'sessions';

  // SharedPrefs keys
  static const String keyDeviceId = 'device_id';
  static const String keyCurrentSessionId = 'current_session_id';
}
