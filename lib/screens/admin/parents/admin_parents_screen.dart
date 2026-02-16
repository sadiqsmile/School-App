import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/core_providers.dart';

import '../../../widgets/loading_view.dart';

class AdminParentsScreen extends ConsumerStatefulWidget {
  const AdminParentsScreen({super.key});

  @override
  ConsumerState<AdminParentsScreen> createState() => _AdminParentsScreenState();
}

class _AdminParentsScreenState extends ConsumerState<AdminParentsScreen> {
  bool _creating = false;

  Future<void> _createParentDialog() async {
    final phoneController = TextEditingController();
    final nameController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Parent Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Parent name'),
              ),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Mobile number'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Default password = last 4 digits of mobile number',
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
          ],
        );
      },
    );

    if (ok != true) return;

    final phone = phoneController.text.trim();
    final name = nameController.text.trim();
    if (phone.isEmpty || name.isEmpty) return;

    setState(() => _creating = true);
    try {
      final res = await ref.read(adminServiceProvider).createParent(
            phone: phone,
            displayName: name,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Parent created. Mobile: ${res.mobile}  Password: ${res.defaultPassword.isEmpty ? "(hidden)" : res.defaultPassword}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Create failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parentsStream = ref.read(adminDataServiceProvider).watchParents();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Parents',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.icon(
                onPressed: _creating ? null : _createParentDialog,
                icon: const Icon(Icons.add),
                label: const Text('Create'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder(
            stream: parentsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: LoadingView(message: 'Loading parents…'));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final docs = snapshot.data?.docs ?? const [];
              if (docs.isEmpty) {
                return const Center(child: Text('No parents yet.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  final name = (data['displayName'] as String?) ?? 'Parent';
                  final phone = (data['phone'] as String?) ?? '-';

                  return Card(
                    child: ListTile(
                      title: Text(name),
                      subtitle: Text(phone),
                      trailing: Text(doc.id, style: Theme.of(context).textTheme.bodySmall),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
