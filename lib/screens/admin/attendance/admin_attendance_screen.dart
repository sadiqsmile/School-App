import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/student_base.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/loading_view.dart';

class AdminAttendanceScreen extends ConsumerStatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  ConsumerState<AdminAttendanceScreen> createState() =>
      _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends ConsumerState<AdminAttendanceScreen> {
  String? _classId;
  String? _sectionId;
  DateTime _date = DateTime.now();
  bool _exporting = false;

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _escapeCsv(String value) {
    final needsQuotes =
        value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    final escaped = value.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  String _buildSummaryCsv({
    required String classId,
    required String sectionId,
    required DateTime date,
    required int total,
    required int present,
    required int absent,
    required String markedBy,
  }) {
    final rows = <String>[];
    rows.add('Date,Class,Section,Total,Present,Absent,MarkedBy');
    rows.add(
      '${_escapeCsv(DateFormat('yyyy-MM-dd').format(date))},'
      '${_escapeCsv(classId)},'
      '${_escapeCsv(sectionId)},'
      '${_escapeCsv(total.toString())},'
      '${_escapeCsv(present.toString())},'
      '${_escapeCsv(absent.toString())},'
      '${_escapeCsv(markedBy)}',
    );
    return rows.join('\n');
  }

  String _buildSummaryTsv({
    required String classId,
    required String sectionId,
    required DateTime date,
    required int total,
    required int present,
    required int absent,
    required String markedBy,
  }) {
    final rows = <String>[];
    rows.add('Date\tClass\tSection\tTotal\tPresent\tAbsent\tMarkedBy');
    rows.add(
      '${DateFormat('yyyy-MM-dd').format(date)}\t'
      '$classId\t'
      '$sectionId\t'
      '$total\t'
      '$present\t'
      '$absent\t'
      '$markedBy',
    );
    return rows.join('\n');
  }

  String _buildDetailedCsv({
    required List<StudentBase> students,
    required Map<String, String> records,
  }) {
    final rows = <String>[];
    rows.add('AdmissionNo,StudentName,Status');
    for (final s in students) {
      final admission = s.admissionNo ?? '';
      final status = records[s.id] ?? '';
      rows.add(
        '${_escapeCsv(admission)},${_escapeCsv(s.fullName)},${_escapeCsv(status)}',
      );
    }
    return rows.join('\n');
  }

  String _buildDetailedTsv({
    required List<StudentBase> students,
    required Map<String, String> records,
  }) {
    final rows = <String>[];
    rows.add('AdmissionNo\tStudentName\tStatus');
    for (final s in students) {
      final admission = s.admissionNo ?? '';
      final status = records[s.id] ?? '';
      rows.add('$admission\t${s.fullName}\t$status');
    }
    return rows.join('\n');
  }

  Future<Map<String, String>> _loadDetailedRecords({
    required String yearId,
    required DateTime date,
    required List<StudentBase> students,
  }) async {
    final attendance = ref.read(attendanceServiceProvider);
    final normalized = DateTime(date.year, date.month, date.day);

    final records = <String, String>{};
    for (final s in students) {
      final snap = await attendance
          .attendanceStudentDayDoc(
            yearId: yearId,
            studentId: s.id,
            date: normalized,
          )
          .get();
      final status = (snap.data()?['status'] as String?);
      if (status == 'P' || status == 'A') {
        records[s.id] = status!;
      }
    }
    return records;
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(firebaseAuthUserProvider).asData?.value;
    if (authUser == null) {
      return const Center(child: Text('Please login again.'));
    }

    final yearAsync = ref.watch(activeAcademicYearIdProvider);
    final adminData = ref.read(adminDataServiceProvider);
    final attendance = ref.read(attendanceServiceProvider);

    final classesStream = adminData.watchClasses();
    final sectionsStream = adminData.watchSections();

    return yearAsync.when(
      loading: () =>
          const Center(child: LoadingView(message: 'Loading academic year…')),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (yearId) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Attendance Report',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Academic Year: $yearId',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: StreamBuilder(
                              stream: classesStream,
                              builder: (context, snap) {
                                if (snap.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 6),
                                    child: LinearProgressIndicator(),
                                  );
                                }
                                final docs = snap.data?.docs ?? const [];
                                final ids = docs.map((d) => d.id).toSet();
                                final selected =
                                    (_classId != null && ids.contains(_classId))
                                    ? _classId
                                    : null;
                                final items = <DropdownMenuItem<String?>>[
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('Select class'),
                                  ),
                                  for (final d in docs)
                                    DropdownMenuItem(
                                      value: d.id,
                                      child: Text(
                                        (d.data()['name'] as String?) ?? d.id,
                                      ),
                                    ),
                                ];
                                return DropdownButtonFormField<String?>(
                                  key: ValueKey(selected),
                                  initialValue: selected,
                                  items: items,
                                  onChanged: (v) =>
                                      setState(() => _classId = v),
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
                                if (snap.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 6),
                                    child: LinearProgressIndicator(),
                                  );
                                }
                                final docs = snap.data?.docs ?? const [];
                                final ids = docs.map((d) => d.id).toSet();
                                final selected =
                                    (_sectionId != null &&
                                        ids.contains(_sectionId))
                                    ? _sectionId
                                    : null;
                                final items = <DropdownMenuItem<String?>>[
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('Select section'),
                                  ),
                                  for (final d in docs)
                                    DropdownMenuItem(
                                      value: d.id,
                                      child: Text(
                                        (d.data()['name'] as String?) ?? d.id,
                                      ),
                                    ),
                                ];
                                return DropdownButtonFormField<String?>(
                                  key: ValueKey(selected),
                                  initialValue: selected,
                                  items: items,
                                  onChanged: (v) =>
                                      setState(() => _sectionId = v),
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
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: DateTime(2020, 1, 1),
                            lastDate: DateTime(2035, 12, 31),
                            initialDate: _date,
                          );
                          if (picked != null) {
                            setState(() => _date = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.date_range_outlined),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(DateFormat('dd MMM yyyy').format(_date)),
                              const Icon(Icons.edit_calendar_outlined),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tip: “Copy summary” is fast. “Copy detailed” reads one doc per student (slower).',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: (_classId == null || _sectionId == null)
                  ? const Center(
                      child: Text(
                        'Select class and section to view attendance.',
                      ),
                    )
                  : StreamBuilder(
                      stream: attendance.watchAttendanceSummaryDay(
                        yearId: yearId,
                        classId: _classId!,
                        sectionId: _sectionId!,
                        date: _date,
                      ),
                      builder: (context, summarySnap) {
                        if (summarySnap.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: LoadingView(message: 'Loading attendance…'),
                          );
                        }
                        if (summarySnap.hasError) {
                          return Center(
                            child: Text('Error: ${summarySnap.error}'),
                          );
                        }

                        final doc = summarySnap.data;
                        final exists = doc?.exists == true;
                        final data = doc?.data();

                        if (!exists || data == null) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'No attendance marked for this date yet.',
                              ),
                            ),
                          );
                        }

                        final total =
                            (data['totalStudents'] as num?)?.toInt() ?? 0;
                        final present =
                            (data['presentCount'] as num?)?.toInt() ?? 0;
                        final absent =
                            (data['absentCount'] as num?)?.toInt() ?? 0;
                        final markedByUid =
                          (data['markedByUid'] as String?) ??
                          (data['markedByTeacherUid'] as String?);

                        final classId = _classId!;
                        final sectionId = _sectionId!;

                        return ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          children: [
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Wrap(
                                  spacing: 10,
                                  runSpacing: 8,
                                  children: [
                                    Chip(label: Text('Total: $total')),
                                    Chip(label: Text('Present: $present')),
                                    Chip(label: Text('Absent: $absent')),
                                    if (markedByUid == null)
                                      const Chip(label: Text('Marked by: —'))
                                    else
                                      FutureBuilder<String?>(
                                        future: ref
                                            .read(userProfileServiceProvider)
                                            .getUserDisplayNameOrNull(
                                              markedByUid,
                                            ),
                                        builder: (context, nameSnap) {
                                          final name = nameSnap.data;
                                          final label =
                                              (name == null ||
                                                  name.trim().isEmpty)
                                              ? markedByUid
                                              : '$name ($markedByUid)';
                                          return Chip(
                                            label: Text('Marked by: $label'),
                                          );
                                        },
                                      ),
                                    ActionChip(
                                      label: const Text('Copy summary CSV'),
                                      onPressed: _exporting
                                          ? null
                                          : () async {
                                              final csv = _buildSummaryCsv(
                                                classId: classId,
                                                sectionId: sectionId,
                                                date: _date,
                                                total: total,
                                                present: present,
                                                absent: absent,
                                                markedBy: markedByUid ?? '',
                                              );
                                              await Clipboard.setData(
                                                ClipboardData(text: csv),
                                              );
                                              if (mounted) {
                                                _snack(
                                                  'Summary CSV copied to clipboard',
                                                );
                                              }
                                            },
                                    ),
                                    ActionChip(
                                      label: const Text('Copy summary TSV'),
                                      onPressed: _exporting
                                          ? null
                                          : () async {
                                              final tsv = _buildSummaryTsv(
                                                classId: classId,
                                                sectionId: sectionId,
                                                date: _date,
                                                total: total,
                                                present: present,
                                                absent: absent,
                                                markedBy: markedByUid ?? '',
                                              );
                                              await Clipboard.setData(
                                                ClipboardData(text: tsv),
                                              );
                                              if (mounted) {
                                                _snack(
                                                  'Summary TSV copied to clipboard',
                                                );
                                              }
                                            },
                                    ),
                                    ActionChip(
                                      label: const Text(
                                        'Copy detailed CSV (slow)',
                                      ),
                                      onPressed: _exporting
                                          ? null
                                          : () async {
                                              setState(() => _exporting = true);
                                              try {
                                                final students = await attendance
                                                    .watchStudentsForClassSection(
                                                      classId: classId,
                                                      sectionId: sectionId,
                                                    )
                                                    .first;
                                                final records =
                                                    await _loadDetailedRecords(
                                                      yearId: yearId,
                                                      date: _date,
                                                      students: students,
                                                    );
                                                final csv = _buildDetailedCsv(
                                                  students: students,
                                                  records: records,
                                                );
                                                await Clipboard.setData(
                                                  ClipboardData(text: csv),
                                                );
                                                if (mounted) {
                                                  _snack(
                                                    'Detailed CSV copied to clipboard',
                                                  );
                                                }
                                              } catch (e) {
                                                if (mounted) {
                                                  _snack('Export failed: $e');
                                                }
                                              } finally {
                                                if (mounted) {
                                                  setState(
                                                    () => _exporting = false,
                                                  );
                                                }
                                              }
                                            },
                                    ),
                                    ActionChip(
                                      label: const Text(
                                        'Copy detailed TSV (slow)',
                                      ),
                                      onPressed: _exporting
                                          ? null
                                          : () async {
                                              setState(() => _exporting = true);
                                              try {
                                                final students = await attendance
                                                    .watchStudentsForClassSection(
                                                      classId: classId,
                                                      sectionId: sectionId,
                                                    )
                                                    .first;
                                                final records =
                                                    await _loadDetailedRecords(
                                                      yearId: yearId,
                                                      date: _date,
                                                      students: students,
                                                    );
                                                final tsv = _buildDetailedTsv(
                                                  students: students,
                                                  records: records,
                                                );
                                                await Clipboard.setData(
                                                  ClipboardData(text: tsv),
                                                );
                                                if (mounted) {
                                                  _snack(
                                                    'Detailed TSV copied to clipboard',
                                                  );
                                                }
                                              } catch (e) {
                                                if (mounted) {
                                                  _snack('Export failed: $e');
                                                }
                                              } finally {
                                                if (mounted) {
                                                  setState(
                                                    () => _exporting = false,
                                                  );
                                                }
                                              }
                                            },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  '$classId-$sectionId • ${DateFormat('dd MMM yyyy').format(_date)}\n\n'
                                  'This report reads Attendance v3 daily summaries.\n'
                                  'Use the export buttons above for summary or per-student output.',
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
