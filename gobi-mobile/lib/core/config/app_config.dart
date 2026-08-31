class AppConfig {
  // API Configuration
  // Can be configured via --dart-define=API_BASE_URL=http://... or defaults to 127.0.0.1:8000
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
  static const String apiVersion = String.fromEnvironment(
    'API_VERSION',
    defaultValue: '/api/v1',
  );
  static const String apiBaseUrl = '$baseUrl$apiVersion';

  // App Information
  static const String appName = 'Gobi';
  static const String appVersion = '1.0.0';

  // Token Storage Key
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';

  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
