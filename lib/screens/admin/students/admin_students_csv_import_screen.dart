import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/csv/students_csv.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/loading_view.dart';

class AdminStudentsCsvImportScreen extends ConsumerStatefulWidget {
  const AdminStudentsCsvImportScreen({
    super.key,
    required this.parseResult,
  });

  final StudentsCsvParseResult parseResult;

  @override
  ConsumerState<AdminStudentsCsvImportScreen> createState() => _AdminStudentsCsvImportScreenState();
}

class _AdminStudentsCsvImportScreenState extends ConsumerState<AdminStudentsCsvImportScreen> {
  bool _importing = false;
  int _done = 0;
  int _total = 0;
  String? _status;

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _runImport() async {
    final issues = widget.parseResult.issues;
    if (issues.isNotEmpty) {
      _snack('Fix CSV errors before importing');
      return;
    }

    final rows = widget.parseResult.rows;
    if (rows.isEmpty) {
      _snack('No rows to import');
      return;
    }

    setState(() {
      _importing = true;
      _done = 0;
      _total = rows.length;
      _status = 'Starting…';
    });

    try {
      final report = await ref.read(studentCsvImportServiceProvider).importStudents(
            rows: rows,
            onProgress: (done, total) {
              if (!mounted) return;
              setState(() {
                _done = done;
                _total = total;
                _status = 'Processing $done / $total';
              });
            },
          );

      if (!mounted) return;

      final failures = report.results.where((x) => !x.success).toList();
      final ok = report.successCount;

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Import finished'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Success: $ok'),
                    Text('Failed: ${report.failureCount}'),
                    const SizedBox(height: 12),
                    if (failures.isNotEmpty) ...[
                      const Text('Row errors:', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      for (final f in failures.take(50))
                        Text('Row ${f.rowNumber}: ${f.message}', style: const TextStyle(fontSize: 12)),
                      if (failures.length > 50)
                        Text('…and ${failures.length - 50} more', style: const TextStyle(fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          );
        },
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _snack('Import failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _importing = false;
          _status = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final issues = widget.parseResult.issues;
    final rows = widget.parseResult.rows;

    final hasIssues = issues.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Import Students CSV')),
      body: _importing
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LoadingView(message: 'Importing…'),
                    const SizedBox(height: 12),
                    if (_total > 0)
                      LinearProgressIndicator(value: (_done / _total).clamp(0.0, 1.0)),
                    const SizedBox(height: 8),
                    if (_status != null) Text(_status!, textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Preview',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Text('Rows found: ${rows.length}'),
                        const SizedBox(height: 12),
                        if (hasIssues) ...[
                          Text(
                            'CSV errors (${issues.length})',
                            style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          for (final i in issues.take(50))
                            Text('Row ${i.rowNumber}: ${i.message}', style: const TextStyle(fontSize: 12)),
                          if (issues.length > 50)
                            Text('…and ${issues.length - 50} more', style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 12),
                        ] else ...[
                          const Text(
                            'Looks good. Import will create/update students and auto-create missing parents (default password = last 4 digits).',
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _runImport,
                            icon: const Icon(Icons.upload_file),
                            label: Text('Import ${rows.length} row(s)'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (rows.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'First ${rows.length < 20 ? rows.length : 20} rows',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          for (final r in rows.take(20))
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text('${r.name}  (Adm: ${r.admissionNo})'),
                              subtitle: Text('Class: ${r.classId}-${r.sectionId} • Group: ${r.groupId} • Parent: ${r.parentMobile}'),
                              trailing: Icon(
                                r.isActive ? Icons.check_circle_outline : Icons.pause_circle_outline,
                                color: r.isActive ? Colors.green : Colors.orange,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
