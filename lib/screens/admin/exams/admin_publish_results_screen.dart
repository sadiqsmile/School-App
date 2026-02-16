import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/exam.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/loading_view.dart';

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
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Exam-wide',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        const Text('Publish/unpublish all results for this exam.'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => _toggleExamWide(true),
                                icon: const Icon(Icons.public),
                                label: const Text('Publish all'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _toggleExamWide(false),
                                icon: const Icon(Icons.lock_outline),
                                label: const Text('Unpublish all'),
                              ),
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
