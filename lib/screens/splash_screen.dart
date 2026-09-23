import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_screen.dart';
import 'home_screen.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _showAuth = false;
  bool _authIsLogin = true;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const HomeScreen();
        }

        if (!_showAuth) {
          return WelcomeScreen(
            onGetStarted: () {
              setState(() {
                _authIsLogin = false;
                _showAuth = true;
              });
            },
            onSignIn: () {
              setState(() {
                _authIsLogin = true;
                _showAuth = true;
              });
            },
          );
        }

        return AuthScreen(isLogin: _authIsLogin);
      },
    );
  }
}
