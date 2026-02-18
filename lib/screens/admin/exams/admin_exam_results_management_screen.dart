import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/exam.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/exam_providers.dart';

class AdminExamResultsManagementScreen extends ConsumerStatefulWidget {
  const AdminExamResultsManagementScreen({
    super.key,
    required this.yearId,
    required this.exam,
  });

  final String yearId;
  final Exam exam;

  @override
  ConsumerState<AdminExamResultsManagementScreen> createState() =>
      _AdminExamResultsManagementScreenState();
}

class _AdminExamResultsManagementScreenState
    extends ConsumerState<AdminExamResultsManagementScreen> {
  String? _selectedClassId;
  String? _selectedSectionId;
  String _filterStatus = 'all'; // all, pending, approved, published
  bool _busy = false;

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : null,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _approveStudent(String studentId) async {
    final userState = ref.read(appUserProvider);
    final uid = userState.maybeWhen(
      data: (user) => user.uid,
      orElse: () => '',
    );
    if (uid.isEmpty) {
      _snack('Could not get user ID', isError: true);
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(approveResultProvider.notifier).approveForStudent(
            yearId: widget.yearId,
            examId: widget.exam.id,
            studentId: studentId,
            approvedByUid: uid,
          );
      if (!mounted) return;
      _snack('Result approved');
    } catch (e) {
      if (!mounted) return;
      _snack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approveAll() async {
    if (_selectedClassId == null || _selectedSectionId == null) {
      _snack('Please select class and section', isError: true);
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve All'),
        content: const Text('Approve all results for this class-section?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final userState = ref.read(appUserProvider);
    final uid = userState.maybeWhen(
      data: (user) => user.uid,
      orElse: () => '',
    );
    if (uid.isEmpty) {
      _snack('Could not get user ID', isError: true);
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(approveResultProvider.notifier).approveForClassSection(
            yearId: widget.yearId,
            examId: widget.exam.id,
            classId: _selectedClassId!,
            sectionId: _selectedSectionId!,
            approvedByUid: uid,
          );
      if (!mounted) return;
      _snack('All results approved');
    } catch (e) {
      if (!mounted) return;
      _snack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publishResults() async {
    if (_selectedClassId == null || _selectedSectionId == null) {
      _snack('Please select class and section', isError: true);
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Publish Results'),
        content: const Text(
          'This will publish all approved results to parents.\n\nMake sure all results are approved first.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final userState = ref.read(appUserProvider);
    final uid = userState.maybeWhen(
      data: (user) => user.uid,
      orElse: () => '',
    );
    if (uid.isEmpty) {
      _snack('Could not get user ID', isError: true);
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(publishResultProvider.notifier).publishForClassSection(
            yearId: widget.yearId,
            examId: widget.exam.id,
            classId: _selectedClassId!,
            sectionId: _selectedSectionId!,
            publishedByUid: uid,
          );
      if (!mounted) return;
      _snack('Results published successfully');
    } catch (e) {
      if (!mounted) return;
      _snack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final classesStream = ref.read(adminDataServiceProvider).watchClasses();
    final sectionsStream = ref.read(adminDataServiceProvider).watchSections();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Results'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Class/Section Selection
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Class & Section',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: StreamBuilder(
                                stream: classesStream,
                                builder: (ctx, snap) {
                                  final docs = (snap.data as QuerySnapshot?)?.docs ?? [];
                                  return DropdownButtonFormField<String>(
                                    initialValue: _selectedClassId,
                                    items: [
                                      for (final d in docs)
                                        DropdownMenuItem(
                                          value: d.id,
                                          child: Text(((d.data() as Map<String, dynamic>?)?['name'] as String?) ?? d.id),
                                        ),
                                    ],
                                    onChanged: (v) => setState(() => _selectedClassId = v),
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
                                builder: (ctx, snap) {
                                  final docs = (snap.data as QuerySnapshot?)?.docs ?? [];
                                  return DropdownButtonFormField<String>(
                                    initialValue: _selectedSectionId,
                                    items: [
                                      for (final d in docs)
                                        DropdownMenuItem(
                                          value: d.id,
                                          child: Text(((d.data() as Map<String, dynamic>?)?['name'] as String?) ?? d.id),
                                        ),
                                    ],
                                    onChanged: (v) => setState(() => _selectedSectionId = v),
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

                // Filter chips
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _filterStatus == 'all',
                      onSelected: (_) => setState(() => _filterStatus = 'all'),
                    ),
                    FilterChip(
                      label: const Text('Pending'),
                      selected: _filterStatus == 'pending',
                      onSelected: (_) => setState(() => _filterStatus = 'pending'),
                    ),
                    FilterChip(
                      label: const Text('Approved'),
                      selected: _filterStatus == 'approved',
                      onSelected: (_) => setState(() => _filterStatus = 'approved'),
                    ),
                    FilterChip(
                      label: const Text('Published'),
                      selected: _filterStatus == 'published',
                      onSelected: (_) => setState(() => _filterStatus = 'published'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Results List
                if (_selectedClassId != null && _selectedSectionId != null)
                  Consumer(
                    builder: (ctx, ref, _) {
                      final results = ref.watch(watchExamResultsForClassSectionProvider((
                        yearId: widget.yearId,
                        examId: widget.exam.id,
                        classId: _selectedClassId!,
                        sectionId: _selectedSectionId!,
                      )));

                      return results.when(
                        data: (items) {
                          // Filter by status
                          final filtered = items.where((r) {
                            if (_filterStatus == 'pending') return !r.isApproved;
                            if (_filterStatus == 'approved') return r.isApproved && !r.isPublished;
                            if (_filterStatus == 'published') return r.isPublished;
                            return true;
                          }).toList();

                          if (filtered.isEmpty) {
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child: Text(
                                    'No results found',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.outline.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Results (${filtered.length})',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (_filterStatus != 'published')
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        if (_filterStatus == 'pending')
                                          FilledButton.icon(
                                            onPressed: _approveAll,
                                            icon: const Icon(Icons.check_circle_outline),
                                            label: const Text('Approve All'),
                                          ),
                                        if (_filterStatus == 'approved')
                                          FilledButton.icon(
                                            onPressed: _publishResults,
                                            icon: const Icon(Icons.publish),
                                            label: const Text('Publish'),
                                          ),
                                      ],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ...filtered.map((result) {
                                final statusColor = result.isPublished
                                    ? Colors.green
                                    : (result.isApproved
                                        ? Colors.blue
                                        : Colors.orange);
                                final statusLabel = result.isPublished
                                    ? 'Published'
                                    : (result.isApproved ? 'Approved' : 'Draft');

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    result.studentName,
                                                    style:
                                                        theme.textTheme.bodyLarge,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    'ID: ${result.studentId}',
                                                    style:
                                                        theme.textTheme.bodySmall,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Chip(
                                              label: Text(statusLabel),
                                              backgroundColor: statusColor
                                                  .withValues(alpha: 0.2),
                                              labelStyle: TextStyle(
                                                color: statusColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Total: ${result.total.toStringAsFixed(1)} | ${result.percentage.toStringAsFixed(1)}% | ${result.grade}',
                                              style: theme.textTheme.bodySmall,
                                            ),
                                            if (!result.isApproved &&
                                                !result.isPublished)
                                              FilledButton.icon(
                                                onPressed: () =>
                                                    _approveStudent(
                                                      result.studentId,
                                                    ),
                                                icon: const Icon(Icons.check),
                                                label: const Text('Approve'),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                        loading: () => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        error: (err, st) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text('Error: $err'),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
    );
  }
}
