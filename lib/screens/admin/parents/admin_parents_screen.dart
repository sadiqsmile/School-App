import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../providers/core_providers.dart';
import '../../../widgets/loading_view.dart';
import '../../../features/csv/parents_csv.dart';
import '../../../utils/csv_saver.dart';
import 'admin_parent_details_screen.dart';
import 'admin_parents_csv_import_screen.dart';
import 'admin_parent_approvals_screen.dart';

enum _ParentCsvAction {
  export,
  import,
}

class AdminParentsScreen extends ConsumerStatefulWidget {
  const AdminParentsScreen({super.key});

  @override
  ConsumerState<AdminParentsScreen> createState() => _AdminParentsScreenState();
}

class _AdminParentsScreenState extends ConsumerState<AdminParentsScreen> {
  bool _creating = false;

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _exportParentsCsv() async {
    try {
      final rows = await ref.read(parentCsvImportServiceProvider).exportParentsForCsv();
      final csvText = buildParentsCsv(parents: rows);

      final now = DateTime.now();
      final y = now.year.toString().padLeft(4, '0');
      final m = now.month.toString().padLeft(2, '0');
      final d = now.day.toString().padLeft(2, '0');
      final fileName = 'parents_$y$m$d.csv';

      await saveCsvText(fileName: fileName, csvText: csvText);

      if (!mounted) return;
      _snack('CSV exported');
    } catch (e) {
      if (!mounted) return;
      _snack('Export failed: $e');
    }
  }

  Future<void> _importParentsCsv() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
      if (res == null || res.files.isEmpty) return;
      final f = res.files.first;
      final bytes = f.bytes;
      if (bytes == null) {
        _snack('Could not read the selected file. Please try again.');
        return;
      }

      final parsed = parseParentsCsvBytes(bytes: bytes);
      if (!mounted) return;
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => AdminParentsCsvImportScreen(parseResult: parsed),
        ),
      );
      if (!mounted) return;
      if (ok == true) _snack('Import complete');
    } catch (e) {
      if (!mounted) return;
      _snack('Import failed: $e');
    }
  }

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
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AdminParentApprovalsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.how_to_reg),
                label: const Text('Approvals'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<_ParentCsvAction>(
                tooltip: 'CSV actions',
                onSelected: (action) {
                  switch (action) {
                    case _ParentCsvAction.export:
                      _exportParentsCsv();
                      break;
                    case _ParentCsvAction.import:
                      _importParentsCsv();
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _ParentCsvAction.export,
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.download_outlined),
                      title: Text('Export CSV'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _ParentCsvAction.import,
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.upload_file_outlined),
                      title: Text('Import CSV'),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
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
                      onTap: () => _open(
                        context,
                        AdminParentDetailsScreen(mobile: doc.id),
                      ),
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
