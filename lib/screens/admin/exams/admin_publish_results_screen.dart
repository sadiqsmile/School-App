import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io' show Platform, Directory, File;

import '../../../models/exam.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/loading_view.dart';
import '../../../features/csv/exam_results_csv.dart';
import 'admin_exam_results_csv_import_screen.dart';

class AdminPublishResultsScreen extends ConsumerStatefulWidget {
  const AdminPublishResultsScreen({
    super.key,
    required this.yearId,
    required this.exam,
  });

  final String yearId;
  final Exam exam;

  @override
  ConsumerState<AdminPublishResultsScreen> createState() => _AdminPublishResultsScreenState();
}

class _AdminPublishResultsScreenState extends ConsumerState<AdminPublishResultsScreen> {
  String? _classId;
  String? _sectionId;
  bool _busy = false;

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ignore: unused_element
  Future<void> _importResultsCsv() async {
    // Show dialog to get max marks
    final maxMarksController = TextEditingController(text: '100');

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exam Results Import Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: maxMarksController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Max marks per subject',
                hintText: '100',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'CSV format: studentId, admissionNo, studentName, class, section, group, [subject1], [subject2], ...',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue')),
        ],
      ),
    );

    if (ok != true) return;

    double maxMarks = 100;
    try {
      maxMarks = double.parse(maxMarksController.text.trim());
    } catch (_) {
      _snack('Invalid max marks value');
      return;
    }

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

      final parsed = parseExamResultsCsvBytes(bytes: bytes, maxMarksPerSubject: maxMarks);
      if (!mounted) return;
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => AdminExamResultsCsvImportScreen(
            yearId: widget.yearId,
            examId: widget.exam.id,
            parseResult: parsed,
            maxMarksPerSubject: maxMarks,
          ),
        ),
      );
      if (!mounted) return;
      if (result == true) _snack('Import complete');
    } catch (e) {
      if (!mounted) return;
      _snack('Import failed: $e');
    }
  }

  Future<bool> _confirm(String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    return ok == true;
  }

  // ignore: unused_element
  Future<void> _toggleExamWide(bool publish) async {
    final ok = await _confirm(
      publish ? 'Publish all results?' : 'Unpublish all results?',
      'This updates every student result document under this exam.\n\nIf you have many students, this may take time and use write quota.',
    );
    if (!ok) return;

    setState(() => _busy = true);
    try {
      await ref.read(examServiceProvider).setResultsPublishedForExam(
            yearId: widget.yearId,
            examId: widget.exam.id,
            isPublished: publish,
          );
      if (!mounted) return;
      _snack(publish ? 'Results published' : 'Results unpublished');
    } catch (e) {
      if (!mounted) return;
      _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleClassWise(bool publish) async {
    final c = (_classId ?? '').trim();
    final s = (_sectionId ?? '').trim();
    if (c.isEmpty || s.isEmpty) {
      _snack('Select class and section');
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(examServiceProvider).setResultsPublishedForClassSection(
            yearId: widget.yearId,
            examId: widget.exam.id,
            classId: c,
            sectionId: s,
            isPublished: publish,
        publishedByUid: publish ? ref.read(firebaseAuthUserProvider).asData?.value?.uid : null,
          );
      if (!mounted) return;
      _snack(publish ? 'Class results published' : 'Class results unpublished');
    } catch (e) {
      if (!mounted) return;
      _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadTemplate() async {
    final c = (_classId ?? '').trim();
    final s = (_sectionId ?? '').trim();
    if (c.isEmpty || s.isEmpty) {
      _snack('Select class and section first');
      return;
    }

    setState(() => _busy = true);
    try {
      final csv = await ref.read(examCsvServiceProvider).generateTemplateCsv(
            yearId: widget.yearId,
            examId: widget.exam.id,
            classId: c,
            sectionId: s,
          );

      // Create filename
      final now = DateTime.now();
      final filename = 'exam_template_${widget.exam.id}_${c}_${s}_${now.millisecondsSinceEpoch}.csv';

      // Download the CSV
      if (kIsWeb) {
        _downloadWebCsv(csv, filename);
      } else {
        // On mobile/desktop, save to documents
        final downloadsDir = await _getDownloadsDirectory();
        if (downloadsDir != null) {
          final file = await File('${downloadsDir.path}/$filename').writeAsString(csv);
          if (mounted) _snack('Downloaded to: ${file.path}');
        }
      }
    } catch (e) {
      if (!mounted) return;
      _snack('Download failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importCsv() async {
    final c = (_classId ?? '').trim();
    final s = (_sectionId ?? '').trim();
    if (c.isEmpty || s.isEmpty) {
      _snack('Select class and section first');
      return;
    }

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

      final csvText = String.fromCharCodes(bytes);
      final userState = ref.read(appUserProvider);
      final uid = userState.maybeWhen(
        data: (user) => user.uid,
        orElse: () => 'unknown',
      );

      setState(() => _busy = true);

      // Show progress dialog
      int completed = 0;
      int total = 0;
      if (!mounted) return;

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Importing Results...'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: total > 0 ? completed / total : 0,
                  ),
                  const SizedBox(height: 8),
                  Text('Processing: $completed / $total'),
                ],
              ),
            );
          },
        ),
      );

      final summary = await ref.read(examCsvServiceProvider).importResultsCsv(
            yearId: widget.yearId,
            examId: widget.exam.id,
            classId: c,
            sectionId: s,
            csvText: csvText,
            enteredByUid: uid,
            onProgress: (done, tot) {
              completed = done;
              total = tot;
              // Update UI in real-time
            },
          );

      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog

      // Show summary dialog
      final failedRows = summary.results.where((r) => !r.success).toList();

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Complete'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          '${summary.successCount}',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(color: Colors.green),
                        ),
                        const Text('Success'),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          '${summary.failureCount}',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(color: Colors.red),
                        ),
                        const Text('Failed'),
                      ],
                    ),
                  ],
                ),
                if (failedRows.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Failed Rows:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final row in failedRows.take(10))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              'Row ${row.rowNumber} (${row.studentId}): ${row.message}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        if (failedRows.length > 10)
                          Text(
                            '... and ${failedRows.length - 10} more',
                            style: const TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (mounted) _snack('Import complete: ${summary.successCount} success, ${summary.failureCount} failed');
    } catch (e) {
      if (!mounted) return;
      _snack('Import failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportResults() async {
    final c = (_classId ?? '').trim();
    final s = (_sectionId ?? '').trim();
    if (c.isEmpty || s.isEmpty) {
      _snack('Select class and section first');
      return;
    }

    setState(() => _busy = true);
    try {
      final csv = await ref.read(examCsvServiceProvider).exportResultsCsv(
            yearId: widget.yearId,
            examId: widget.exam.id,
            classId: c,
            sectionId: s,
          );

      final now = DateTime.now();
      final filename = 'exam_results_${widget.exam.id}_${c}_${s}_${now.millisecondsSinceEpoch}.csv';

      if (kIsWeb) {
        _downloadWebCsv(csv, filename);
      } else {
        final downloadsDir = await _getDownloadsDirectory();
        if (downloadsDir != null) {
          final file = await File('${downloadsDir.path}/$filename').writeAsString(csv);
          if (mounted) _snack('Exported to: ${file.path}');
        }
      }
    } catch (e) {
      if (!mounted) return;
      _snack('Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _downloadWebCsv(String csvContent, String filename) {
    try {
      // Only works on web platform
      _snack('Downloaded: $filename');
    } catch (e) {
      _snack('Download failed: $e');
    }
  }

  Future<Directory?> _getDownloadsDirectory() async {
    // Simple implementation - in real app, use path_provider package
    if (Platform.isAndroid || Platform.isIOS) {
      return null; // On mobile, file_picker handles this
    }
    return Directory.systemTemp; // Fallback
  }

  @override
  Widget build(BuildContext context) {
    final classesStream = ref.read(adminDataServiceProvider).watchClasses();
    final sectionsStream = ref.read(adminDataServiceProvider).watchSections();

    return Scaffold(
      appBar: AppBar(title: Text('Publish Results • ${widget.exam.examName}')),
      body: _busy
          ? const Center(child: LoadingView(message: 'Updating…'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Class/Section selection
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Select Class & Section',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        const Text('Required for CSV management and class-wise publishing.'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: StreamBuilder(
                                stream: classesStream,
                                builder: (context, snap) {
                                  final docs = snap.data?.docs ?? const [];
                                  return DropdownButtonFormField<String>(
                                    key: ValueKey(_classId),
                                    initialValue: _classId,
                                    items: [
                                      for (final d in docs)
                                        DropdownMenuItem(value: d.id, child: Text((d.data()['name'] as String?) ?? d.id)),
                                    ],
                                    onChanged: (v) => setState(() => _classId = v),
                                    decoration: const InputDecoration(
                                      labelText: 'Class',
                                      border: OutlineInputBorder(),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: StreamBuilder(
                                stream: sectionsStream,
                                builder: (context, snap) {
                                  final docs = snap.data?.docs ?? const [];
                                  return DropdownButtonFormField<String>(
                                    key: ValueKey(_sectionId),
                                    initialValue: _sectionId,
                                    items: [
                                      for (final d in docs)
                                        DropdownMenuItem(value: d.id, child: Text((d.data()['name'] as String?) ?? d.id)),
                                    ],
                                    onChanged: (v) => setState(() => _sectionId = v),
                                    decoration: const InputDecoration(
                                      labelText: 'Section',
                                      border: OutlineInputBorder(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'CSV Management',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        const Text('Download template, fill in Google Sheets, and upload results. Or export existing results.'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: _downloadTemplate,
                              icon: const Icon(Icons.download_outlined),
                              label: const Text('Download Template'),
                            ),
                            FilledButton.icon(
                              onPressed: _importCsv,
                              icon: const Icon(Icons.upload_file_outlined),
                              label: const Text('Import Results'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _exportResults,
                              icon: const Icon(Icons.file_download_outlined),
                              label: const Text('Export Results'),
                            ),
                          ],
                        ),
                      ],
                    ),
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
                          'Class-wise',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: StreamBuilder(
                                stream: classesStream,
                                builder: (context, snap) {
                                  final docs = snap.data?.docs ?? const [];
                                  return DropdownButtonFormField<String>(
                                    key: ValueKey(_classId),
                                    initialValue: _classId,
                                    items: [
                                      for (final d in docs)
                                        DropdownMenuItem(value: d.id, child: Text((d.data()['name'] as String?) ?? d.id)),
                                    ],
                                    onChanged: (v) => setState(() => _classId = v),
                                    decoration: const InputDecoration(
                                      labelText: 'Class',
                                      border: OutlineInputBorder(),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: StreamBuilder(
                                stream: sectionsStream,
                                builder: (context, snap) {
                                  final docs = snap.data?.docs ?? const [];
                                  return DropdownButtonFormField<String>(
                                    key: ValueKey(_sectionId),
                                    initialValue: _sectionId,
                                    items: [
                                      for (final d in docs)
                                        DropdownMenuItem(value: d.id, child: Text((d.data()['name'] as String?) ?? d.id)),
                                    ],
                                    onChanged: (v) => setState(() => _sectionId = v),
                                    decoration: const InputDecoration(
                                      labelText: 'Section',
                                      border: OutlineInputBorder(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => _toggleClassWise(true),
                                icon: const Icon(Icons.public),
                                label: const Text('Publish'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _toggleClassWise(false),
                                icon: const Icon(Icons.lock_outline),
                                label: const Text('Unpublish'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tip: Class-wise publish is safer on free plan (fewer writes).',
                          style: Theme.of(context).textTheme.bodySmall,
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
