import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../providers/core_providers.dart';

class UnifiedLoginScreen extends ConsumerStatefulWidget {
  const UnifiedLoginScreen({super.key});

  @override
  ConsumerState<UnifiedLoginScreen> createState() => _UnifiedLoginScreenState();
}

class _UnifiedLoginScreenState extends ConsumerState<UnifiedLoginScreen> {
  // Smart login form
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  bool _rememberMe = false;
  String? _statusMessage;
  String _detectedLoginType = ''; // "Parent", "Staff", or ""

  @override
  void initState() {
    super.initState();
    // Listen to changes in ID field to detect login type
    _idController.addListener(_updateDetectedLoginType);
  }

  void _updateDetectedLoginType() {
    final input = _idController.text.trim();
    String newType = '';
    
    if (input.isEmpty) {
      newType = '';
    } else if (_isMobileNumber(input)) {
      newType = 'Parent';
    } else if (_isEmail(input)) {
      newType = 'Staff';
    }
    
    if (newType != _detectedLoginType) {
      setState(() => _detectedLoginType = newType);
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Need Help?'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Contact Support',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 12),
              Text('📧 Email: support@hongirana.edu'),
              SizedBox(height: 8),
              Text('📞 Phone: +91-XXXX-XXXX-XXXX'),
              SizedBox(height: 8),
              Text('💬 WhatsApp: +91-XXXX-XXXX-XXXX'),
              SizedBox(height: 16),
              Text(
                'Frequently Asked Questions',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 8),
              Text('• Check your email for account activation'),
              SizedBox(height: 4),
              Text('• Try resetting your password'),
              SizedBox(height: 4),
              Text('• Ensure you\'re on stable internet'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))
        ],
      ),
    );
  }

  String _prettyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return 'Wrong details. Please check your login and try again.';
        case 'user-disabled':
          return 'This account is disabled. Please contact the admin.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'network-request-failed':
          return 'Network error. Please check your internet and try again.';
        case 'invalid-email':
          return 'Invalid email address.';
        case 'operation-not-allowed':
          return 'Sign-in is not enabled for this app. Please contact the admin.';
        case 'weak-password':
          return 'Password must be at least 6 characters.';
        case 'requires-recent-login':
          return 'Please sign in again and retry.';
        default:
          final msg = (e.message ?? '').trim();
          return msg.isEmpty ? 'Login failed. Please try again.' : msg;
      }
    }

    final raw = e.toString();
    const prefix = 'Exception: ';
    final msg = raw.startsWith(prefix) ? raw.substring(prefix.length) : raw;
    if (msg.toLowerCase().contains('wrong password')) {
      return 'Wrong details. Please check your login and try again.';
    }
    return msg;
  }

  // Smart detection: check if input is mobile number (10 digits) or email
  bool _isMobileNumber(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length == 10 && input.trim().length <= 12;
  }

  bool _isEmail(String input) {
    return input.trim().contains('@');
  }

  // Smart login handler
  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    
    final id = _idController.text.trim();
    final password = _passwordController.text;

    if (_isMobileNumber(id)) {
      // Login as Parent
      await _loginAsParent(id, password);
    } else if (_isEmail(id)) {
      // Login as Staff (Teacher/Admin/Viewer)
      await _loginAsStaff(id, password);
    } else {
      _snack('Please enter a valid mobile number or email');
    }
  }

  Future<void> _loginAsParent(String phoneNumber, String password) async {
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).signInParent(
            phoneNumber: phoneNumber,
            password: password,
            onStatus: (m) {
              if (!mounted) return;
              setState(() => _statusMessage = m);
            },
          );
      if (mounted) context.go('/');
    } catch (e) {
      if (!mounted) return;
      _snack(_prettyError(e));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _loginAsStaff(String email, String password) async {
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).signInEmail(
            email: email,
            password: password,
          );
      // Router will handle role-based redirection
    } catch (e) {
      if (!mounted) return;
      _snack(_prettyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;

    // Design requirement: card responsive width, max 420 on web/desktop.
    final maxCardWidth = 420.0;
    final horizontalPadding = screenWidth >= 600 ? 28.0 : 20.0;

    const bg1 = Color(0xFF6D28D9); // Purple
    const bg2 = Color(0xFF2563EB); // Blue
    const bg3 = Color(0xFF0EA5E9); // Sky

    final focusColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Full-screen curved gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [bg1, bg2, bg3],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),

          // Soft wave at the bottom (two layers for depth)
          Align(
            alignment: Alignment.bottomCenter,
            child: ClipPath(
              clipper: _BottomWaveClipper(amplitude: 26, shift: 0.0),
              child: Container(
                height: 220,
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ClipPath(
              clipper: _BottomWaveClipper(amplitude: 18, shift: 30.0),
              child: Container(
                height: 170,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxCardWidth),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 720),
                      curve: Curves.easeOutCubic,
                      builder: (context, t, child) {
                        return Opacity(
                          opacity: t,
                          child: Transform.translate(
                            offset: Offset(0, (1 - t) * 22),
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SmartLoginForm(
                            formKey: _formKey,
                            idController: _idController,
                            passwordController: _passwordController,
                            loading: _loading,
                            obscurePassword: _obscurePassword,
                            statusMessage: _statusMessage,
                            detectedLoginType: _detectedLoginType,
                            rememberMe: _rememberMe,
                            onRememberMeChanged: (v) =>
                                setState(() => _rememberMe = v ?? false),
                            focusColor: focusColor,
                            buttonGradient: const [bg2, bg1],
                            onToggleObscure: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                            onSubmit: _handleLogin,
                            onHelpTap: () => _showHelpDialog(context),
                          ),
                          const SizedBox(height: 18),
                          _PremiumFooter(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wave-style bottom clipper used for the curved gradient login background.
class _BottomWaveClipper extends CustomClipper<Path> {
  _BottomWaveClipper({required this.amplitude, required this.shift});

  final double amplitude;
  final double shift;

  @override
  Path getClip(Size size) {
    final path = Path();

    // Start from top-left
    path.lineTo(0, 0);

    // Draw a smooth wave across the top edge of the clipped container.
    final baseY = amplitude + 18;
    path.quadraticBezierTo(
      size.width * 0.20,
      baseY + shift,
      size.width * 0.50,
      baseY,
    );
    path.quadraticBezierTo(
      size.width * 0.80,
      baseY - shift,
      size.width,
      baseY + 8,
    );

    // Close shape down to bottom
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant _BottomWaveClipper oldClipper) {
    return oldClipper.amplitude != amplitude || oldClipper.shift != shift;
  }
}

/// Smart Login Form - Auto-detects mobile (parent) or email (staff)
class _SmartLoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController idController;
  final TextEditingController passwordController;
  final bool loading;
  final bool obscurePassword;
  final String? statusMessage;
  final String detectedLoginType; // "Parent", "Staff", or ""
  final bool rememberMe;
  final ValueChanged<bool?> onRememberMeChanged;
  final Color focusColor;
  final List<Color> buttonGradient;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final VoidCallback onHelpTap;

  const _SmartLoginForm({
    required this.formKey,
    required this.idController,
    required this.passwordController,
    required this.loading,
    required this.obscurePassword,
    required this.statusMessage,
    required this.detectedLoginType,
    required this.rememberMe,
    required this.onRememberMeChanged,
    required this.focusColor,
    required this.buttonGradient,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onHelpTap,
  });

  @override
  Widget build(BuildContext context) {
    // Build dynamic hint based on detected login type (UI-only).
    final subtitleText = detectedLoginType == 'Parent'
        ? 'Parent portal access'
        : detectedLoginType == 'Staff'
            ? 'Staff portal access'
            : 'Use mobile number (parent) or email (staff)';

    return Material(
      color: Colors.white,
      elevation: 18,
      shadowColor: Colors.black.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Text(
                'Log In',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: const Color(0xFF0F172A),
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitleText,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 18),

              // ID field (mobile/email)
              TextFormField(
                controller: idController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                decoration: _buildModernInputDecoration(
                  context,
                  label: 'Mobile Number or Email',
                  hint: '10-digit mobile or email',
                  icon: Icons.person_outline,
                  focusColor: focusColor,
                ),
                validator: (value) {
                  final v = (value ?? '').trim();
                  if (v.isEmpty) return 'Enter mobile number or email';

                  final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                  if (digits.length == 10 && v.length <= 12) return null;
                  if (v.contains('@')) return null;

                  return 'Enter valid mobile number or email';
                },
              ),
              const SizedBox(height: 14),

              // Password field
              TextFormField(
                controller: passwordController,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => loading ? null : onSubmit(),
                decoration: _buildModernInputDecoration(
                  context,
                  label: 'Password',
                  icon: Icons.lock_outline,
                  focusColor: focusColor,
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 20,
                    ),
                    onPressed: onToggleObscure,
                  ),
                ),
                validator: (value) {
                  if ((value ?? '').isEmpty) return 'Enter password';
                  if ((value ?? '').length < 4) return 'Password too short';
                  return null;
                },
              ),

              const SizedBox(height: 10),

              // Remember Me + Help row
              Row(
                children: [
                  Checkbox(
                    value: rememberMe,
                    onChanged: onRememberMeChanged,
                    activeColor: focusColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Remember Me',
                    style: TextStyle(
                      color: Color(0xFF334155),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: onHelpTap,
                    style: TextButton.styleFrom(
                      foregroundColor: focusColor,
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Need help?'),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Login button
              _GradientLoginButton(
                label: 'Log In',
                loading: loading,
                onPressed: loading ? null : onSubmit,
                gradient: buttonGradient,
              ),

              // Status message
              if (loading && (statusMessage ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(focusColor),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          statusMessage!,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF334155),
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 6),

              // Forgot password (kept)
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password reset coming soon')),
                  );
                },
                child: const Text('Forgot password?'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildModernInputDecoration(
    BuildContext context, {
    required String label,
    String? hint,
    required IconData icon,
    Widget? suffixIcon,
    Color focusColor = const Color(0xFF2563EB),
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 22, color: const Color(0xFF64748B)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF3F4F6),
      labelStyle: const TextStyle(
        color: Color(0xFF475569),
        fontSize: 14,
      ),
      hintStyle: TextStyle(
        color: const Color(0xFF94A3B8),
        fontSize: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(
          color: focusColor,
          width: 2.2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(
          color: Color(0xFFEF5350),
          width: 1.5,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(
          color: Color(0xFFEF5350),
          width: 2.2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    );
  }
}

/// Gradient login button matching the premium curved SaaS style.
class _GradientLoginButton extends StatelessWidget {
  const _GradientLoginButton({
    required this.label,
    required this.loading,
    required this.onPressed,
    required this.gradient,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: onPressed == null
                ? [
                    gradient[0].withValues(alpha: 0.55),
                    gradient[1].withValues(alpha: 0.55),
                  ]
                : gradient,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(30),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: loading
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        label,
                        key: const ValueKey('label'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Premium footer with branding (2026 style)
class _PremiumFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.08),
                Colors.transparent,
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '© 2026 Hongirana School of Excellence',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF9CA3AF),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF42A5F5).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'v1.0.0',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF42A5F5),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
