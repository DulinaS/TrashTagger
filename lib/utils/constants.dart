class AppConstants {
  // App Info
  static const String appName = 'TrashTagger';
  static const String appVersion = '1.0.0';

  // API Endpoints (for your Cloud Functions)
  static const String baseUrl =
      'https://us-central1-trashtagger-app.cloudfunctions.net';

  // Image Constants
  static const double maxImageSizeMB = 10.0;
  static const int imageQuality = 80;

  // Location Constants
  static const double defaultRadius = 5.0; // km
  static const double maxRadius = 50.0; // km
  static const double minRadius = 1.0; // km

  // Points System
  static const Map<String, int> basePoints = {
    'report_low': 10,
    'report_medium': 15,
    'report_high': 25,
    'cleanup_low': 20,
    'cleanup_medium': 30,
    'cleanup_high': 50,
  };

  // Trash Types
  static const List<String> trashTypes = [
    'general',
    'recyclable',
    'hazardous',
    'large',
    'organic',
  ];

  // Severity Levels
  static const List<String> severityLevels = ['low', 'medium', 'high'];

  // Status Types
  static const List<String> reportStatuses = [
    'pending',
    'verified',
    'rejected',
    'cleaning',
    'completed',
  ];
}
