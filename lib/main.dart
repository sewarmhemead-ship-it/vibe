import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:vibe_orbit/app_theme.dart';
import 'package:vibe_orbit/main_pager.dart';
import 'package:vibe_orbit/theme_notifier.dart';
import 'package:vibe_orbit/services/interaction_stats_service.dart';
import 'package:vibe_orbit/services/local_identity_service.dart';
import 'package:vibe_orbit/services/vault_service.dart';
import 'package:vibe_orbit/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } else {
    // Mobile/desktop: prefer native config (google-services.json / plist).
    await Firebase.initializeApp();
  }
  await VaultService.instance.init();
  await LocalIdentityService.instance.ensureInitialized();
  await InteractionStatsService.instance.load();
  runApp(const VibeOrbitApp());
}

class VibeOrbitApp extends StatelessWidget {
  const VibeOrbitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: vibeOrbitHighContrast,
      builder: (context, highContrast, _) {
        final theme = highContrast
            ? vibeOrbitDarkThemeHighContrast
            : vibeOrbitDarkTheme;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.dark,
          theme: theme,
          darkTheme: theme,
          locale: const Locale('ar'),
          supportedLocales: const [
            Locale('ar'),
            Locale('en'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            return Directionality(
              textDirection: TextDirection.ltr,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const MainPager(),
        );
      },
    );
  }
}
