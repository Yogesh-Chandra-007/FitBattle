import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../widgets/cyberpunk_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _hapticsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() => _version = '${packageInfo.version} (${packageInfo.buildNumber})');
    } catch (e) {
      setState(() => _version = '1.0.0');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.rajdhani(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: cs.primary,
            letterSpacing: 0.5,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PREFERENCES',
                style: GoogleFonts.rajdhani(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: cs.onSurface.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(height: 12),

              CyberpunkCard(
                padding: EdgeInsets.zero,
                glow: false,
                child: Column(
                  children: [
                    _buildSettingTile(
                      icon: Icons.notifications,
                      title: 'Notifications',
                      subtitle: 'Battle invites and updates',
                      value: _notificationsEnabled,
                      onChanged: (v) {
                        HapticFeedback.lightImpact();
                        setState(() => _notificationsEnabled = v);
                      },
                    ),
                    Divider(color: Theme.of(context).dividerColor, height: 1),
                    _buildSettingTile(
                      icon: Icons.volume_up,
                      title: 'Sound Effects',
                      subtitle: 'Battle sounds and music',
                      value: _soundEnabled,
                      onChanged: (v) {
                        HapticFeedback.lightImpact();
                        setState(() => _soundEnabled = v);
                      },
                    ),
                    Divider(color: Theme.of(context).dividerColor, height: 1),
                    _buildSettingTile(
                      icon: Icons.vibration,
                      title: 'Haptic Feedback',
                      subtitle: 'Vibrations on interactions',
                      value: _hapticsEnabled,
                      onChanged: (v) {
                        HapticFeedback.lightImpact();
                        setState(() => _hapticsEnabled = v);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'ABOUT',
                style: GoogleFonts.rajdhani(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: cs.onSurface.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(height: 12),

              CyberpunkCard(
                padding: const EdgeInsets.all(16),
                glow: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.fitness_center, color: cs.primary, size: 40),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'FitBattle',
                                style: GoogleFonts.rajdhani(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: cs.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                'Version $_version',
                                style: GoogleFonts.rajdhani(
                                  fontSize: 13,
                                  color: cs.onSurface.withValues(alpha: 0.55),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Real-time 1v1 fitness battles with pose detection.',
                      style: GoogleFonts.rajdhani(
                        fontSize: 14,
                        color: cs.onSurface.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              CyberpunkCard(
                padding: EdgeInsets.zero,
                glow: false,
                child: Column(
                  children: [
                    _buildInfoTile(
                      icon: Icons.privacy_tip,
                      title: 'Privacy Policy',
                      onTap: () => _showComingSoon('Privacy Policy'),
                    ),
                    Divider(color: Theme.of(context).dividerColor, height: 1),
                    _buildInfoTile(
                      icon: Icons.description,
                      title: 'Terms of Service',
                      onTap: () => _showComingSoon('Terms of Service'),
                    ),
                    Divider(color: Theme.of(context).dividerColor, height: 1),
                    _buildInfoTile(
                      icon: Icons.help,
                      title: 'Help & Support',
                      onTap: () => _showComingSoon('Help & Support'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;

    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(
        title,
        style: GoogleFonts.rajdhani(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: cs.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.rajdhani(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: cs.onSurface.withValues(alpha: 0.55),
        ),
      ),
      secondary: Icon(icon, color: cs.primary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(icon, color: cs.primary),
      title: Text(
        title,
        style: GoogleFonts.rajdhani(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: cs.onSurface,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: cs.onSurface.withValues(alpha: 0.4)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  void _showComingSoon(String feature) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Coming Soon',
          style: GoogleFonts.rajdhani(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: cs.primary,
          ),
        ),
        content: Text(
          '$feature will be available in a future update.',
          style: GoogleFonts.rajdhani(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: GoogleFonts.rajdhani(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: cs.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
