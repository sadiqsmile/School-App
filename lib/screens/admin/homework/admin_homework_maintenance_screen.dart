import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/loading_view.dart';

class AdminHomeworkMaintenanceScreen extends ConsumerStatefulWidget {
  const AdminHomeworkMaintenanceScreen({super.key});

  @override
  ConsumerState<AdminHomeworkMaintenanceScreen> createState() => _AdminHomeworkMaintenanceScreenState();
}

class _AdminHomeworkMaintenanceScreenState extends ConsumerState<AdminHomeworkMaintenanceScreen> {
  bool _busy = false;
  int _done = 0;
  int _total = -1;
  String? _status;

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _archiveOld({required String yearId}) async {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));

    setState(() {
      _busy = true;
      _done = 0;
      _total = -1;
      _status = 'Archiving…';
    });

    try {
      final count = await ref.read(homeworkServiceProvider).archiveOldHomework(
            yearId: yearId,
            cutoffDate: cutoff,
            onProgress: (done, total) {
              if (!mounted) return;
              setState(() {
                _done = done;
                _total = total;
                _status = total > 0 ? 'Archiving $done / $total' : 'Archiving… ($done updated)';
              });
            },
          );

      if (!mounted) return;
      _snack('Archived $count item(s)');
    } catch (e) {
      if (!mounted) return;
      _snack('Archive failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(firebaseAuthUserProvider).asData?.value;
    if (authUser == null) {
      return const Center(child: Text('Please login again.'));
    }

    final yearAsync = ref.watch(activeAcademicYearIdProvider);

    return yearAsync.when(
      loading: () => const Center(child: LoadingView(message: 'Loading academic year…')),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (yearId) {
        final cutoff = DateTime.now().subtract(const Duration(days: 30));
        final cutoffText = '${cutoff.year}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}';

        final oldStream = ref.read(homeworkServiceProvider).watchOldActiveHomework(
              yearId: yearId,
              cutoffDate: cutoff,
              limit: 50,
            );

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Monthly Homework Auto-Clear (FREE plan)',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          Text('Active Year: $yearId'),
                          const SizedBox(height: 8),
                          Text(
                            'Rule: hide homework/notes older than 30 days in UI.\n'
                            'This screen lets you archive old items by setting isActive=false (history is preserved).',
                          ),
                          const SizedBox(height: 8),
                          Text('Cutoff date: $cutoffText', style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _busy ? null : () => _archiveOld(yearId: yearId),
                            icon: const Icon(Icons.archive_outlined),
                            label: const Text('Archive old homework/notes'),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tip: This is optional. Even without archiving, the UI will auto-hide old items.',
                            style: Theme.of(context).textTheme.bodySmall,
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
                            'Preview: old active items (first 50)',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: oldStream,
                            builder: (context, snap) {
                              if (snap.connectionState == ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 6),
                                  child: LinearProgressIndicator(),
                                );
                              }
                              if (snap.hasError) {
                                return Text('Error: ${snap.error}');
                              }

                              final docs = snap.data?.docs ?? const [];
                              if (docs.isEmpty) {
                                return const Text('No old active homework found.');
                              }

                              String fmtTs(Object? ts) {
                                if (ts is Timestamp) {
                                  final d = ts.toDate();
                                  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                                }
                                return '—';
                              }

                              return Column(
                                children: [
                                  for (final d in docs)
                                    ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(Icons.assignment_outlined),
                                      title: Text((d.data()['title'] as String?) ?? 'Homework'),
                                      subtitle: Text(
                                        '${(d.data()['class'] ?? '').toString()}-${(d.data()['section'] ?? '').toString()} • '
                                        '${(d.data()['subject'] ?? '').toString()} • '
                                        'Publish: ${fmtTs(d.data()['publishDate'])}',
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_busy)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withAlpha(51),
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const LoadingView(message: 'Working…'),
                              const SizedBox(height: 12),
                              if (_total > 0)
                                LinearProgressIndicator(value: (_done / _total).clamp(0.0, 1.0))
                              else
                                const LinearProgressIndicator(),
                              const SizedBox(height: 8),
                              if (_status != null) Text(_status!, textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
