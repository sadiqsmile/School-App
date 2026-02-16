import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/core_providers.dart';

import '../../widgets/auth_shell.dart';

enum LoginTab { parent, teacher, admin }

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

  bool get _anyLoading => _parentLoading || _teacherLoading || _adminLoading;

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

    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signInParent() async {
    if (!(_parentFormKey.currentState?.validate() ?? false)) return;
    setState(() => _parentLoading = true);
    try {
      await ref.read(authServiceProvider).signInParent(
            phoneNumber: _parentPhoneController.text.trim(),
            password: _parentPasswordController.text,
          );
      // Parent login does not use Firebase Auth, so we navigate explicitly.
      if (mounted) {
        context.go('/parent');
      }
    } catch (e) {
      if (!mounted) return;
      _snack('Login failed: $e');
    } finally {
      if (mounted) setState(() => _parentLoading = false);
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
      _snack('Login failed: $e');
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
      _snack('Login failed: $e');
    } finally {
      if (mounted) setState(() => _adminLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'School App',
      subtitle: 'Sign in to continue',
      footer: [
        Text(
          _tab == LoginTab.parent
              ? 'Tip: Default parent password is the last 4 digits of the mobile number.'
              : 'Use the account created by the Admin.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Welcome back',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Select your role and sign in.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            _RolePills(
              value: _tab,
              onChanged: _anyLoading ? null : (v) => setState(() => _tab = v),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: switch (_tab) {
                LoginTab.parent => _ParentForm(
                    key: const ValueKey('parent'),
                    formKey: _parentFormKey,
                    phoneController: _parentPhoneController,
                    passwordController: _parentPasswordController,
                    loading: _parentLoading,
                    obscure: _parentObscure,
                    onToggleObscure: () => setState(() => _parentObscure = !_parentObscure),
                    onSubmit: _signInParent,
                  ),
                LoginTab.teacher => _EmailForm(
                    key: const ValueKey('teacher'),
                    title: 'Teacher Login',
                    formKey: _teacherFormKey,
                    emailController: _teacherEmailController,
                    passwordController: _teacherPasswordController,
                    loading: _teacherLoading,
                    obscure: _teacherObscure,
                    onToggleObscure: () => setState(() => _teacherObscure = !_teacherObscure),
                    onSubmit: _signInTeacher,
                  ),
                LoginTab.admin => _EmailForm(
                    key: const ValueKey('admin'),
                    title: 'Admin Login',
                    formKey: _adminFormKey,
                    emailController: _adminEmailController,
                    passwordController: _adminPasswordController,
                    loading: _adminLoading,
                    obscure: _adminObscure,
                    onToggleObscure: () => setState(() => _adminObscure = !_adminObscure),
                    onSubmit: _signInAdmin,
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RolePills extends StatelessWidget {
  const _RolePills({required this.value, required this.onChanged});

  final LoginTab value;
  final ValueChanged<LoginTab>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Light, distinct pastel colors per role.
    const parentBg = Color(0xFFE3F2FD);
    const parentBorder = Color(0xFF90CAF9);
    const parentSelectedBg = Color(0xFFBBDEFB);
    const parentSelectedBorder = Color(0xFF42A5F5);

    const teacherBg = Color(0xFFE8F5E9);
    const teacherBorder = Color(0xFFA5D6A7);
    const teacherSelectedBg = Color(0xFFC8E6C9);
    const teacherSelectedBorder = Color(0xFF43A047);

    const adminBg = Color(0xFFFFF3E0);
    const adminBorder = Color(0xFFFFCC80);
    const adminSelectedBg = Color(0xFFFFE0B2);
    const adminSelectedBorder = Color(0xFFFB8C00);

    Widget pill({
      required LoginTab tab,
      required String label,
      required IconData icon,
      required Color baseBg,
      required Color baseBorder,
      required Color selectedBg,
      required Color selectedBorder,
    }) {
      final selected = value == tab;

      final bg = selected ? selectedBg : baseBg;
      final border = selected ? selectedBorder : baseBorder;
      final fg = selected ? scheme.onSurface : scheme.onSurface;

      return Expanded(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onChanged == null ? null : () => onChanged!(tab),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: fg),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: fg,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.1,
                            ),
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

    return Row(
      children: [
        pill(
          tab: LoginTab.parent,
          label: 'Parent',
          icon: Icons.family_restroom,
          baseBg: parentBg,
          baseBorder: parentBorder,
          selectedBg: parentSelectedBg,
          selectedBorder: parentSelectedBorder,
        ),
        const SizedBox(width: 10),
        pill(
          tab: LoginTab.teacher,
          label: 'Teacher',
          icon: Icons.school_outlined,
          baseBg: teacherBg,
          baseBorder: teacherBorder,
          selectedBg: teacherSelectedBg,
          selectedBorder: teacherSelectedBorder,
        ),
        const SizedBox(width: 10),
        pill(
          tab: LoginTab.admin,
          label: 'Admin',
          icon: Icons.admin_panel_settings_outlined,
          baseBg: adminBg,
          baseBorder: adminBorder,
          selectedBg: adminSelectedBg,
          selectedBorder: adminSelectedBorder,
        ),
      ],
    );
  }
}

class _ParentForm extends StatelessWidget {
  const _ParentForm({
    super.key,
    required this.formKey,
    required this.phoneController,
    required this.passwordController,
    required this.loading,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final bool loading;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    InputDecoration deco({required String label, required IconData icon, Widget? suffixIcon}) {
      return InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.75)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.75)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      );
    }

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Parent Login',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: deco(label: 'Mobile number', icon: Icons.phone_android),
            validator: (value) {
              final v = (value ?? '').trim();
              if (v.isEmpty) return 'Enter mobile number';
              if (v.length < 8) return 'Enter a valid mobile number';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: passwordController,
            obscureText: obscure,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => loading ? null : onSubmit(),
            decoration: deco(
              label: 'Password',
              icon: Icons.lock_outline,
              suffixIcon: IconButton(
                tooltip: obscure ? 'Show password' : 'Hide password',
                onPressed: onToggleObscure,
                icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
              ),
            ),
            validator: (value) {
              if ((value ?? '').isEmpty) return 'Enter password';
              if ((value ?? '').length < 4) return 'Password is too short';
              return null;
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: loading ? null : onSubmit,
              icon: loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: const Text('Sign in'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmailForm extends StatelessWidget {
  const _EmailForm({
    super.key,
    required this.title,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.loading,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSubmit,
  });

  final String title;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool loading;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    InputDecoration deco({required String label, required IconData icon, Widget? suffixIcon}) {
      return InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.75)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.75)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      );
    }

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: deco(label: 'Email', icon: Icons.alternate_email),
            validator: (value) {
              final v = (value ?? '').trim();
              if (v.isEmpty) return 'Enter email';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: passwordController,
            obscureText: obscure,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => loading ? null : onSubmit(),
            decoration: deco(
              label: 'Password',
              icon: Icons.lock_outline,
              suffixIcon: IconButton(
                tooltip: obscure ? 'Show password' : 'Hide password',
                onPressed: onToggleObscure,
                icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
              ),
            ),
            validator: (value) {
              if ((value ?? '').isEmpty) return 'Enter password';
              if ((value ?? '').length < 6) return 'Password is too short';
              return null;
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: loading ? null : onSubmit,
              icon: loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: const Text('Sign in'),
            ),
          ),
        ],
      ),
    );
  }
}
