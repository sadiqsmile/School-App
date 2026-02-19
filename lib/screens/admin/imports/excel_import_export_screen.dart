import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/csv/parents_csv.dart';
import '../../../features/csv/students_csv.dart';
import '../../../features/csv/teachers_csv.dart';
import '../../../models/user_role.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../utils/csv_saver.dart';
import '../../../utils/excel_utils.dart';
import '../../../utils/file_saver.dart';
import '../../../widgets/loading_view.dart';

enum ExcelImportType {
  students,
  parents,
  teachers,
}

enum ExportFormat {
  csv,
  xlsx,
}

class AdminExcelImportExportScreen extends ConsumerWidget {
  const AdminExcelImportExportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUserAsync = ref.watch(appUserProvider);

    return appUserAsync.when(
      loading: () => const Center(child: LoadingView(message: 'Loading…')),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (user) {
        if (user.role != UserRole.admin) {
          return const Center(child: Text('Only admins can access this screen.'));
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Excel Import / Export',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Import or export students, parents, and teachers using CSV or Excel files.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            _sectionCard(
              context,
              title: 'Import',
              subtitle: 'Upload .csv or .xlsx files with required headers',
              children: [
                _actionButton(
                  context,
                  icon: Icons.upload_file,
                  label: 'Import Students',
                  onPressed: () => _openImportFlow(context, ExcelImportType.students),
                ),
                _actionButton(
                  context,
                  icon: Icons.upload_file,
                  label: 'Import Parents',
                  onPressed: () => _openImportFlow(context, ExcelImportType.parents),
                ),
                _actionButton(
                  context,
                  icon: Icons.upload_file,
                  label: 'Import Teachers',
                  onPressed: () => _openImportFlow(context, ExcelImportType.teachers),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _sectionCard(
              context,
              title: 'Export',
              subtitle: 'Download CSV or Excel with correct headers',
              children: [
                _actionButton(
                  context,
                  icon: Icons.download,
                  label: 'Export Students',
                  onPressed: () => _exportStudents(context, ref),
                ),
                _actionButton(
                  context,
                  icon: Icons.download,
                  label: 'Export Parents',
                  onPressed: () => _exportParents(context, ref),
                ),
                _actionButton(
                  context,
                  icon: Icons.download,
                  label: 'Export Teachers',
                  onPressed: () => _exportTeachers(context, ref),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  static void _openImportFlow(BuildContext context, ExcelImportType type) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ExcelImportFlowScreen(type: type)),
    );
  }

  static Future<void> _exportStudents(BuildContext context, WidgetRef ref) async {
    final format = await _selectExportFormat(context);
    if (format == null) return;

    try {
      final rows = await ref.read(studentCsvImportServiceProvider).exportBaseStudentsForCsv();
      final now = DateTime.now();
      final y = now.year.toString().padLeft(4, '0');
      final m = now.month.toString().padLeft(2, '0');
      final d = now.day.toString().padLeft(2, '0');

      if (format == ExportFormat.csv) {
        final csvText = buildStudentsCsv(students: rows);
        await saveCsvText(fileName: 'students_$y$m$d.csv', csvText: csvText);
      } else {
        final bytes = buildExcelFileBytes(
          headers: StudentCsvRow.headers,
          rows: _rowsFromMaps(rows, StudentCsvRow.headers),
          sheetName: 'Students',
        );
        await saveFileBytes(
          fileName: 'students_$y$m$d.xlsx',
          bytes: bytes,
          mimeType: _xlsxMimeType,
          dialogTitle: 'Save Excel',
          allowedExtensions: const ['xlsx'],
        );
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export complete')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  static Future<void> _exportParents(BuildContext context, WidgetRef ref) async {
    final format = await _selectExportFormat(context);
    if (format == null) return;

    try {
      final rows = await ref.read(parentCsvImportServiceProvider).exportParentsForCsv();
      final now = DateTime.now();
      final y = now.year.toString().padLeft(4, '0');
      final m = now.month.toString().padLeft(2, '0');
      final d = now.day.toString().padLeft(2, '0');

      if (format == ExportFormat.csv) {
        final csvText = buildParentsCsv(parents: rows);
        await saveCsvText(fileName: 'parents_$y$m$d.csv', csvText: csvText);
      } else {
        final bytes = buildExcelFileBytes(
          headers: ParentCsvRow.headers,
          rows: _rowsFromMaps(rows, ParentCsvRow.headers),
          sheetName: 'Parents',
        );
        await saveFileBytes(
          fileName: 'parents_$y$m$d.xlsx',
          bytes: bytes,
          mimeType: _xlsxMimeType,
          dialogTitle: 'Save Excel',
          allowedExtensions: const ['xlsx'],
        );
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export complete')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  static Future<void> _exportTeachers(BuildContext context, WidgetRef ref) async {
    final format = await _selectExportFormat(context);
    if (format == null) return;

    try {
      final rows = await ref.read(teacherCsvImportServiceProvider).exportTeachersForCsv();
      final now = DateTime.now();
      final y = now.year.toString().padLeft(4, '0');
      final m = now.month.toString().padLeft(2, '0');
      final d = now.day.toString().padLeft(2, '0');

      if (format == ExportFormat.csv) {
        final csvText = buildTeachersCsv(teachers: rows);
        await saveCsvText(fileName: 'teachers_$y$m$d.csv', csvText: csvText);
      } else {
        final bytes = buildExcelFileBytes(
          headers: TeacherCsvRow.headers,
          rows: _rowsFromMaps(rows, TeacherCsvRow.headers),
          sheetName: 'Teachers',
        );
        await saveFileBytes(
          fileName: 'teachers_$y$m$d.xlsx',
          bytes: bytes,
          mimeType: _xlsxMimeType,
          dialogTitle: 'Save Excel',
          allowedExtensions: const ['xlsx'],
        );
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export complete')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }
}

class ExcelImportFlowScreen extends ConsumerStatefulWidget {
  const ExcelImportFlowScreen({
    super.key,
    required this.type,
  });

  final ExcelImportType type;

  @override
  ConsumerState<ExcelImportFlowScreen> createState() => _ExcelImportFlowScreenState();
}

class _ExcelImportFlowScreenState extends ConsumerState<ExcelImportFlowScreen> {
  bool _loading = false;
  bool _importing = false;
  int _done = 0;
  int _total = 0;
  String? _status;

  String? _fileName;
  List<String> _headers = const [];
  List<List<String>> _previewRows = const [];
  List<String> _issues = const [];

  List<StudentCsvRow> _studentRows = const [];
  List<ParentCsvRow> _parentRows = const [];
  List<TeacherCsvRow> _teacherRows = const [];

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String get _title {
    switch (widget.type) {
      case ExcelImportType.students:
        return 'Import Students';
      case ExcelImportType.parents:
        return 'Import Parents';
      case ExcelImportType.teachers:
        return 'Import Teachers';
    }
  }

  Future<void> _pickFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['csv', 'xlsx'],
      );
      if (res == null || res.files.isEmpty) return;
      final file = res.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        _snack('Could not read the selected file.');
        return;
      }

      setState(() {
        _loading = true;
        _fileName = file.name;
        _issues = const [];
        _headers = const [];
        _previewRows = const [];
        _studentRows = const [];
        _parentRows = const [];
        _teacherRows = const [];
      });

      final table = await _readTable(file, bytes);
      if (table.isEmpty) {
        setState(() {
          _loading = false;
          _issues = const ['File is empty'];
        });
        return;
      }

      final csvText = const ListToCsvConverter().convert(table);
      final header = table.first.map((c) => c.toString().trim()).toList();
      final previewRows = _buildPreviewRows(table);

      switch (widget.type) {
        case ExcelImportType.students:
          final parsed = parseStudentsCsvText(csvText: csvText);
          setState(() {
            _studentRows = parsed.rows;
            _issues = parsed.issues.map((i) => 'Row ${i.rowNumber}: ${i.message}').toList();
            _headers = header;
            _previewRows = previewRows;
          });
          break;
        case ExcelImportType.parents:
          final parsed = parseParentsCsvText(csvText: csvText);
          setState(() {
            _parentRows = parsed.rows;
            _issues = parsed.issues.map((i) => 'Row ${i.rowNumber}: ${i.message}').toList();
            _headers = header;
            _previewRows = previewRows;
          });
          break;
        case ExcelImportType.teachers:
          final parsed = parseTeachersCsvText(csvText: csvText);
          setState(() {
            _teacherRows = parsed.rows;
            _issues = parsed.issues.map((i) => 'Row ${i.rowNumber}: ${i.message}').toList();
            _headers = header;
            _previewRows = previewRows;
          });
          break;
      }
    } catch (e) {
      _snack('Failed to read file: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<List<dynamic>>> _readTable(PlatformFile file, List<int> bytes) async {
    final ext = file.extension?.toLowerCase();
    if (ext == 'xlsx') {
      return parseExcelTableFromBytes(bytes);
    }

    final text = utf8.decode(bytes, allowMalformed: true);
    final converter = CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    );
    return converter.convert(text);
  }

  List<List<String>> _buildPreviewRows(List<List<dynamic>> table) {
    final dataRows = table
        .skip(1)
        .where((row) => row.any((cell) => cell.toString().trim().isNotEmpty))
        .take(20)
        .toList();

    return dataRows
      .map((row) => row.map((cell) => cell == null ? '' : cell.toString()).toList())
        .toList();
  }

  Future<void> _runImport() async {
    if (_issues.isNotEmpty) {
      _snack('Fix errors before importing.');
      return;
    }

    final rows = switch (widget.type) {
      ExcelImportType.students => _studentRows.length,
      ExcelImportType.parents => _parentRows.length,
      ExcelImportType.teachers => _teacherRows.length,
    };

    if (rows == 0) {
      _snack('No rows to import.');
      return;
    }

    setState(() {
      _importing = true;
      _done = 0;
      _total = rows;
      _status = 'Starting…';
    });

    try {
      switch (widget.type) {
        case ExcelImportType.students:
          final report = await ref.read(studentCsvImportServiceProvider).importStudents(
                rows: _studentRows,
                allowUpdates: false,
                onProgress: _onProgress,
              );
          await _showReport(
            successCount: report.successCount,
            failureCount: report.failureCount,
            failures: report.results
                .where((x) => !x.success)
                .map((x) => _ImportFailure(rowNumber: x.rowNumber, message: x.message))
                .toList(),
          );
          break;
        case ExcelImportType.parents:
          final report = await ref.read(parentCsvImportServiceProvider).importParents(
                rows: _parentRows,
                allowUpdates: false,
                onProgress: _onProgress,
              );
          await _showReport(
            successCount: report.successCount,
            failureCount: report.failureCount,
            failures: report.results
                .where((x) => !x.success)
                .map((x) => _ImportFailure(rowNumber: x.rowNumber, message: x.message))
                .toList(),
          );
          break;
        case ExcelImportType.teachers:
          final report = await ref.read(teacherCsvImportServiceProvider).importTeachers(
                rows: _teacherRows,
                allowUpdates: false,
                onProgress: _onProgress,
              );
          await _showReport(
            successCount: report.successCount,
            failureCount: report.failureCount,
            failures: report.results
                .where((x) => !x.success)
                .map((x) => _ImportFailure(rowNumber: x.rowNumber, message: x.message))
                .toList(),
          );
          break;
      }
    } catch (e) {
      _snack('Import failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _importing = false;
          _status = null;
        });
      }
    }
  }

  void _onProgress(int done, int total) {
    if (!mounted) return;
    setState(() {
      _done = done;
      _total = total;
      _status = 'Processing $done / $total';
    });
  }

  Future<void> _showReport({
    required int successCount,
    required int failureCount,
    required List<_ImportFailure> failures,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Import finished'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Success: $successCount'),
                  Text('Failed: $failureCount'),
                  const SizedBox(height: 12),
                  if (failures.isNotEmpty) ...[
                    const Text('Row errors:', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    for (final f in failures.take(50))
                      Text('Row ${f.rowNumber}: ${f.message}', style: const TextStyle(fontSize: 12)),
                    if (failures.length > 50)
                      Text('…and ${failures.length - 50} more', style: const TextStyle(fontSize: 12)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasIssues = _issues.isNotEmpty;
    final rowsCount = switch (widget.type) {
      ExcelImportType.students => _studentRows.length,
      ExcelImportType.parents => _parentRows.length,
      ExcelImportType.teachers => _teacherRows.length,
    };

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: _importing
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LoadingView(message: 'Importing…'),
                    const SizedBox(height: 12),
                    if (_total > 0)
                      LinearProgressIndicator(value: (_done / _total).clamp(0.0, 1.0)),
                    const SizedBox(height: 8),
                    if (_status != null) Text(_status!, textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
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
                          'Select file',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text('Supported: .csv and .xlsx'),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _loading ? null : _pickFile,
                          icon: const Icon(Icons.attach_file),
                          label: Text(_fileName == null ? 'Choose file' : 'Change file'),
                        ),
                        if (_fileName != null) ...[
                          const SizedBox(height: 8),
                          Text('Selected: $_fileName'),
                        ],
                        const SizedBox(height: 12),
                        Text('Rows found: $rowsCount'),
                        if (hasIssues) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Errors (${_issues.length})',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          for (final issue in _issues.take(50))
                            Text(issue, style: const TextStyle(fontSize: 12)),
                          if (_issues.length > 50)
                            Text('…and ${_issues.length - 50} more', style: const TextStyle(fontSize: 12)),
                        ],
                        if (!hasIssues && rowsCount > 0) ...[
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _runImport,
                            icon: const Icon(Icons.cloud_upload_outlined),
                            label: Text('Import $rowsCount row(s)'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_headers.isNotEmpty && _previewRows.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Preview (first ${_previewRows.length} rows)',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: [
                                for (final h in _headers) DataColumn(label: Text(h)),
                              ],
                              rows: [
                                for (final row in _previewRows)
                                  DataRow(
                                    cells: [
                                      for (var i = 0; i < _headers.length; i++)
                                        DataCell(Text(i < row.length ? row[i] : '')),
                                    ],
                                  ),
                              ],
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

class _ImportFailure {
  const _ImportFailure({
    required this.rowNumber,
    required this.message,
  });

  final int rowNumber;
  final String message;
}

Widget _sectionCard(
  BuildContext context, {
  required String title,
  required String subtitle,
  required List<Widget> children,
}) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: children,
          ),
        ],
      ),
    ),
  );
}

Widget _actionButton(
  BuildContext context, {
  required IconData icon,
  required String label,
  required VoidCallback onPressed,
}) {
  return SizedBox(
    width: 220,
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    ),
  );
}

Future<ExportFormat?> _selectExportFormat(BuildContext context) {
  return showDialog<ExportFormat>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Choose export format'),
        content: const Text('Select CSV or Excel (.xlsx).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ExportFormat.csv),
            child: const Text('CSV'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ExportFormat.xlsx),
            child: const Text('Excel'),
          ),
        ],
      );
    },
  );
}

List<List<Object?>> _rowsFromMaps(List<Map<String, Object?>> data, List<String> headers) {
  return data.map((row) {
    return headers.map((header) {
      final value = row[header];
      if (value is List) return value.join(',');
      return value ?? '';
    }).toList();
  }).toList();
}

const String _xlsxMimeType =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
