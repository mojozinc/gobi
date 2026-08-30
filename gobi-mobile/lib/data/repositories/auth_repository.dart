import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_config.dart';
import '../api/api_client.dart';
import '../models/user.dart';
import 'dart:convert';

class AuthRepository {
  final ApiClient _apiClient;
  final SharedPreferences _prefs;

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
    await _prefs.remove(AppConfig.tokenKey);
    await _prefs.remove(AppConfig.userKey);
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
    return _prefs.getString(AppConfig.tokenKey);
  }

  Future<User?> getCurrentUser() async {
    final userJson = _prefs.getString(AppConfig.userKey);
    if (userJson != null) {
      return User.fromJson(json.decode(userJson));
    }
    return null;
  }

  Future<void> _saveAuthData(String token, User user) async {
    await _prefs.setString(AppConfig.tokenKey, token);
    await _prefs.setString(AppConfig.userKey, json.encode(user.toJson()));
    _apiClient.setAuthToken(token);
  }

  Future<User> refreshProfile() async {
    final user = await _apiClient.getProfile();
    await _prefs.setString(AppConfig.userKey, json.encode(user.toJson()));
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
    await _prefs.setString(AppConfig.userKey, json.encode(user.toJson()));
    return user;
  }
}
