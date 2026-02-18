import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui' as ui;

import '../../providers/core_providers.dart';
import '../../utils/app_animations.dart';

enum LoginTab { parent, teacher, admin, student }

class UnifiedLoginScreen extends ConsumerStatefulWidget {
  const UnifiedLoginScreen({super.key, this.initialTab = LoginTab.parent});

  final LoginTab initialTab;

  @override
  ConsumerState<UnifiedLoginScreen> createState() => _UnifiedLoginScreenState();
}

class _UnifiedLoginScreenState extends ConsumerState<UnifiedLoginScreen> {
  late LoginTab _tab;

  // Parent
  final _parentFormKey = GlobalKey<FormState>();
  final _parentPhoneController = TextEditingController();
  final _parentPasswordController = TextEditingController();
  bool _parentObscure = true;
  bool _parentLoading = false;
  String? _parentStatus;

  // Teacher
  final _teacherFormKey = GlobalKey<FormState>();
  final _teacherEmailController = TextEditingController();
  final _teacherPasswordController = TextEditingController();
  bool _teacherObscure = true;
  bool _teacherLoading = false;

  // Admin
  final _adminFormKey = GlobalKey<FormState>();
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  bool _adminObscure = true;
  bool _adminLoading = false;

  // Student
  final _studentFormKey = GlobalKey<FormState>();
  final _studentEmailController = TextEditingController();
  final _studentPasswordController = TextEditingController();
  bool _studentObscure = true;
  bool _studentLoading = false;

  bool get _anyLoading => _parentLoading || _teacherLoading || _adminLoading || _studentLoading;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  @override
  void didUpdateWidget(covariant UnifiedLoginScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      setState(() => _tab = widget.initialTab);
    }
  }

  @override
  void dispose() {
    _parentPhoneController.dispose();
    _parentPasswordController.dispose();
    _teacherEmailController.dispose();
    _teacherPasswordController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    _studentEmailController.dispose();
    _studentPasswordController.dispose();
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

  Future<void> _signInParent() async {
    if (!(_parentFormKey.currentState?.validate() ?? false)) return;
    setState(() => _parentLoading = true);
    try {
      await ref.read(authServiceProvider).signInParent(
            phoneNumber: _parentPhoneController.text.trim(),
            password: _parentPasswordController.text,
            onStatus: (m) {
              if (!mounted) return;
              setState(() => _parentStatus = m);
            },
          );
      if (mounted) context.go('/');
    } catch (e) {
      if (!mounted) return;
      _snack(_prettyError(e));
    } finally {
      if (mounted) {
        setState(() {
          _parentLoading = false;
          _parentStatus = null;
        });
      }
    }
  }

  Future<void> _signInTeacher() async {
    if (!(_teacherFormKey.currentState?.validate() ?? false)) return;
    setState(() => _teacherLoading = true);
    try {
      await ref.read(authServiceProvider).signInEmail(
            email: _teacherEmailController.text.trim(),
            password: _teacherPasswordController.text,
          );
    } catch (e) {
      if (!mounted) return;
      _snack(_prettyError(e));
    } finally {
      if (mounted) setState(() => _teacherLoading = false);
    }
  }

  Future<void> _signInAdmin() async {
    if (!(_adminFormKey.currentState?.validate() ?? false)) return;
    setState(() => _adminLoading = true);
    try {
      await ref.read(authServiceProvider).signInEmail(
            email: _adminEmailController.text.trim(),
            password: _adminPasswordController.text,
          );
    } catch (e) {
      if (!mounted) return;
      _snack(_prettyError(e));
    } finally {
      if (mounted) setState(() => _adminLoading = false);
    }
  }

  Future<void> _signInStudent() async {
    if (!(_studentFormKey.currentState?.validate() ?? false)) return;
    setState(() => _studentLoading = true);
    try {
      await ref.read(authServiceProvider).signInEmail(
            email: _studentEmailController.text.trim(),
            password: _studentPasswordController.text,
          );
    } catch (e) {
      if (!mounted) return;
      _snack(_prettyError(e));
    } finally {
      if (mounted) setState(() => _studentLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(elevation: 0, backgroundColor: Colors.transparent),
      backgroundColor: const Color(0xFFFAFBFC),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Animated gradient background
          _AnimatedGradientBackground(),

          // Floating blur blobs (glassmorphic effect)
          Positioned(
            top: -100,
            right: -100,
            child: _BlurBlob(size: 300, color: Colors.blue.withValues(alpha: 0.15)),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: _BlurBlob(size: 280, color: Colors.purple.withValues(alpha: 0.12)),
          ),

          // Main content
          SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header with animation
                    AppAnimations.fadeInUp(
                      child: _PremiumHeader(),
                    ),
                    const SizedBox(height: 32),

                    // Role selector with animation
                    AppAnimations.fadeInUp(
                      child: _ModernRoleSelector(
                        value: _tab,
                        onChanged: _anyLoading ? null : (v) => setState(() => _tab = v),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Form switcher with animation
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) {
                        return SlideTransition(
                          position: Tween<Offset>(begin: const Offset(0.2, 0), end: Offset.zero)
                              .animate(animation),
                          child: FadeTransition(opacity: animation, child: child),
                        );
                      },
                      child: switch (_tab) {
                        LoginTab.parent => _PremiumParentForm(
                            key: const ValueKey('parent'),
                            formKey: _parentFormKey,
                            phoneController: _parentPhoneController,
                            passwordController: _parentPasswordController,
                            loading: _parentLoading,
                            obscure: _parentObscure,
                            statusMessage: _parentStatus,
                            onToggleObscure: () =>
                                setState(() => _parentObscure = !_parentObscure),
                            onSubmit: _signInParent,
                            onHelpTap: () => _showHelpDialog(context),
                          ),
                        LoginTab.teacher => _PremiumEmailForm(
                            key: const ValueKey('teacher'),
                            title: 'Teacher Login',
                            formKey: _teacherFormKey,
                            emailController: _teacherEmailController,
                            passwordController: _teacherPasswordController,
                            loading: _teacherLoading,
                            obscure: _teacherObscure,
                            onToggleObscure: () =>
                                setState(() => _teacherObscure = !_teacherObscure),
                            onSubmit: _signInTeacher,
                            onHelpTap: () => _showHelpDialog(context),
                          ),
                        LoginTab.admin => _PremiumEmailForm(
                            key: const ValueKey('admin'),
                            title: 'Admin Login',
                            formKey: _adminFormKey,
                            emailController: _adminEmailController,
                            passwordController: _adminPasswordController,
                            loading: _adminLoading,
                            obscure: _adminObscure,
                            onToggleObscure: () => setState(() => _adminObscure = !_adminObscure),
                            onSubmit: _signInAdmin,
                            onHelpTap: () => _showHelpDialog(context),
                          ),
                        LoginTab.student => _PremiumEmailForm(
                            key: const ValueKey('student'),
                            title: 'Student Login',
                            formKey: _studentFormKey,
                            emailController: _studentEmailController,
                            passwordController: _studentPasswordController,
                            loading: _studentLoading,
                            obscure: _studentObscure,
                            onToggleObscure: () =>
                                setState(() => _studentObscure = !_studentObscure),
                            onSubmit: _signInStudent,
                            onHelpTap: () => _showHelpDialog(context),
                          ),
                      },
                    ),
                    const SizedBox(height: 24),

                    // Footer
                    _PremiumFooter(),
                  ],
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
                const Color(0xFF1F7FB8).withValues(alpha: 0.08),
                const Color(0xFF26A69A).withValues(alpha: 0.06),
                const Color(0xFF6366F1).withValues(alpha: 0.05),
              ],
            ),
          ),
        );
      },
    );
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

/// Premium header with school name and subtitle
class _PremiumHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Logo placeholder or icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1F7FB8).withValues(alpha: 0.3),
                const Color(0xFF26A69A).withValues(alpha: 0.2),
              ],
            ),
          ),
          child: Center(
            child: Icon(
              Icons.school,
              size: 44,
              color: const Color(0xFF1F7FB8),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Hongirana School',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: const Color(0xFF0F1419),
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Welcome back',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF79747E),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Modern role selector with pill buttons and smooth animations
class _ModernRoleSelector extends StatelessWidget {
  final LoginTab value;
  final ValueChanged<LoginTab>? onChanged;

  const _ModernRoleSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    Widget pill({
      required LoginTab tab,
      required String label,
      required IconData icon,
    }) {
      final isSelected = value == tab;
      final colors = _getRoleColors(tab);

      return Expanded(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colors['gradient1']!, colors['gradient2']!],
                  )
                : null,
            color: isSelected ? null : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? colors['border']! : const Color(0xFFE0E0E0),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colors['shadow']!.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onChanged == null ? null : () => onChanged!(tab),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 6 : 10,
                  vertical: 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 24,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF5F6368),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF5F6368),
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            letterSpacing: 0.3,
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            pill(tab: LoginTab.parent, label: 'Parent', icon: Icons.family_restroom),
            const SizedBox(width: 8),
            pill(tab: LoginTab.teacher, label: 'Teacher', icon: Icons.school_outlined),
            const SizedBox(width: 8),
            pill(tab: LoginTab.admin, label: 'Admin', icon: Icons.admin_panel_settings_outlined),
            const SizedBox(width: 8),
            pill(tab: LoginTab.student, label: 'Student', icon: Icons.person_outline),
          ],
        ),
      ),
    );
  }

  Map<String, Color> _getRoleColors(LoginTab tab) {
    return switch (tab) {
      LoginTab.parent => {
          'gradient1': const Color(0xFF42A5F5),
          'gradient2': const Color(0xFF29B6F6),
          'border': const Color(0xFF1976D2),
          'shadow': const Color(0xFF42A5F5),
        },
      LoginTab.teacher => {
          'gradient1': const Color(0xFF66BB6A),
          'gradient2': const Color(0xFF4CAF50),
          'border': const Color(0xFF388E3C),
          'shadow': const Color(0xFF66BB6A),
        },
      LoginTab.admin => {
          'gradient1': const Color(0xFFFFA726),
          'gradient2': const Color(0xFFFF9800),
          'border': const Color(0xFFF57C00),
          'shadow': const Color(0xFFFFA726),
        },
      LoginTab.student => {
          'gradient1': const Color(0xFFAB47BC),
          'gradient2': const Color(0xFF9C27B0),
          'border': const Color(0xFF7B1FA2),
          'shadow': const Color(0xFFAB47BC),
        },
    };
  }
}

/// Glassmorphic card wrapper
class _GlassmorphicCard extends StatelessWidget {
  final Widget child;

  const _GlassmorphicCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Premium button with gradient and loading state
class _PremiumButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  const _PremiumButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1F7FB8),
            const Color(0xFF1565A0),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F7FB8).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading) ...[
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(
                        Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ] else
                  const Icon(Icons.login, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Premium parent login form with glassmorphic card
class _PremiumParentForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final bool loading;
  final bool obscure;
  final String? statusMessage;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final VoidCallback onHelpTap;

  const _PremiumParentForm({
    super.key,
    required this.formKey,
    required this.phoneController,
    required this.passwordController,
    required this.loading,
    required this.obscure,
    required this.statusMessage,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onHelpTap,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassmorphicCard(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Parent Login',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Secure access to your child\'s information',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF79747E),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Phone field with +91 prefix
            TextFormField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: _buildModernInputDecoration(
                context,
                label: 'Mobile number',
                hint: '10000 00000',
                icon: Icons.phone_android,
                prefix: '+91 ',
              ),
              validator: (value) {
                final v = (value ?? '').trim();
                final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                if (digits.isEmpty) return 'Enter mobile number';
                if (digits.length != 10) return 'Enter a valid 10-digit number';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Password field
            TextFormField(
              controller: passwordController,
              obscureText: obscure,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => loading ? null : onSubmit(),
              decoration: _buildModernInputDecoration(
                context,
                label: 'Password',
                icon: Icons.lock_outline,
                suffixIcon: IconButton(
                  icon: Icon(
                    obscure ? Icons.visibility_off : Icons.visibility,
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
              onPressed: loading ? null : onSubmit,
            ),

            // Parent status message
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
    String? prefix,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF79747E)),
      prefix: prefix != null ? Text(prefix) : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF5F5F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFE0E0E0),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFF1F7FB8),
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

/// Premium email login form (for teacher, admin, student)
class _PremiumEmailForm extends StatelessWidget {
  final String title;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool loading;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final VoidCallback onHelpTap;

  const _PremiumEmailForm({
    super.key,
    required this.title,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.loading,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onHelpTap,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassmorphicCard(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Access your portal securely',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF79747E),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Email field
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: _buildModernInputDecoration(
                context,
                label: 'Email address',
                icon: Icons.alternate_email,
              ),
              validator: (value) {
                final v = (value ?? '').trim();
                if (v.isEmpty) return 'Enter email';
                if (!v.contains('@')) return 'Enter valid email';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Password field
            TextFormField(
              controller: passwordController,
              obscureText: obscure,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => loading ? null : onSubmit(),
              decoration: _buildModernInputDecoration(
                context,
                label: 'Password',
                icon: Icons.lock_outline,
                suffixIcon: IconButton(
                  icon: Icon(
                    obscure ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                  ),
                  onPressed: onToggleObscure,
                ),
              ),
              validator: (value) {
                if ((value ?? '').isEmpty) return 'Enter password';
                if ((value ?? '').length < 6) return 'Password too short';
                return null;
              },
            ),
            const SizedBox(height: 18),

            // Sign in button
            _PremiumButton(
              label: 'Sign in',
              loading: loading,
              onPressed: loading ? null : onSubmit,
            ),

            const SizedBox(height: 12),

            // Forgot password text button
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password reset coming soon')),
                );
              },
              child: const Text('Forgot password?'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1F7FB8),
              ),
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
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF79747E)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF5F5F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFE0E0E0),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFF1F7FB8),
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

/// Premium footer with branding
class _PremiumFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 1,
          color: Colors.black.withValues(alpha: 0.06),
        ),
        const SizedBox(height: 16),
        Text(
          '© 2026 Hongirana School',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF99A3A0),
                fontSize: 12,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'v1.0.0',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFFB3B9B8),
                fontSize: 11,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
