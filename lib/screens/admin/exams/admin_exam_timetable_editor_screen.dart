import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/exam.dart';
import '../../../models/exam_schedule_item.dart';
import '../../../models/exam_timetable.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/loading_view.dart';

class AdminExamTimetableEditorScreen extends ConsumerStatefulWidget {
  const AdminExamTimetableEditorScreen({
    super.key,
    required this.yearId,
    required this.exam,
    this.classId,
    this.sectionId,
  });

  final String yearId;
  final Exam exam;
  final String? classId;
  final String? sectionId;

  @override
  ConsumerState<AdminExamTimetableEditorScreen> createState() => _AdminExamTimetableEditorScreenState();
}

class _AdminExamTimetableEditorScreenState extends ConsumerState<AdminExamTimetableEditorScreen> {
  String? _classId;
  String? _sectionId;
  bool _saving = false;

  final _subject = TextEditingController();
  final _startTime = TextEditingController(text: '09:00');
  final _endTime = TextEditingController(text: '10:00');
  DateTime _date = DateTime.now();

  List<ExamScheduleItem> _schedule = <ExamScheduleItem>[];
  bool _published = false;

  @override
  void initState() {
    super.initState();
    _classId = widget.classId;
    _sectionId = widget.sectionId;
  }

  @override
  void dispose() {
    _subject.dispose();
    _startTime.dispose();
    _endTime.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2035, 12, 31),
      initialDate: _date,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final parts = controller.text.split(':');
    final initial = TimeOfDay(
      hour: parts.length == 2 ? int.tryParse(parts[0]) ?? 9 : 9,
      minute: parts.length == 2 ? int.tryParse(parts[1]) ?? 0 : 0,
    );

    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final h = picked.hour.toString().padLeft(2, '0');
    final m = picked.minute.toString().padLeft(2, '0');
    setState(() => controller.text = '$h:$m');
  }

  bool _isTimeValid(String v) {
    final parts = v.split(':');
    if (parts.length != 2) return false;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return false;
    if (h < 0 || h > 23) return false;
    if (m < 0 || m > 59) return false;
    return true;
  }

  int _minutes(String v) {
    final parts = v.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    return h * 60 + m;
  }

  void _addItem() {
    final subject = _subject.text.trim();
    final start = _startTime.text.trim();
    final end = _endTime.text.trim();

    if ((_classId ?? '').trim().isEmpty || (_sectionId ?? '').trim().isEmpty) {
      _snack('Select class and section first');
      return;
    }
    if (subject.isEmpty) {
      _snack('Subject is required');
      return;
    }
    if (!_isTimeValid(start) || !_isTimeValid(end)) {
      _snack('Time must be HH:mm');
      return;
    }
    if (_minutes(end) <= _minutes(start)) {
      _snack('End time must be after start time');
      return;
    }

    setState(() {
      _schedule = [..._schedule, ExamScheduleItem(date: _date, subject: subject, startTime: start, endTime: end)];
      _subject.clear();
    });
  }

  Future<void> _saveAll() async {
    final classId = (_classId ?? '').trim();
    final sectionId = (_sectionId ?? '').trim();
    if (classId.isEmpty || sectionId.isEmpty) {
      _snack('Select class and section');
      return;
    }

    setState(() => _saving = true);
    try {
      final service = ref.read(examServiceProvider);
      await service.upsertTimetableForClassSection(
        yearId: widget.yearId,
        examId: widget.exam.id,
        classId: classId,
        sectionId: sectionId,
        schedule: _schedule,
      );
      await service.setTimetablePublished(
        yearId: widget.yearId,
        examId: widget.exam.id,
        classId: classId,
        sectionId: sectionId,
        isPublished: _published,
      );

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
    final classesStream = ref.read(adminDataServiceProvider).watchClasses();
    final sectionsStream = ref.read(adminDataServiceProvider).watchSections();

    final canWatch = (_classId ?? '').trim().isNotEmpty && (_sectionId ?? '').trim().isNotEmpty;

    final timetableStream = !canWatch
        ? null
        : ref.read(examServiceProvider).watchTimetableForClassSection(
              yearId: widget.yearId,
              examId: widget.exam.id,
              classId: _classId!,
              sectionId: _sectionId!,
            );

    return Scaffold(
      appBar: AppBar(title: Text('Edit Timetable • ${widget.exam.examName}')),
      body: _saving
          ? const Center(child: LoadingView(message: 'Saving…'))
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
                          'Class / Section',
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
                                  final ids = docs.map((d) => d.id).toSet();
                                  final selected = (_classId != null && ids.contains(_classId)) ? _classId : null;

                                  return DropdownButtonFormField<String>(
                                    key: ValueKey(selected),
                                    initialValue: selected,
                                    items: [
                                      for (final d in docs)
                                        DropdownMenuItem(
                                          value: d.id,
                                          child: Text((d.data()['name'] as String?) ?? d.id),
                                        ),
                                    ],
                                    onChanged: (v) => setState(() => _classId = v),
                                    decoration: const InputDecoration(
                                      labelText: 'Class',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.class_outlined),
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
                                  final ids = docs.map((d) => d.id).toSet();
                                  final selected = (_sectionId != null && ids.contains(_sectionId)) ? _sectionId : null;

                                  return DropdownButtonFormField<String>(
                                    key: ValueKey(selected),
                                    initialValue: selected,
                                    items: [
                                      for (final d in docs)
                                        DropdownMenuItem(
                                          value: d.id,
                                          child: Text((d.data()['name'] as String?) ?? d.id),
                                        ),
                                    ],
                                    onChanged: (v) => setState(() => _sectionId = v),
                                    decoration: const InputDecoration(
                                      labelText: 'Section',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.group_outlined),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (timetableStream != null)
                          StreamBuilder<ExamTimetable?>(
                            stream: timetableStream,
                            builder: (context, snap) {
                              final t = snap.data;
                              if (snap.connectionState == ConnectionState.waiting) {
                                return const LinearProgressIndicator();
                              }
                              if (snap.hasError) {
                                return Text('Error: ${snap.error}');
                              }
                              // Load existing schedule into local state once.
                              if (t != null && _schedule.isEmpty) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (!mounted) return;
                                  setState(() {
                                    _schedule = t.schedule;
                                    _published = t.isPublished;
                                  });
                                });
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _published,
                          onChanged: (v) => setState(() => _published = v),
                          title: const Text('Publish timetable'),
                          subtitle: const Text('Parents can view timetable only when published.'),
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
                          'Add schedule item',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.date_range),
                          label: Text('Date: ${_date.day.toString().padLeft(2, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.year}'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _subject,
                          decoration: const InputDecoration(
                            labelText: 'Subject',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.menu_book_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _startTime,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Start Time (HH:mm)',
                                  border: OutlineInputBorder(),
                                ),
                                onTap: () => _pickTime(_startTime),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _endTime,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'End Time (HH:mm)',
                                  border: OutlineInputBorder(),
                                ),
                                onTap: () => _pickTime(_endTime),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: _addItem,
                            icon: const Icon(Icons.add),
                            label: const Text('Add'),
                          ),
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
                          'Schedule (${_schedule.length})',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        if (_schedule.isEmpty)
                          const Text('No items yet.'),
                        for (final item in _schedule)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.subject, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(
                              '${item.date.day.toString().padLeft(2, '0')}-${item.date.month.toString().padLeft(2, '0')}-${item.date.year} • ${item.startTime} - ${item.endTime}',
                            ),
                            trailing: IconButton(
                              tooltip: 'Remove',
                              onPressed: () {
                                setState(() {
                                  _schedule = _schedule.where((x) => x != item).toList();
                                });
                              },
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: _saveAll,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Save timetable'),
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
