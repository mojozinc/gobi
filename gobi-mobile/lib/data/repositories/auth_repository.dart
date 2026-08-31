import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_config.dart';
import '../api/api_client.dart';
import '../models/user.dart';
import 'dart:convert';

class AuthRepository {
  final ApiClient _apiClient;
  final SharedPreferences? _prefs;
  final Map<String, String> _inMemoryStorage = {};

  AuthRepository(this._apiClient, this._prefs);

  Future<LoginResponse> register({
    required String email,
    required String password,
    required String name,
    String? phone,
  }) async {
    final response = await _apiClient.register(
      email: email,
      password: password,
      name: name,
      phone: phone,
    );

    // Save token and user data
    await _saveAuthData(response.token, response.user);

    return response;
  }

  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.login(
      email: email,
      password: password,
    );

    // Save token and user data
    await _saveAuthData(response.token, response.user);

    return response;
  }

  Future<void> logout() async {
    try {
      await _prefs?.remove(AppConfig.tokenKey);
      await _prefs?.remove(AppConfig.userKey);
    } catch (_) {}
    _inMemoryStorage.remove(AppConfig.tokenKey);
    _inMemoryStorage.remove(AppConfig.userKey);
    _apiClient.setAuthToken(null);
  }

  Future<bool> isAuthenticated() async {
    final token = await getToken();
    if (token != null) {
      _apiClient.setAuthToken(token);
      return true;
    }
    return false;
  }

  Future<String?> getToken() async {
    try {
      return _prefs?.getString(AppConfig.tokenKey) ?? _inMemoryStorage[AppConfig.tokenKey];
    } catch (_) {
      return _inMemoryStorage[AppConfig.tokenKey];
    }
  }

  Future<User?> getCurrentUser() async {
    try {
      final userJson = _prefs?.getString(AppConfig.userKey) ?? _inMemoryStorage[AppConfig.userKey];
      if (userJson != null) {
        return User.fromJson(json.decode(userJson));
      }
    } catch (_) {
      final userJson = _inMemoryStorage[AppConfig.userKey];
      if (userJson != null) {
        return User.fromJson(json.decode(userJson));
      }
    }
    return null;
  }

  Future<void> _saveAuthData(String token, User user) async {
    _inMemoryStorage[AppConfig.tokenKey] = token;
    _inMemoryStorage[AppConfig.userKey] = json.encode(user.toJson());
    try {
      await _prefs?.setString(AppConfig.tokenKey, token);
      await _prefs?.setString(AppConfig.userKey, json.encode(user.toJson()));
    } catch (_) {}
    _apiClient.setAuthToken(token);
  }

  Future<User> refreshProfile() async {
    final user = await _apiClient.getProfile();
    final userJson = json.encode(user.toJson());
    _inMemoryStorage[AppConfig.userKey] = userJson;
    try {
      await _prefs?.setString(AppConfig.userKey, userJson);
    } catch (_) {}
    return user;
  }

  Future<User> updateProfile({
    String? name,
    String? phone,
    String? photoUrl,
  }) async {
    final user = await _apiClient.updateProfile(
      name: name,
      phone: phone,
      photoUrl: photoUrl,
    );
    final userJson = json.encode(user.toJson());
    _inMemoryStorage[AppConfig.userKey] = userJson;
    try {
      await _prefs?.setString(AppConfig.userKey, userJson);
    } catch (_) {}
    return user;
  }
}
