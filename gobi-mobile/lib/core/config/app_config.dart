class AppConfig {
  // API Configuration
  // Note: For physical device on same Wi-Fi, use your machine's LAN IP (192.168.0.109)
  static const String baseUrl = 'http://192.168.0.109:8000';
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
