import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

import '../../../models/student_base.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/loading_view.dart';

class AdminAttendanceScreen extends ConsumerStatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  ConsumerState<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends ConsumerState<AdminAttendanceScreen> {
  String? _classId;
  String? _sectionId;
  DateTime _date = DateTime.now();

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _escapeCsv(String value) {
    final needsQuotes = value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r');
    final escaped = value.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  String _buildCsv({
    required List<StudentBase> students,
    required Map<String, String> records,
  }) {
    final rows = <String>[];
    rows.add('AdmissionNo,StudentName,Status');
    for (final s in students) {
      final admission = s.admissionNo ?? '';
      final status = records[s.id] ?? '';
      rows.add('${_escapeCsv(admission)},${_escapeCsv(s.fullName)},${_escapeCsv(status)}');
    }
    return rows.join('\n');
  }

  String _buildTsv({
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
      loading: () => const Center(child: LoadingView(message: 'Loading academic year…')),
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
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text('Academic Year: $yearId', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: StreamBuilder(
                              stream: classesStream,
                              builder: (context, snap) {
                                if (snap.connectionState == ConnectionState.waiting) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 6),
                                    child: LinearProgressIndicator(),
                                  );
                                }
                                final docs = snap.data?.docs ?? const [];
                                final ids = docs.map((d) => d.id).toSet();
                                final selected = (_classId != null && ids.contains(_classId)) ? _classId : null;
                                final items = <DropdownMenuItem<String?>>[
                                  const DropdownMenuItem(value: null, child: Text('Select class')),
                                  for (final d in docs)
                                    DropdownMenuItem(
                                      value: d.id,
                                      child: Text((d.data()['name'] as String?) ?? d.id),
                                    ),
                                ];
                                return DropdownButtonFormField<String?>(
                                  key: ValueKey(selected),
                                  initialValue: selected,
                                  items: items,
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
                                if (snap.connectionState == ConnectionState.waiting) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 6),
                                    child: LinearProgressIndicator(),
                                  );
                                }
                                final docs = snap.data?.docs ?? const [];
                                final ids = docs.map((d) => d.id).toSet();
                                final selected = (_sectionId != null && ids.contains(_sectionId)) ? _sectionId : null;
                                final items = <DropdownMenuItem<String?>>[
                                  const DropdownMenuItem(value: null, child: Text('Select section')),
                                  for (final d in docs)
                                    DropdownMenuItem(
                                      value: d.id,
                                      child: Text((d.data()['name'] as String?) ?? d.id),
                                    ),
                                ];
                                return DropdownButtonFormField<String?>(
                                  key: ValueKey(selected),
                                  initialValue: selected,
                                  items: items,
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
                        'Tip: Use “Copy CSV” or “Copy TSV” to export this report, or take a screenshot.',
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
                  ? const Center(child: Text('Select class and section to view attendance.'))
                  : StreamBuilder<List<StudentBase>>(
                      stream: attendance.watchStudentsForClassSection(
                        classId: _classId!,
                        sectionId: _sectionId!,
                      ),
                      builder: (context, studentsSnap) {
                        if (studentsSnap.connectionState == ConnectionState.waiting) {
                          return const Center(child: LoadingView(message: 'Loading students…'));
                        }
                        if (studentsSnap.hasError) {
                          return Center(child: Text('Error: ${studentsSnap.error}'));
                        }

                        final students = studentsSnap.data ?? const <StudentBase>[];
                        if (students.isEmpty) {
                          return const Center(child: Text('No students found for this class/section.'));
                        }

                        return StreamBuilder(
                          stream: attendance.watchAttendanceDay(
                            yearId: yearId,
                            classId: _classId!,
                            sectionId: _sectionId!,
                            date: _date,
                          ),
                          builder: (context, daySnap) {
                            if (daySnap.connectionState == ConnectionState.waiting) {
                              return const Center(child: LoadingView(message: 'Loading attendance…'));
                            }
                            if (daySnap.hasError) {
                              return Center(child: Text('Error: ${daySnap.error}'));
                            }

                            final doc = daySnap.data;
                            final exists = doc?.exists == true;
                            final data = doc?.data();

                            if (!exists) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text('No attendance marked for this date yet.'),
                                ),
                              );
                            }

                            final raw = (data == null ? null : data['records']);
                            final records = <String, String>{};
                            if (raw is Map) {
                              for (final e in raw.entries) {
                                final k = e.key.toString();
                                final v = e.value?.toString();
                                if (v != null && (v == 'P' || v == 'A')) {
                                  records[k] = v;
                                }
                              }
                            }

                            var present = 0;
                            var absent = 0;
                            for (final s in students) {
                              final v = records[s.id];
                              if (v == 'P') present++;
                              if (v == 'A') absent++;
                            }

                            final source = _AttendanceDataSource(students: students, records: records);

                            final classId = _classId!;
                            final sectionId = _sectionId!;

                            final markedByUid = (data?['markedByTeacherUid'] as String?);

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
                                        Chip(label: Text('Total: ${students.length}')),
                                        Chip(label: Text('Present: $present')),
                                        Chip(label: Text('Absent: $absent')),
                                        if (markedByUid == null)
                                          const Chip(label: Text('Marked by: —'))
                                        else
                                          FutureBuilder<String?>(
                                            future: ref
                                                .read(userProfileServiceProvider)
                                                .getUserDisplayNameOrNull(markedByUid),
                                            builder: (context, nameSnap) {
                                              final name = nameSnap.data;
                                              final label = (name == null || name.trim().isEmpty)
                                                  ? markedByUid
                                                  : '$name ($markedByUid)';
                                              return Chip(label: Text('Marked by: $label'));
                                            },
                                          ),
                                        ActionChip(
                                          label: const Text('Copy CSV'),
                                          onPressed: () async {
                                            final csv = _buildCsv(students: students, records: records);
                                            await Clipboard.setData(ClipboardData(text: csv));
                                            if (mounted) _snack('CSV copied to clipboard');
                                          },
                                        ),
                                        ActionChip(
                                          label: const Text('Copy TSV'),
                                          onPressed: () async {
                                            final tsv = _buildTsv(students: students, records: records);
                                            await Clipboard.setData(ClipboardData(text: tsv));
                                            if (mounted) _snack('TSV copied to clipboard');
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Card(
                                  child: PaginatedDataTable(
                                    header: Text('$classId-$sectionId • ${DateFormat('dd MMM yyyy').format(_date)}'),
                                    rowsPerPage: 25,
                                    columns: const [
                                      DataColumn(label: Text('Admission')),
                                      DataColumn(label: Text('Student')),
                                      DataColumn(label: Text('Status')),
                                    ],
                                    source: source,
                                  ),
                                ),
                              ],
                            );
                          },
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

class _AttendanceDataSource extends DataTableSource {
  _AttendanceDataSource({required this.students, required this.records});

  final List<StudentBase> students;
  final Map<String, String> records;

  @override
  DataRow? getRow(int index) {
    if (index < 0 || index >= students.length) return null;
    final s = students[index];
    final status = records[s.id];
    final label = status ?? '—';
    final color = switch (status) {
      'P' => Colors.green,
      'A' => Colors.red,
      _ => Colors.grey,
    };

    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(Text(s.admissionNo ?? '-')),
        DataCell(Text(s.fullName)),
        DataCell(Text(label, style: TextStyle(fontWeight: FontWeight.w900, color: color))),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => students.length;

  @override
  int get selectedRowCount => 0;
}
