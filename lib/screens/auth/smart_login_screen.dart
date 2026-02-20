import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../providers/core_providers.dart';
import '../../config/app_config.dart';
import '../../utils/app_animations.dart';

class SmartLoginScreen extends ConsumerStatefulWidget {
  const SmartLoginScreen({super.key});

  @override
  ConsumerState<SmartLoginScreen> createState() => _SmartLoginScreenState();
}

class _SmartLoginScreenState extends ConsumerState<SmartLoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _statusMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _isMobileNumber(String input) {
    final cleaned = input.trim().replaceAll(RegExp(r'\D'), '');
    return cleaned.length == 10 && int.tryParse(cleaned) != null;
  }

  bool _isEmail(String input) {
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return emailRegex.hasMatch(input.trim());
  }

  String _prettyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return 'Invalid username or password. Please try again.';
        case 'user-disabled':
          return 'This account is disabled. Contact administration.';
        case 'too-many-requests':
          return 'Too many failed attempts. Please try again later.';
        case 'network-request-failed':
          return 'Network error. Check your internet connection.';
        case 'invalid-email':
          return 'Invalid email format.';
        default:
          return e.message ?? 'Login failed. Please try again.';
      }
    }
    final msg = e.toString();
    if (msg.contains('Exception: ')) {
      return msg.replaceFirst('Exception: ', '');
    }
    return msg;
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _statusMessage = 'Signing in...';
    });

    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text;

      if (_isMobileNumber(username)) {
        // Parent login
        await _loginAsParent(username, password);
      } else if (_isEmail(username)) {
        // Staff login (Teacher/Admin/Viewer)
        await _loginAsStaff(username, password);
      } else {
        throw Exception('Please enter a valid mobile number or email address');
      }

      if (mounted) context.go('/');
    } catch (e) {
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

  Future<void> _loginAsParent(String mobile, String password) async {
    setState(() => _statusMessage = 'Logging in as Parent...');
    
    await ref.read(authServiceProvider).signInParent(
      phoneNumber: mobile,
      password: password,
      onStatus: (m) {
        if (!mounted) return;
        setState(() => _statusMessage = m);
      },
    );
  }

  Future<void> _loginAsStaff(String email, String password) async {
    setState(() => _statusMessage = 'Verifying credentials...');
    
    // Sign in with Firebase Auth
    await ref.read(authServiceProvider).signInEmail(
      email: email,
      password: password,
    );

    // Role detection happens automatically in app_router.dart
    // based on the user's Firestore profile
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your mobile number or email';
    }
    final trimmed = value.trim();
    if (!_isMobileNumber(trimmed) && !_isEmail(trimmed)) {
      return 'Enter a valid 10-digit mobile or email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 4) {
      return 'Password must be at least 4 characters';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final isDesktop = screenWidth >= 1000;
    final isTablet = screenWidth >= 600 && screenWidth < 1000;
    final maxContentWidth = isDesktop ? 480.0 : (isTablet ? 460.0 : 400.0);

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
          // Premium gradient background
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

          // Animated floating blobs
          _AnimatedBlob(
            color: Colors.blue.shade200,
            top: -100,
            left: -100,
            size: 300,
            duration: const Duration(seconds: 8),
          ),
          _AnimatedBlob(
            color: Colors.purple.shade200,
            bottom: -150,
            right: -150,
            size: 350,
            duration: const Duration(seconds: 10),
          ),

          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: (screenWidth - maxContentWidth).clamp(20, 60) / 2,
                  vertical: 24,
                ),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo/App Icon
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade600, Colors.purple.shade600],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.shade300.withOpacity(0.5),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.school,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // App Title
                      Text(
                        'School Management',
                        style: TextStyle(
                          fontSize: isDesktop ? 32 : 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to continue',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Login Card
                      _GlassmorphicCard(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Smart hint
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.blue.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 20,
                                        color: Colors.blue.shade700,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Enter mobile number (Parent) or email (Staff)',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Username field
                                TextFormField(
                                  controller: _usernameController,
                                  enabled: !_loading,
                                  validator: _validateUsername,
                                  decoration: InputDecoration(
                                    labelText: 'Mobile Number or Email',
                                    hintText: '9876543210 or email@example.com',
                                    prefixIcon: const Icon(Icons.person_outline),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                ),
                                const SizedBox(height: 20),

                                // Password field
                                TextFormField(
                                  controller: _passwordController,
                                  enabled: !_loading,
                                  obscureText: _obscurePassword,
                                  validator: _validatePassword,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    hintText: 'Enter your password',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                      ),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _handleLogin(),
                                ),
                                const SizedBox(height: 12),

                                // Forgot password
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _loading ? null : () {
                                      _snack('Please contact school administration to reset your password');
                                    },
                                    child: const Text('Forgot Password?'),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Status message
                                if (_statusMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              Colors.blue.shade700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _statusMessage!,
                                            style: TextStyle(
                                              color: Colors.blue.shade700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],

                                // Login button
                                SizedBox(
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade600,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 2,
                                      shadowColor: Colors.blue.shade300,
                                    ),
                                    child: _loading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                            ),
                                          )
                                        : const Text(
                                            'Sign In',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Help text
                      TextButton.icon(
                        onPressed: _loading ? null : () {
                          showDialog(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Need Help?'),
                              content: const Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Login Instructions:',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 12),
                                  Text('• Parents: Use your 10-digit mobile number'),
                                  SizedBox(height: 4),
                                  Text('• Staff: Use your email address'),
                                  SizedBox(height: 4),
                                  Text('• Default password: Last 4 digits of mobile (Parents)'),
                                  SizedBox(height: 16),
                                  Text(
                                    'Need Support?',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 8),
                                  Text('Contact school administration'),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.help_outline, size: 20),
                        label: const Text('Need help signing in?'),
                      ),

                      // Footer
                      const SizedBox(height: 32),
                      Text(
                        '© 2026 School Management System',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                        textAlign: TextAlign.center,
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
}

// Glassmorphic card
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
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.9),
                Colors.white.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// Animated floating blob
class _AnimatedBlob extends StatefulWidget {
  final Color color;
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final double size;
  final Duration duration;

  const _AnimatedBlob({
    required this.color,
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.size,
    required this.duration,
  });

  @override
  State<_AnimatedBlob> createState() => _AnimatedBlobState();
}

class _AnimatedBlobState extends State<_AnimatedBlob>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.top,
      bottom: widget.bottom,
      left: widget.left,
      right: widget.right,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + (_controller.value * 0.1),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.color.withOpacity(0.4),
                    widget.color.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
