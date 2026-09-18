import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Required for DateFormat('vi') used in login history, etc.
  await initializeDateFormatting('vi');

  // Safe Firebase init: a failure (e.g. placeholder options) must not crash the
  // app. Auth features simply won't work until flutterfire configure is run.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init failed (run flutterfire configure): $e');
  }

  runApp(const ProviderScope(child: App()));
}
