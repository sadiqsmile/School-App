import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/core_providers.dart';
import '../../../widgets/loading_view.dart';
import 'parent_change_password_screen.dart';
import '../../../providers/auth_providers.dart';
import '../../../utils/parent_auth_email.dart';

class ParentSettingsScreen extends ConsumerWidget {
  const ParentSettingsScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUserAsync = ref.watch(firebaseAuthUserProvider);
    final authUser = authUserAsync.asData?.value;
    final mobile = tryExtractMobileFromParentEmail(authUser?.email);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: authUserAsync.isLoading
          ? const Center(child: LoadingView(message: 'Loading…'))
          : (authUser == null || mobile == null)
              ? const Center(child: Text('Please login again.'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.phone_android_outlined),
                        title: const Text('Parent mobile'),
                        subtitle: Text(mobile),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.lock_outline),
                        title: const Text('Change Password'),
                        subtitle: const Text('Update your password securely'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _open(context, const ParentChangePasswordScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.logout),
                        title: const Text('Sign out'),
                        onTap: () async {
                          await ref.read(authServiceProvider).signOut();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed out')));
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
