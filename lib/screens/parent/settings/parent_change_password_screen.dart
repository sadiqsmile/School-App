import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/core_providers.dart';
import '../../../widgets/loading_view.dart';

class ParentChangePasswordScreen extends ConsumerStatefulWidget {
  const ParentChangePasswordScreen({super.key});

  @override
  ConsumerState<ParentChangePasswordScreen> createState() => _ParentChangePasswordScreenState();
}

class _ParentChangePasswordScreenState extends ConsumerState<ParentChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _old = TextEditingController();
  final _new1 = TextEditingController();
  final _new2 = TextEditingController();

  bool _saving = false;
  bool _obscureOld = true;
  bool _obscureNew1 = true;
  bool _obscureNew2 = true;

  @override
  void dispose() {
    _old.dispose();
    _new1.dispose();
    _new2.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      await ref.read(authServiceProvider).changeMyParentPassword(
            oldPassword: _old.text,
            newPassword: _new1.text,
          );

      if (!mounted) return;
      _snack('Password updated');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: _saving
          ? const Center(child: LoadingView(message: 'Updating…'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Update your password',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _old,
                            obscureText: _obscureOld,
                            decoration: InputDecoration(
                              labelText: 'Old password',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscureOld = !_obscureOld),
                                icon: Icon(_obscureOld ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              ),
                            ),
                            validator: (v) => (v ?? '').trim().isEmpty ? 'Old password is required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _new1,
                            obscureText: _obscureNew1,
                            decoration: InputDecoration(
                              labelText: 'New password',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.lock_reset_outlined),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscureNew1 = !_obscureNew1),
                                icon: Icon(_obscureNew1 ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              ),
                            ),
                            validator: (v) {
                              final s = (v ?? '').trim();
                              if (s.isEmpty) return 'New password is required';
                              if (s.length < 6) return 'Use at least 6 characters';
                              if (s == _old.text.trim()) return 'New password must be different';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _new2,
                            obscureText: _obscureNew2,
                            decoration: InputDecoration(
                              labelText: 'Confirm new password',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.lock_reset_outlined),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscureNew2 = !_obscureNew2),
                                icon: Icon(_obscureNew2 ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              ),
                            ),
                            validator: (v) {
                              final s = (v ?? '').trim();
                              if (s.isEmpty) return 'Please confirm new password';
                              if (s != _new1.text.trim()) return 'Passwords do not match';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: _submit,
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Update password'),
                            ),
                          ),
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
