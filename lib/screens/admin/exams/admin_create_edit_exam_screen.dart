import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/core_providers.dart';
import '../../../widgets/loading_view.dart';

class AdminCreateEditExamScreen extends ConsumerStatefulWidget {
  const AdminCreateEditExamScreen({
    super.key,
    required this.yearId,
    this.examId,
    required this.initialGroupId,
  });

  final String yearId;
  final String? examId;
  final String initialGroupId;

  @override
  ConsumerState<AdminCreateEditExamScreen> createState() => _AdminCreateEditExamScreenState();
}

class _AdminCreateEditExamScreenState extends ConsumerState<AdminCreateEditExamScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  String? _group;
  DateTime? _start;
  DateTime? _end;
  bool _active = true;
  bool _loading = true;
  bool _saving = false;

  static const _groups = <String>['primary', 'middle', 'highschool'];

  @override
  void initState() {
    super.initState();
    _group = widget.initialGroupId;
    _loadIfEditing();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _loadIfEditing() async {
    final examId = widget.examId;
    if (examId == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final snap = await ref
          .read(examServiceProvider)
          .examsCol(yearId: widget.yearId)
          .doc(examId)
          .get();
      final data = snap.data();
      if (data != null) {
        _name.text = (data['examName'] as String?) ?? '';
        _group = (data['groupId'] as String?) ?? widget.initialGroupId;
        final s = data['startDate'];
        final e = data['endDate'];
        if (s is Timestamp) _start = s.toDate();
        if (e is Timestamp) _end = e.toDate();
        _active = (data['isActive'] ?? true) == true;
      }
    } catch (_) {
      // ignore; show empty form
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2035, 12, 31),
      initialDate: _start ?? DateTime.now(),
    );
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2035, 12, 31),
      initialDate: _end ?? (_start ?? DateTime.now()),
    );
    if (picked != null) setState(() => _end = picked);
  }

  String _dateLabel(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final groupId = _group;
    if (groupId == null || groupId.isEmpty) {
      _snack('Select group');
      return;
    }

    if (_start != null && _end != null && _end!.isBefore(_start!)) {
      _snack('End date must be after start date');
      return;
    }

    setState(() => _saving = true);
    try {
      final service = ref.read(examServiceProvider);
      if (widget.examId == null) {
        await service.createExam(
          yearId: widget.yearId,
          examName: _name.text,
          groupId: groupId,
          startDate: _start,
          endDate: _end,
          isActive: _active,
        );
      } else {
        await service.updateExam(
          yearId: widget.yearId,
          examId: widget.examId!,
          examName: _name.text,
          groupId: groupId,
          startDate: _start,
          endDate: _end,
          isActive: _active,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _snack('Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.examId != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Exam' : 'Create Exam')),
      body: _loading
          ? const Center(child: LoadingView(message: 'Loading…'))
          : _saving
              ? const Center(child: LoadingView(message: 'Saving…'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Exam Details',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _name,
                                decoration: const InputDecoration(
                                  labelText: 'Exam Name',
                                  prefixIcon: Icon(Icons.school_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) => (v ?? '').trim().isEmpty ? 'Exam name is required' : null,
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                key: ValueKey(_group),
                                initialValue: _group,
                                items: [
                                  for (final g in _groups)
                                    DropdownMenuItem(value: g, child: Text(g[0].toUpperCase() + g.substring(1))),
                                ],
                                onChanged: (v) => setState(() => _group = v),
                                decoration: const InputDecoration(
                                  labelText: 'Group',
                                  prefixIcon: Icon(Icons.account_tree_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Select group' : null,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _pickStart,
                                      icon: const Icon(Icons.date_range),
                                      label: Text('Start: ${_dateLabel(_start)}'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _pickEnd,
                                      icon: const Icon(Icons.event),
                                      label: Text('End: ${_dateLabel(_end)}'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                value: _active,
                                onChanged: (v) => setState(() => _active = v),
                                title: const Text('Active'),
                                subtitle: const Text('Inactive exams are hidden from teacher/parent lists.'),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 48,
                                child: FilledButton.icon(
                                  onPressed: _save,
                                  icon: const Icon(Icons.save_outlined),
                                  label: const Text('Save'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
