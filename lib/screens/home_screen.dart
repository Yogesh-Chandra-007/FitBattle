import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/friends_service.dart';
import 'battle_zone_screen.dart';
import 'friends_screen.dart';
import 'lobby_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;

  final List<Widget> _pages = const [
    BattleZoneScreen(),
    FriendsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _handleRouteArguments();
  }

  void _handleRouteArguments() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LobbyScreen(
              roomId: args['roomId'],
              exercise: args['exercise'],
              isHost: args['isHost'],
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final profile = auth.profile;
    final cs = Theme.of(context).colorScheme;

    final appBarTitles = [
      Row(
        children: [
          const Text('⚡ ', style: TextStyle(fontSize: 20)),
          Text('Battle Zone', style: GoogleFonts.rajdhani(fontSize: 22, fontWeight: FontWeight.w800, color: cs.primary)),
        ],
      ),
      Text('Friends', style: GoogleFonts.rajdhani(fontSize: 22, fontWeight: FontWeight.w800, color: cs.primary)),
      Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: cs.primary.withValues(alpha: 0.2),
            child: Text(
              (profile?.username.isNotEmpty == true) ? profile!.username[0].toUpperCase() : '?',
              style: GoogleFonts.rajdhani(fontSize: 14, fontWeight: FontWeight.w800, color: cs.primary),
            ),
          ),
          const SizedBox(width: 8),
          Text(profile?.username ?? 'Profile', style: GoogleFonts.rajdhani(fontSize: 22, fontWeight: FontWeight.w800, color: cs.primary)),
        ],
      ),
    ];

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FriendsService()),
      ],
      child: Navigator(
        onGenerateRoute: (settings) {
          if (settings.name == '/lobby') {
            final args = settings.arguments as Map;
            return MaterialPageRoute(
              builder: (_) => LobbyScreen(
                roomId: args['roomId'],
                exercise: args['exercise'],
                isHost: args['isHost'],
              ),
            );
          }
          return MaterialPageRoute(
            builder: (_) => _buildMainScaffold(appBarTitles, cs),
          );
        },
      ),
    );
  }

  Widget _buildMainScaffold(List<Widget> titles, ColorScheme cs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Text(
              'FitBattle',
              style: GoogleFonts.rajdhani(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: cs.primary,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 10),
            if (_currentTab == 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: cs.primary.withValues(alpha: 0.12),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
                ),
                child: Text(
                  'SWEAT • COMPETE • GROW',
                  style: GoogleFonts.rajdhani(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: cs.onSurface.withValues(alpha: 0.7),
                    letterSpacing: 2,
                  ),
                ),
              ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Theme.of(context).dividerColor),
        ),
      ),
      body: IndexedStack(
        index: _currentTab,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
          color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.white,
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: (i) {
            if (i != _currentTab) HapticFeedback.selectionClick();
            setState(() => _currentTab = i);
          },
          backgroundColor: Colors.transparent,
          selectedItemColor: cs.primary,
          unselectedItemColor: cs.onSurface.withValues(alpha: 0.45),
          selectedLabelStyle: GoogleFonts.rajdhani(fontSize: 12, fontWeight: FontWeight.w800),
          unselectedLabelStyle: GoogleFonts.rajdhani(fontSize: 12, fontWeight: FontWeight.w600),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.flash_on), label: 'Battle'),
            BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Friends'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
