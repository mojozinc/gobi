import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/api/api_client.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/medications_repository.dart';
import '../../data/models/user.dart';
import '../services/api_service.dart';

// Shared Preferences Provider
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) {
  return null;
});

// App SQLite Database Provider
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// API Client Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

// New FastAPI Service Provider
final apiServiceProvider = Provider<ApiService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ApiService(prefs: prefs);
});

// Medications Repository Provider (Local First + Cloud Sync)
final medicationsRepositoryProvider = Provider<MedicationsRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final apiService = ref.watch(apiServiceProvider);
  return MedicationsRepository(db, apiService);
});

// Stream of Active Medications from Local Database
final medicationsListStreamProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String?>((ref, dependentId) {
  final repo = ref.watch(medicationsRepositoryProvider);
  return repo.watchMedications(dependentId: dependentId);
});

// Stream of Today's Doses from Local Database
final todayDosesStreamProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String?>((ref, dependentId) {
  final repo = ref.watch(medicationsRepositoryProvider);
  return repo.watchTodayDoses(dependentId: dependentId);
});

// Cloud Sync Status Provider
final syncStatusProvider = StateProvider<SyncStatus>((ref) {
  return SyncStatus.idle;
});

// Auth Repository Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return AuthRepository(apiClient, prefs);
});

// Auth State Provider
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final apiService = ref.watch(apiServiceProvider);
  return AuthStateNotifier(authRepository, apiService);
});

// Theme Mode Provider
final themeModeProvider = StateProvider<bool>((ref) {
  return false; // false = light mode, true = dark mode
});


// Auth State
class AuthState {
  final bool isAuthenticated;
  final User? user;
  final bool isLoading;
  final String? error;

  AuthState({
    required this.isAuthenticated,
    this.user,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    User? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Auth State Notifier
class AuthStateNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final ApiService _apiService;

  AuthStateNotifier(this._authRepository, this._apiService)
      : super(AuthState(isAuthenticated: false)) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final isAuth = await _authRepository.isAuthenticated();
    if (isAuth) {
      final user = await _authRepository.getCurrentUser();
      final token = await _authRepository.getToken();
      if (token != null) {
        _apiService.setToken(token);
      }
      if (user != null) {
        _apiService.setUser(user.toJson());
      }
      state = state.copyWith(isAuthenticated: true, user: user);
    } else if (_apiService.isAuthenticated) {
      final userMap = _apiService.currentUser;
      User? user;
      if (userMap != null) {
        try {
          user = User.fromJson(userMap);
        } catch (_) {}
      }
      state = state.copyWith(isAuthenticated: true, user: user);
    }
  }

  Future<void> loginAnonymously({String? deviceId, String? name}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _apiService.loginAnonymously(deviceId: deviceId, name: name);
      final userMap = res['user'] as Map<String, dynamic>?;
      User? user;
      if (userMap != null) {
        try {
          user = User.fromJson(userMap);
        } catch (_) {}
      }
      state = AuthState(
        isAuthenticated: true,
        user: user,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
    String? phone,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _authRepository.register(
        email: email,
        password: password,
        name: name,
        phone: phone,
      );
      _apiService.setToken(response.token);
      _apiService.setUser(response.user.toJson());
      state = AuthState(
        isAuthenticated: true,
        user: response.user,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _authRepository.login(
        email: email,
        password: password,
      );
      _apiService.setToken(response.token);
      _apiService.setUser(response.user.toJson());
      state = AuthState(
        isAuthenticated: true,
        user: response.user,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    _apiService.clearAuth();
    state = AuthState(isAuthenticated: false);
  }

  Future<void> updateProfile({
    String? name,
    String? phone,
    String? photoUrl,
  }) async {
    try {
      final updatedUser = await _authRepository.updateProfile(
        name: name,
        phone: phone,
        photoUrl: photoUrl,
      );
      _apiService.setUser(updatedUser.toJson());
      state = state.copyWith(user: updatedUser);
    } catch (e) {
      rethrow;
    }
  }
}
