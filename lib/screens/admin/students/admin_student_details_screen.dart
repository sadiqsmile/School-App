import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/loading_view.dart';

class AdminStudentDetailsScreen extends ConsumerStatefulWidget {
  const AdminStudentDetailsScreen({super.key, required this.studentId});

  final String studentId;

  @override
  ConsumerState<AdminStudentDetailsScreen> createState() => _AdminStudentDetailsScreenState();
}

class _AdminStudentDetailsScreenState extends ConsumerState<AdminStudentDetailsScreen> {
  bool _busy = false;

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _disableStudent() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Disable student?'),
          content: const Text('This will set isActive = false for this student.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Disable')),
          ],
        );
      },
    );

    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(AppConfig.schoolId)
          .collection('students')
          .doc(widget.studentId)
          .set({'isActive': false}, SetOptions(merge: true));

      if (!mounted) return;
      _snack('Student disabled');
    } catch (e) {
      if (!mounted) return;
      _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeParentMobile({required String oldMobile}) async {
    final mobileCtrl = TextEditingController();
    final parentNameCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change Parent Mobile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: mobileCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'New parent mobile (10 digits)',
                  prefixIcon: Icon(Icons.phone_android_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: parentNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Parent name (optional)',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 10),
              const Text('If the parent account does not exist, it will be created with password = last 4 digits.'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
          ],
        );
      },
    );

    if (ok != true) return;

    final newMobile = mobileCtrl.text.trim();
    final parentName = parentNameCtrl.text.trim().isEmpty ? null : parentNameCtrl.text.trim();

    if (newMobile.length != 10 || int.tryParse(newMobile) == null) {
      _snack('Mobile must be exactly 10 digits');
      return;
    }
    if (newMobile == oldMobile) {
      _snack('This student is already linked to $newMobile');
      return;
    }

    setState(() => _busy = true);
    try {
      final fs = FirebaseFirestore.instance;
      final school = fs.collection('schools').doc(AppConfig.schoolId);
      final studentRef = school.collection('students').doc(widget.studentId);
      final oldParentRef = oldMobile.trim().isEmpty ? null : school.collection('parents').doc(oldMobile);
      final newParentRef = school.collection('parents').doc(newMobile);

      await fs.runTransaction((tx) async {
        final studentSnap = await tx.get(studentRef);
        if (!studentSnap.exists) {
          throw Exception('Student not found');
        }

        // Update student
        tx.set(studentRef, {'parentMobile': newMobile}, SetOptions(merge: true));

        // Remove from old parent.children (best effort)
        if (oldParentRef != null) {
          tx.set(
            oldParentRef,
            {'children': FieldValue.arrayRemove([widget.studentId])},
            SetOptions(merge: true),
          );
        }

        // Add to new parent.children (create if missing)
        final newParentSnap = await tx.get(newParentRef);
        if (newParentSnap.exists) {
          final update = <String, Object?>{
            'children': FieldValue.arrayUnion([widget.studentId]),
          };
          if (parentName != null && parentName.isNotEmpty) {
            update['displayName'] = parentName;
          }
          tx.set(newParentRef, update, SetOptions(merge: true));
        } else {
          final defaultPassword = newMobile.substring(newMobile.length - 4);
          tx.set(newParentRef, {
            'mobile': newMobile,
            'password': defaultPassword,
            'displayName': parentName ?? 'Parent',
            'role': 'parent',
            'isActive': true,
            'children': [widget.studentId],
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });

      if (!mounted) return;
      _snack('Parent mobile updated');
    } catch (e) {
      if (!mounted) return;
      _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminData = ref.read(adminDataServiceProvider);
    final docStream = adminData
        .schoolDoc(schoolId: AppConfig.schoolId)
        .collection('students')
        .doc(widget.studentId)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Student Details')),
      body: Stack(
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: docStream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: LoadingView(message: 'Loading…'));
              }
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              final doc = snap.data;
              if (doc == null || !doc.exists) {
                return const Center(child: Text('Student not found'));
              }

              final data = doc.data() ?? const <String, dynamic>{};
              final admissionNo = (data['admissionNo'] as String?) ?? '—';
              final name = (data['name'] as String?) ?? (data['fullName'] as String?) ?? 'Student';
              final groupId = (data['group'] as String?) ?? (data['groupId'] as String?) ?? '—';
              final classId = (data['class'] as String?) ?? (data['classId'] as String?) ?? '—';
              final sectionId = (data['section'] as String?) ?? (data['sectionId'] as String?) ?? '—';
              final parentMobile = (data['parentMobile'] as String?) ?? '';
              final isActive = (data['isActive'] ?? true) == true;
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          Text('Student ID: ${doc.id}', style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 12),
                          _FieldRow(label: 'Admission No', value: admissionNo),
                          _FieldRow(label: 'Group', value: groupId),
                          _FieldRow(label: 'Class', value: classId),
                          _FieldRow(label: 'Section', value: sectionId),
                          _FieldRow(label: 'Parent Mobile', value: parentMobile.isEmpty ? '—' : parentMobile),
                          _FieldRow(label: 'Active', value: isActive ? 'Yes' : 'No'),
                          _FieldRow(
                            label: 'Created At',
                            value: createdAt == null ? '—' : createdAt.toLocal().toString(),
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
                            'Actions',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _changeParentMobile(oldMobile: parentMobile),
                              icon: const Icon(Icons.link_outlined),
                              label: const Text('Change Parent Mobile'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 48,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.error,
                                foregroundColor: Theme.of(context).colorScheme.onError,
                              ),
                              onPressed: _busy ? null : _disableStudent,
                              icon: const Icon(Icons.block_outlined),
                              label: const Text('Disable Student'),
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
          if (_busy)
            const ColoredBox(
              color: Color(0x66000000),
              child: Center(child: LoadingView(message: 'Working…')),
            ),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
