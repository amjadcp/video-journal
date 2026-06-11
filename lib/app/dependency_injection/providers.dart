import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
