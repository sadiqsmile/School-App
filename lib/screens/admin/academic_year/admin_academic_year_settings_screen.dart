import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/loading_view.dart';

import 'admin_academic_year_rollover_wizard_screen.dart';

class AdminAcademicYearSettingsScreen extends ConsumerStatefulWidget {
  const AdminAcademicYearSettingsScreen({super.key});

  @override
  ConsumerState<AdminAcademicYearSettingsScreen> createState() => _AdminAcademicYearSettingsScreenState();
}

class _YearItem {
  const _YearItem({
    required this.yearId,
    required this.label,
    required this.createdAt,
  });

  final String yearId;
  final String label;
  final DateTime? createdAt;
}

class _AdminAcademicYearSettingsScreenState extends ConsumerState<AdminAcademicYearSettingsScreen> {
  bool _busy = false;

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _createYearDialog() async {
    final yearCtrl = TextEditingController();
    final labelCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Academic Year'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: yearCtrl,
                decoration: const InputDecoration(
                  labelText: 'Year ID',
                  hintText: 'example: 2026-27',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Label (optional)',
                  hintText: 'example: Academic Year 2026-27',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tip: Use the same format everywhere (e.g., 2026-27).',
                style: TextStyle(fontSize: 12),
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

    final yearId = yearCtrl.text.trim();
    final label = labelCtrl.text.trim();

    if (yearId.isEmpty) {
      _snack('Year ID is required');
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(academicYearAdminServiceProvider).createAcademicYear(
            yearId: yearId,
            label: label.isEmpty ? yearId : label,
          );
      if (!mounted) return;
      _snack('Year created');
    } catch (e) {
      if (!mounted) return;
      _snack('Create failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setActiveYear(String yearId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set active year'),
        content: Text('Make "$yearId" the active academic year?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Set Active')),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(academicYearAdminServiceProvider).setActiveAcademicYearId(yearId: yearId);
      ref.invalidate(activeAcademicYearIdProvider);
      if (!mounted) return;
      _snack('Active year updated');
    } catch (e) {
      if (!mounted) return;
      _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openRolloverWizard({required String activeYearId}) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminAcademicYearRolloverWizardScreen(activeYearId: activeYearId),
      ),
    );

    if (ok == true) {
      ref.invalidate(activeAcademicYearIdProvider);
      if (!mounted) return;
      _snack('Rollover finished');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(firebaseAuthUserProvider).asData?.value;
    if (authUser == null) {
      return const Center(child: Text('Please login again.'));
    }

    final yearAsync = ref.watch(activeAcademicYearIdProvider);
    final yearsStream = ref.read(academicYearAdminServiceProvider).watchSchoolAcademicYears();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _createYearDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create Year'),
      ),
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
                        'Academic Year Settings',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      yearAsync.when(
                        loading: () => const Text('Active year: …'),
                        error: (e, _) => Text('Active year: (error) $e'),
                        data: (yearId) => Row(
                          children: [
                            Expanded(child: Text('Active year: $yearId')),
                            FilledButton.icon(
                              onPressed: _busy ? null : () => _openRolloverWizard(activeYearId: yearId),
                              icon: const Icon(Icons.school_outlined),
                              label: const Text('Rollover / Promote'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create new years, switch active year, and run year rollover + student promotion.\n'
                        'No Cloud Functions are used (Firestore-only).',
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
                        'Academic years',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: yearsStream,
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: LinearProgressIndicator(),
                            );
                          }
                          if (snap.hasError) {
                            return Text('Error: ${snap.error}');
                          }

                          final docs = snap.data?.docs ?? const [];
                          if (docs.isEmpty) {
                            return const Text('No academic years yet. Tap “Create Year”.');
                          }

                          _YearItem mapDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
                            final data = d.data();
                            final label = (data['label'] as String?)?.trim();
                            final createdAt = data['createdAt'];

                            DateTime? dt;
                            if (createdAt is Timestamp) dt = createdAt.toDate();

                            return _YearItem(
                              yearId: d.id,
                              label: (label == null || label.isEmpty) ? d.id : label,
                              createdAt: dt,
                            );
                          }

                          final items = docs.map(mapDoc).toList();

                          return yearAsync.when(
                            loading: () => const LoadingView(message: 'Loading active year…'),
                            error: (e, _) => Text('Active year error: $e'),
                            data: (activeYearId) {
                              return Column(
                                children: [
                                  for (final y in items)
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(
                                        y.yearId == activeYearId ? Icons.check_circle : Icons.calendar_today_outlined,
                                      ),
                                      title: Text(y.label),
                                      subtitle: y.createdAt == null
                                          ? Text('ID: ${y.yearId}')
                                          : Text(
                                              'ID: ${y.yearId} • Created: ${y.createdAt!.year}-${y.createdAt!.month.toString().padLeft(2, '0')}-${y.createdAt!.day.toString().padLeft(2, '0')}',
                                            ),
                                      trailing: y.yearId == activeYearId
                                          ? const Text('Active', style: TextStyle(fontWeight: FontWeight.w800))
                                          : TextButton(
                                              onPressed: _busy ? null : () => _setActiveYear(y.yearId),
                                              child: const Text('Set active'),
                                            ),
                                    ),
                                ],
                              );
                            },
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
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: LoadingView(message: 'Working…'),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
