import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/csv/teacher_assignments_csv.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/loading_view.dart';

class AdminTeacherAssignmentsCsvImportScreen extends ConsumerStatefulWidget {
  const AdminTeacherAssignmentsCsvImportScreen({
    super.key,
    required this.parseResult,
  });

  final TeacherAssignmentsCsvParseResult parseResult;

  @override
  ConsumerState<AdminTeacherAssignmentsCsvImportScreen> createState() =>
      _AdminTeacherAssignmentsCsvImportScreenState();
}

class _AdminTeacherAssignmentsCsvImportScreenState
    extends ConsumerState<AdminTeacherAssignmentsCsvImportScreen> {
  bool _importing = false;
  int _done = 0;
  int _total = 0;
  String? _status;
  bool _replaceExisting = true;

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
      final report = await ref.read(teacherAssignmentCsvImportServiceProvider)
          .importTeacherAssignments(
            rows: rows,
            replaceExisting: _replaceExisting,
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
      appBar: AppBar(title: const Text('Import Teacher Assignments CSV')),
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
                          'Review & Confirm',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        if (hasIssues)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CSV has ${issues.length} error(s):',
                                  style: TextStyle(
                                    color: Colors.red.shade900,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                for (final issue in issues.take(10))
                                  Text(
                                    '• ${issue.message}',
                                    style: TextStyle(color: Colors.red.shade900),
                                  ),
                                if (issues.length > 10)
                                  Text(
                                    '• …and ${issues.length - 10} more',
                                    style: TextStyle(color: Colors.red.shade900),
                                  ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '✓ CSV is valid. ${rows.length} teacher(s) will be processed.',
                              style: TextStyle(
                                color: Colors.green.shade900,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        if (!hasIssues) ...[
                          CheckboxListTile(
                            value: _replaceExisting,
                            onChanged: (v) {
                              setState(() => _replaceExisting = v ?? true);
                            },
                            title: const Text('Replace existing assignments'),
                            subtitle: const Text(
                              'If unchecked, new assignments will be added to existing ones',
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Text(
                          'Preview (first 10 rows):',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Teacher UID')),
                              DataColumn(label: Text('Class/Section IDs')),
                            ],
                            rows: [
                              for (final row in rows.take(10))
                                DataRow(cells: [
                                  DataCell(Text(row.teacherUid, maxLines: 2, overflow: TextOverflow.ellipsis)),
                                  DataCell(SizedBox(
                                    width: 200,
                                    child: Text(
                                      row.classSectionIds.join(', '),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  )),
                                ]),
                            ],
                          ),
                        ),
                        if (rows.length > 10)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '…and ${rows.length - 10} more rows',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: hasIssues ? null : _runImport,
                      child: const Text('Import'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
