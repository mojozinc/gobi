import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/api/api_client.dart';
import '../../data/models/user.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/medication_repository.dart';
import '../services/intent_router_service.dart';

// Local Drift Database Provider
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// Medication Repository Provider
final medicationRepositoryProvider = Provider<MedicationRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return MedicationRepository(db);
});

// Intent Router Service Provider
final intentRouterServiceProvider = Provider<IntentRouterService>((ref) {
  final repo = ref.watch(medicationRepositoryProvider);
  final service = IntentRouterService(repo);
  ref.onDispose(() => service.dispose());
  return service;
});

// Stream of Voice Action Intent Events
final intentEventStreamProvider = StreamProvider<IntentEvent>((ref) {
  final service = ref.watch(intentRouterServiceProvider);
  return service.events;
});

// Reactive Active Medications Stream
final activeMedicationsProvider = StreamProvider<List<MedicationEntry>>((ref) {
  final repo = ref.watch(medicationRepositoryProvider);
  return repo.watchMedications();
});

// Reactive Today's Doses Stream
final todayDosesProvider = StreamProvider<List<DoseLogEntry>>((ref) {
  final repo = ref.watch(medicationRepositoryProvider);
  return repo.watchTodayDoses();
});

// Shared Preferences Provider
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) {
  return null;
});

// API Client Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
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
  return AuthStateNotifier(authRepository);
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

  AuthStateNotifier(this._authRepository)
      : super(AuthState(isAuthenticated: false)) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final isAuth = await _authRepository.isAuthenticated();
    if (isAuth) {
      final user = await _authRepository.getCurrentUser();
      state = state.copyWith(isAuthenticated: true, user: user);
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
      state = state.copyWith(user: updatedUser);
    } catch (e) {
      rethrow;
    }
  }
}
