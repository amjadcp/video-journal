import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_journal/core/storage/database.dart';
import 'package:video_journal/features/auth/data/auth_repository_impl.dart';
import 'package:video_journal/features/auth/domain/auth_repository.dart';
import 'package:video_journal/features/journal/data/journal_repository_impl.dart';
import 'package:video_journal/features/journal/domain/journal_repository.dart';
import 'package:video_journal/features/settings/data/settings_repository_impl.dart';
import 'package:video_journal/features/settings/domain/settings_repository.dart';

// Database Provider
final journalDatabaseProvider = Provider<JournalDatabase>((ref) {
  final db = JournalDatabase();
  ref.onDispose(() {
    db.close();
  });
  return db;
});

// Repository Provider
final journalRepositoryProvider = Provider<JournalRepository>((ref) {
  final db = ref.watch(journalDatabaseProvider);
  return JournalRepositoryImpl(db);
});

// Secure Storage Provider
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

// Settings Repository Provider
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return SettingsRepositoryImpl(storage);
});

// Auth Repository Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});

// Auth State Provider
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// Theme Mode Notifier & Provider
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SettingsRepository _settingsRepository;

  ThemeModeNotifier(this._settingsRepository) : super(ThemeMode.system) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final modeStr = await _settingsRepository.getThemeMode();
    state = _parseThemeMode(modeStr);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _settingsRepository.setThemeMode(mode.name);
  }

  ThemeMode _parseThemeMode(String? modeStr) {
    switch (modeStr) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return ThemeModeNotifier(settingsRepo);
});
