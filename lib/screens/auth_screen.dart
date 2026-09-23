import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  final bool isLogin;

  const AuthScreen({super.key, this.isLogin = true});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;
  bool _showPassword = false;
  bool _showConfirm = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.isLogin;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() { _loading = true; _error = null; });

    try {
      final auth = context.read<AuthService>();
      if (_isLogin) {
        await auth.signIn(_emailCtrl.text.trim(), _passwordCtrl.text);
      } else {
        await auth.signUp(_emailCtrl.text.trim(), _passwordCtrl.text, _usernameCtrl.text.trim());
      }
    } on Exception catch (e) {
      setState(() => _error = e.toString()
          .replaceAll('Exception: ', '')
          .replaceAll('[firebase_auth/wrong-password] ', '')
          .replaceAll('[firebase_auth/', '')
          .replaceAll(']', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleMode() {
    HapticFeedback.selectionClick();
    setState(() { _isLogin = !_isLogin; _error = null; });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF0A0A1A), const Color(0xFF0D1B2A), const Color(0xFF0A0A0A)]
                    : [const Color(0xFFE3F2FD), const Color(0xFFE8F5E9), const Color(0xFFF3E5F5)],
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Logo
                      const Text(
                        '⚡',
                        style: TextStyle(fontSize: 56),
                      ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

                      const SizedBox(height: 8),

                      Text(
                        'FitBattle',
                        style: GoogleFonts.rajdhani(
                          fontSize: 44,
                          fontWeight: FontWeight.w900,
                          color: cs.primary,
                          letterSpacing: 2,
                        ),
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.3),

                      Text(
                        '1v1 fitness battles, real-time',
                        style: GoogleFonts.rajdhani(
                          fontSize: 15,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ).animate().fadeIn(delay: 400.ms),

                      const SizedBox(height: 48),

                      // Mode toggle pill
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            _modeTab('LOG IN', _isLogin, cs),
                            _modeTab('SIGN UP', !_isLogin, cs),
                          ],
                        ),
                      ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),

                      const SizedBox(height: 28),

                      // Fields
                      AnimatedSize(
                        duration: 300.ms,
                        curve: Curves.easeInOut,
                        child: Column(
                          children: [
                            if (!_isLogin) ...[
                              _buildField(_usernameCtrl, 'Username', Icons.person_outline),
                              const SizedBox(height: 14),
                            ],
                            _buildField(_emailCtrl, 'Email', Icons.mail_outline, keyboardType: TextInputType.emailAddress),
                            const SizedBox(height: 14),
                            _buildPasswordField(_passwordCtrl, 'Password', _showPassword, () {
                              setState(() => _showPassword = !_showPassword);
                            }),
                            if (!_isLogin) ...[
                              const SizedBox(height: 14),
                              _buildPasswordField(_confirmCtrl, 'Confirm Password', _showConfirm, () {
                                setState(() => _showConfirm = !_showConfirm);
                              }, validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                if (v != _passwordCtrl.text) return 'Passwords do not match';
                                return null;
                              }),
                            ],
                          ],
                        ),
                      ),

                      // Error
                      AnimatedSize(
                        duration: 200.ms,
                        child: _error != null
                            ? Container(
                                margin: const EdgeInsets.only(top: 14),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(_error!, style: GoogleFonts.rajdhani(color: Colors.redAccent, fontSize: 13))),
                                  ],
                                ),
                              ).animate().shake(duration: 400.ms)
                            : const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 28),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: AnimatedContainer(
                          duration: 200.ms,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: isDark ? Colors.black : Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: _loading ? 0 : 4,
                            ),
                            child: _loading
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: isDark ? Colors.black : Colors.white,
                                    ),
                                  )
                                : Text(
                                    _isLogin ? "LET'S GO" : 'CREATE ACCOUNT',
                                    style: GoogleFonts.rajdhani(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: 1),
                                  ),
                          ),
                        ),
                      ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.3),

                      const SizedBox(height: 18),

                      TextButton(
                        onPressed: _toggleMode,
                        child: Text(
                          _isLogin ? 'No account? Sign up' : 'Already have one? Log in',
                          style: GoogleFonts.rajdhani(color: cs.primary, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeTab(String label, bool selected, ColorScheme cs) {
    return Expanded(
      child: GestureDetector(
        onTap: selected ? null : _toggleMode,
        child: AnimatedContainer(
          duration: 200.ms,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.rajdhani(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: selected ? (Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white) : cs.onSurface.withValues(alpha: 0.5),
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: cs.primary, size: 20),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
      ),
      validator: validator ?? (v) => (v == null || v.isEmpty) ? 'Required' : null,
    );
  }

  Widget _buildPasswordField(
    TextEditingController ctrl,
    String label,
    bool showText,
    VoidCallback onToggle, {
    String? Function(String?)? validator,
  }) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: ctrl,
      obscureText: !showText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(Icons.lock_outline, color: cs.primary, size: 20),
        suffixIcon: IconButton(
          icon: Icon(showText ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
          onPressed: onToggle,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
      ),
      validator: validator ?? (v) {
        if (v == null || v.isEmpty) return 'Required';
        if (v.length < 6) return 'Password must be at least 6 characters';
        return null;
      },
    );
  }
}
