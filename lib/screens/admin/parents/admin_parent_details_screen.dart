import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/loading_view.dart';

class AdminParentDetailsScreen extends ConsumerStatefulWidget {
  const AdminParentDetailsScreen({super.key, required this.mobile});

  final String mobile;

  @override
  ConsumerState<AdminParentDetailsScreen> createState() => _AdminParentDetailsScreenState();
}

class _AdminParentDetailsScreenState extends ConsumerState<AdminParentDetailsScreen> {
  bool _busy = false;

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _resetToLast4() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset parent password?'),
        content: const Text('This will reset the parent password to the last 4 digits of their mobile number.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset')),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final res = await ref.read(adminServiceProvider).resetParentPasswordToDefault(mobile: widget.mobile);
      if (!mounted) return;
      _snack('Password reset. New password: ${res.isEmpty ? '(hidden)' : res}');
    } catch (e) {
      if (!mounted) return;
      _snack('Reset failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final refDoc = FirebaseFirestore.instance
        .collection('schools')
        .doc(AppConfig.schoolId)
        .collection('parents')
        .doc(widget.mobile);

    return Scaffold(
      appBar: AppBar(title: const Text('Parent Details')),
      body: _busy
          ? const Center(child: LoadingView(message: 'Working…'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: refDoc.snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: LoadingView(message: 'Loading…'));
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final doc = snap.data;
                if (doc == null || !doc.exists) {
                  return const Center(child: Text('Parent not found'));
                }

                final data = doc.data() ?? const <String, dynamic>{};
                final displayName = (data['displayName'] as String?) ?? 'Parent';
                final mobile = (data['mobile'] as String?) ?? (data['phone'] as String?) ?? widget.mobile;
                final isActive = (data['isActive'] ?? false) == true;
                final children = (data['children'] is List) ? (data['children'] as List).whereType<String>().toList() : <String>[];

                final hasHash = ((data['passwordHash'] ?? '').toString().trim().isNotEmpty);
                final hasPlain = ((data['password'] ?? '').toString().trim().isNotEmpty);

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('Mobile: $mobile\nChildren: ${children.length}\nActive: ${isActive ? 'Yes' : 'No'}'),
                        isThreeLine: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Security',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text('Has hash: ${hasHash ? 'Yes' : 'No'}'),
                            Text('Has legacy plaintext: ${hasPlain ? 'Yes (should migrate)' : 'No'}'),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 48,
                              child: FilledButton.icon(
                                onPressed: _resetToLast4,
                                icon: const Icon(Icons.lock_reset_outlined),
                                label: const Text('Reset password (last 4 digits)'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
