import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/battle_service.dart';
import 'services/theme_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const FitnessBattleApp());
}

class FitnessBattleApp extends StatelessWidget {
  const FitnessBattleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => BattleService()),
      ],
      child: Consumer<ThemeNotifier>(
        builder: (_, themeNotifier, __) => MaterialApp(
          title: 'Fitness Battle',
          debugShowCheckedModeBanner: false,
          themeMode: themeNotifier.mode,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
