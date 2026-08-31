class AppConfig {
  // API Configuration
  // Using 127.0.0.1:8000 via adb reverse tcp:8000 tcp:8000 for reliable, zero-latency connection
  static const String baseUrl = 'http://127.0.0.1:8000';
  static const String apiVersion = '/api/v1';
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
