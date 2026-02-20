import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui' as ui;

import '../../providers/core_providers.dart';
import '../../utils/app_animations.dart';

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
    final isDesktop = screenWidth >= 1000;
    final isTablet = screenWidth >= 600 && screenWidth < 1000;

    // Responsive max width
    final maxContentWidth = isDesktop ? 520.0 : (isTablet ? 500.0 : 420.0);
    final horizontalPadding = isDesktop ? 32.0 : (isTablet ? 24.0 : 20.0);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Premium gradient background (light blue → violet → white)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFE3F2FD), // Light blue
                  const Color(0xFFF3E5F5), // Light violet
                  const Color(0xFFFAFAFA), // Near white
                  Colors.white,
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),

          // Animated decorative blobs for premium feel
          _AnimatedGradientBackground(),
          
          Positioned(
            top: -120,
            right: -120,
            child: _BlurBlob(size: 350, color: const Color(0xFF64B5F6).withValues(alpha: 0.20)),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: _BlurBlob(size: 320, color: const Color(0xFFAB47BC).withValues(alpha: 0.18)),
          ),
          Positioned(
            top: 200,
            left: -80,
            child: _BlurBlob(size: 280, color: const Color(0xFF42A5F5).withValues(alpha: 0.15)),
          ),
          Positioned(
            bottom: 180,
            right: -100,
            child: _BlurBlob(size: 300, color: const Color(0xFF9575CD).withValues(alpha: 0.15)),
          ),

          // Main content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: isDesktop ? 32 : 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Premium header with glass logo container
                        AppAnimations.fadeInUp(
                          duration: const Duration(milliseconds: 600),
                          child: _PremiumHeader(),
                        ),
                        SizedBox(height: isDesktop ? 40 : 32),

                        // Smart Login Form
                        AppAnimations.fadeInUp(
                          duration: const Duration(milliseconds: 700),
                          child: _SmartLoginForm(
                            formKey: _formKey,
                            idController: _idController,
                            passwordController: _passwordController,
                            loading: _loading,
                            obscurePassword: _obscurePassword,
                            statusMessage: _statusMessage,
                            detectedLoginType: _detectedLoginType,
                            onToggleObscure: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                            onSubmit: _handleLogin,
                            onHelpTap: () => _showHelpDialog(context),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Footer
                        _PremiumFooter(),
                      ],
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

// ===== PREMIUM 2026 WIDGETS =====

/// Animated gradient background with slow moving effect
class _AnimatedGradientBackground extends StatefulWidget {
  @override
  State<_AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<_AnimatedGradientBackground>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final offset = _controller.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(offset * 2 - 1, -1),
              end: Alignment(-offset * 2 + 1, 1),
              colors: [
                const Color(0xFF1F7FB8).withValues(alpha: 0.10),
                const Color(0xFF26A69A).withValues(alpha: 0.08),
                const Color(0xFF8B5CF6).withValues(alpha: 0.06),
                const Color(0xFF0EA5E9).withValues(alpha: 0.06),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HoverScale extends StatefulWidget {
  const _HoverScale({required this.child, this.enabled = true, this.onTap});

  final Widget child;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  State<_HoverScale> createState() => _HoverScaleState();
}

class _HoverScaleState extends State<_HoverScale> {
  bool _hovering = false;

  bool get _supportsHover {
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final enableHover = widget.enabled && _supportsHover;

    Widget content = AnimatedScale(
      scale: (_hovering && enableHover) ? 1.015 : 1.0,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: widget.child,
    );

    if (enableHover) {
      content = MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: content,
      );
    }

    if (widget.onTap != null) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: content,
      );
    }

    return content;
  }
}

/// Floating blur blob for glassmorphic effect
class _BlurBlob extends StatefulWidget {
  final double size;
  final Color color;

  const _BlurBlob({required this.size, required this.color});

  @override
  State<_BlurBlob> createState() => _BlurBlobState();
}

class _BlurBlobState extends State<_BlurBlob> with TickerProviderStateMixin {
  late AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0),
          end: const Offset(0, 30),
        ).evaluate(_floatController);

        return Transform.translate(
          offset: offset,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Premium header with glassmorphic logo container
class _PremiumHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Branding logo paths
    const primaryLogoAssetPath = 'assets/images/logo.png';
    const fallbackLogoAssetPath = 'assets/images/school_logo.png';

    final media = MediaQuery.of(context);
    final dpr = media.devicePixelRatio;
    final isCompact = media.size.width < 360;
    final isMobile = media.size.width < 600;

    // Responsive logo sizing - 20% smaller than before
    // Mobile: max 96px, Tablet: max 96px, Desktop: max 112px
    final maxLogoSize = isCompact ? 88.0 : (isMobile ? 96.0 : 112.0);
    // Increased cache multiplier for HD rendering (2x for crisp display)
    final cachePx = (maxLogoSize * 2.5 * dpr).round();

    return Column(
      children: [
        // Logo with natural aspect ratio - shadow removed for cleaner look
        RepaintBoundary(
          child: Align(
            alignment: Alignment.center,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: maxLogoSize,
                maxHeight: maxLogoSize * 1.2, // Allow slightly taller for logo proportions
              ),
              child: Image.asset(
                primaryLogoAssetPath,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                isAntiAlias: true,
                // HD cache settings for maximum clarity
                cacheWidth: cachePx,
                cacheHeight: cachePx,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) {
                  return Image.asset(
                    fallbackLogoAssetPath,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    isAntiAlias: true,
                    // HD cache settings for fallback logo too
                    cacheWidth: cachePx,
                    cacheHeight: cachePx,
                    gaplessPlayback: true,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        constraints: BoxConstraints(
                          maxWidth: maxLogoSize,
                          maxHeight: maxLogoSize * 1.2,
                        ),
                        child: Icon(
                          Icons.school_rounded,
                          size: maxLogoSize * 0.6,
                          color: const Color(0xFF42A5F5),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // 2-line title: HONGIRANA / School of Excellence
        Text(
          'HONGIRANA',
          style: TextStyle(
            fontFamily: 'Ubuntu',
            fontSize: isCompact ? 28 : (isMobile ? 32 : 40),
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            height: 1.0,
            color: const Color(0xFF5C2E2E),
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.08),
                offset: const Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'School of Excellence',
          style: TextStyle(
            fontFamily: 'Ubuntu',
            fontSize: isCompact ? 15 : (isMobile ? 16 : 18),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            height: 1.1,
            color: const Color(0xFF5C2E2E),
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.05),
                offset: const Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Welcome back',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.3,
            color: const Color(0xFF6B7280),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Glassmorphic card wrapper with premium 2026 styling
class _GlassmorphicCard extends StatelessWidget {
  final Widget child;

  const _GlassmorphicCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.85),
                Colors.white.withValues(alpha: 0.75),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.8),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 40,
                offset: const Offset(0, 15),
              ),
              BoxShadow(
                color: const Color(0xFF42A5F5).withValues(alpha: 0.08),
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.7),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
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
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final VoidCallback onHelpTap;

  const _SmartLoginForm({
    super.key,
    required this.formKey,
    required this.idController,
    required this.passwordController,
    required this.loading,
    required this.obscurePassword,
    required this.statusMessage,
    required this.detectedLoginType,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onHelpTap,
  });

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFF42A5F5);
    
    // Build dynamic title based on detected login type
    final titleText = detectedLoginType.isEmpty 
        ? 'Sign In'
        : '${detectedLoginType} Login';
    
    final subtitleText = detectedLoginType == 'Parent'
        ? 'Secure access to your child\'s information'
        : detectedLoginType == 'Staff'
        ? 'Access your portal securely'
        : 'Enter mobile number or email to continue';

    return _GlassmorphicCard(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ) ?? const TextStyle(),
              child: Text(
                titleText,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF79747E),
                  ) ?? const TextStyle(),
              child: Text(
                subtitleText,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),

            // Smart ID field (mobile or email)
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
                focusColor: themeColor,
              ),
              validator: (value) {
                final v = (value ?? '').trim();
                if (v.isEmpty) return 'Enter mobile number or email';
                
                // Check if it's a mobile number
                final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                if (digits.length == 10 && v.length <= 12) {
                  return null; // Valid mobile
                }
                
                // Check if it's an email
                if (v.contains('@')) {
                  return null; // Valid email
                }
                
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
                focusColor: themeColor,
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword ? Icons.visibility_off : Icons.visibility,
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
            const SizedBox(height: 18),

            // Sign in button with gradient
            _PremiumButton(
              label: 'Sign in',
              loading: loading,
              gradient1: themeColor,
              gradient2: _darkenColor(themeColor, 0.2),
              onPressed: loading ? null : onSubmit,
            ),

            // Status message
            if (loading && (statusMessage ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F7FB8).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF1F7FB8).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation(Color(0xFF1F7FB8)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        statusMessage!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF1F7FB8),
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Forgot password text button (only for email users)
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password reset coming soon')),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1F7FB8),
              ),
              child: const Text('Forgot password?'),
            ),

            const SizedBox(height: 6),

            // Help button
            TextButton.icon(
              onPressed: onHelpTap,
              icon: const Icon(Icons.help_outline, size: 18),
              label: const Text('Need help?'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1F7FB8),
              ),
            ),
          ],
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
    Color focusColor = const Color(0xFF42A5F5),
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 22, color: const Color(0xFF79747E)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.85),
      labelStyle: const TextStyle(
        color: Color(0xFF616161),
        fontSize: 14,
      ),
      hintStyle: TextStyle(
        color: const Color(0xFF9E9E9E).withValues(alpha: 0.7),
        fontSize: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: const Color(0xFFE0E0E0).withValues(alpha: 0.8),
          width: 1.5,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: const Color(0xFFE0E0E0).withValues(alpha: 0.8),
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: focusColor,
          width: 2.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFEF5350),
          width: 1.5,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFEF5350),
          width: 2.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    );
  }
}

/// Premium button with gradient and loading state (2026 style)
class _PremiumButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  final Color gradient1;
  final Color gradient2;

  const _PremiumButton({
    required this.label,
    required this.loading,
    required this.onPressed,
    this.gradient1 = const Color(0xFF42A5F5),
    this.gradient2 = const Color(0xFF1976D2),
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;

    return _HoverScale(
      enabled: enabled,
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: enabled
                ? [gradient1, gradient2]
                : [
                    gradient1.withValues(alpha: 0.50),
                    gradient2.withValues(alpha: 0.50),
                  ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: gradient1.withValues(alpha: 0.20),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: gradient2.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                    spreadRadius: 0,
                  ),
                ]
              : [
                  BoxShadow(
                    color: gradient1.withValues(alpha: 0.10),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.white.withValues(alpha: 0.3),
            highlightColor: Colors.white.withValues(alpha: 0.1),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading) ...[
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation(
                          Colors.white.withValues(alpha: 0.98),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                  ] else
                    const Icon(Icons.login_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                  ),
                ],
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

/// Helper to darken a color by a factor (0.0 - 1.0)
Color _darkenColor(Color color, double factor) {
  assert(factor >= 0 && factor <= 1);
  
  final int red = (color.red * (1 - factor)).round();
  final int green = (color.green * (1 - factor)).round();
  final int blue = (color.blue * (1 - factor)).round();
  
  return Color.fromRGBO(red, green, blue, color.opacity);
}
