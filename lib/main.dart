import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';
import 'package:video_journal/app/theme/app_theme.dart';
import 'package:video_journal/features/backup/data/backup_worker.dart';
import 'package:video_journal/features/journal/presentation/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase (Safely catch errors if firebase config is missing during initial run)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    // If google-services.json is missing or Firebase is not configured yet,
    // we continue running offline as defined in the FRD (Offline-first, cloud-optional).
    debugPrint('Firebase initialization failed: $e. Running in offline local-only mode.');
  }

  // Initialize WorkManager for background backups
  try {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
  } catch (e) {
    debugPrint('WorkManager initialization failed: $e');
  }

  runApp(
    const ProviderScope(
      child: JournalApp(),
    ),
  );
}

class JournalApp extends StatelessWidget {
  const JournalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Visual Journal',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
