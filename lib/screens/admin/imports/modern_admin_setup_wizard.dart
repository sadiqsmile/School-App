import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../providers/core_providers.dart';
import '../../../features/csv/classes_sections_csv.dart';
import '../../../features/csv/students_csv.dart';
import '../../../features/csv/parents_csv.dart';
import '../../../features/csv/teacher_assignments_csv.dart';
import '../../../services/class_section_csv_import_service.dart';
import '../../../widgets/loading_view.dart';

/// Modern mobile-friendly setup wizard with import capabilities
class ModernAdminSetupWizard extends ConsumerStatefulWidget {
  const ModernAdminSetupWizard({super.key});

  @override
  ConsumerState<ModernAdminSetupWizard> createState() => _ModernAdminSetupWizardState();
}

class _ModernAdminSetupWizardState extends ConsumerState<ModernAdminSetupWizard> {
  int _currentStep = 0;
  String _activeYearId = '';
  String _newYearId = '';
  String _setupMethod = 'import'; // 'manual' or 'import'
  bool _busy = false;

  // Import data holders
  ClassSectionsCsvParseResult? _classSectionsData;
  StudentsCsvParseResult? _studentsData;
  ParentsCsvParseResult? _parentsData;
  TeacherAssignmentsCsvParseResult? _teacherAssignmentsData;

  final _newYearController = TextEditingController();

  @override
  void dispose() {
    _newYearController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _loadActiveYear() async {
    try {
      final yearId = await ref.read(academicYearServiceProvider).getActiveAcademicYearId();
      if (mounted) {
        setState(() => _activeYearId = yearId);
      }
    } catch (e) {
      _snack('Error loading active year: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadActiveYear();
  }

  Future<void> _createYear() async {
    final newYear = _newYearController.text.trim();
    if (newYear.isEmpty) {
      _snack('Please enter a year ID');
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(academicYearAdminServiceProvider).createAcademicYear(
            yearId: newYear,
            label: 'Academic Year $newYear',
          );

      // Set as active
      await ref.read(adminDataServiceProvider).setActiveAcademicYearId(yearId: newYear);

      setState(() {
        _activeYearId = newYear;
        _newYearId = newYear;
      });

      _snack('✅ Year $newYear created and activated');

      // Auto-advance to next step
      setState(() => _currentStep = 1);
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAndParseCSV(String type) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        _snack('Could not read file');
        return;
      }

      final content = utf8.decode(bytes);

      setState(() => _busy = true);

      try {
        switch (type) {
          case 'classes':
            final parsed = parseClassSectionsCsv(content);
            setState(() => _classSectionsData = parsed);
            if (parsed.hasErrors) {
              _snack('⚠️ Found ${parsed.issues.length} errors in CSV');
            } else {
              _snack('✅ Loaded ${parsed.rows.length} class-sections');
            }
            break;
          case 'students':
            final parsed = parseStudentsCsvText(csvText: content);
            setState(() => _studentsData = parsed);
            if (parsed.issues.isNotEmpty) {
              _snack('⚠️ Found ${parsed.issues.length} errors in CSV');
            } else {
              _snack('✅ Loaded ${parsed.rows.length} students');
            }
            break;
          case 'parents':
            final parsed = parseParentsCsvText(csvText: content);
            setState(() => _parentsData = parsed);
            if (parsed.issues.isNotEmpty) {
              _snack('⚠️ Found ${parsed.issues.length} errors in CSV');
            } else {
              _snack('✅ Loaded ${parsed.rows.length} parents');
            }
            break;
          case 'assignments':
            final parsed = parseTeacherAssignmentsCsvText(csvText: content);
            setState(() => _teacherAssignmentsData = parsed);
            if (parsed.issues.isNotEmpty) {
              _snack('⚠️ Found ${parsed.issues.length} errors in CSV');
            } else {
              _snack('✅ Loaded ${parsed.rows.length} assignments');
            }
            break;
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    } catch (e) {
      _snack('Error: $e');
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importAll() async {
    final yearId = _newYearId.isNotEmpty ? _newYearId : _activeYearId;

    if (yearId.isEmpty) {
      _snack('No active year found');
      return;
    }

    setState(() => _busy = true);

    try {
      int totalImported = 0;

      // Import classes/sections
      if (_classSectionsData != null && !_classSectionsData!.hasErrors) {
        final classService = ClassSectionCsvImportService();
        final report = await classService.importClassSections(
          yearId: yearId,
          rows: _classSectionsData!.rows,
        );
        totalImported += report.successCount;
        _snack('✅ Imported ${report.successCount} class-sections');
      }

      // Import students
      if (_studentsData != null && _studentsData!.issues.isEmpty) {
        final report = await ref.read(studentCsvImportServiceProvider).importStudents(
              rows: _studentsData!.rows,
            );
        totalImported += report.successCount;
        _snack('✅ Imported ${report.successCount} students');
      }

      // Import parents
      if (_parentsData != null && _parentsData!.issues.isEmpty) {
        final report = await ref.read(parentCsvImportServiceProvider).importParents(
              rows: _parentsData!.rows,
            );
        totalImported += report.successCount;
        _snack('✅ Imported ${report.successCount} parents');
      }

      // Import teacher assignments
      if (_teacherAssignmentsData != null && _teacherAssignmentsData!.issues.isEmpty) {
        final report = await ref.read(teacherAssignmentCsvImportServiceProvider).importTeacherAssignments(
              rows: _teacherAssignmentsData!.rows,
              replaceExisting: true,
            );
        totalImported += report.successCount;
        _snack('✅ Imported ${report.successCount} assignments');
      }

      // Move to completion step
      setState(() => _currentStep = 4);

      _snack('🎉 Setup complete! Total: $totalImported records');
    } catch (e) {
      _snack('Import error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isCompact = media.size.width < 600;
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.05),
              theme.colorScheme.secondary.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              _buildStepperProgress(context),
              Expanded(
                child: _busy
                    ? const Center(child: LoadingView(message: 'Processing...'))
                    : _buildStepContent(context, isCompact),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'School Setup Wizard',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  'Complete in minutes',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepperProgress(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      color: Colors.white,
      child: Row(
        children: List.generate(5, (index) {
          final isActive = _currentStep == index;
          final isCompleted = _currentStep > index;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: isCompleted || isActive
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (index < 4) const SizedBox(width: 4),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent(BuildContext context, bool isCompact) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isCompact ? 16 : 32),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: _getStepWidget(),
        ),
      ),
    );
  }

  Widget _getStepWidget() {
    switch (_currentStep) {
      case 0:
        return _buildStep1AcademicYear();
      case 1:
        return _buildStep2ChooseMethod();
      case 2:
        return _buildStep3ImportData();
      case 3:
        return _buildStep4Preview();
      case 4:
        return _buildStep5Complete();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1AcademicYear() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(
            icon: Icons.calendar_today,
            title: 'Step 1: Academic Year',
            subtitle: 'Set up the academic year for your school',
          ),
          const SizedBox(height: 24),
          if (_activeYearId.isNotEmpty) ...[
            _infoBox(
              icon: Icons.info_outline,
              text: 'Current active year: $_activeYearId',
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'Create New Academic Year',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newYearController,
            decoration: InputDecoration(
              labelText: 'Year ID',
              hintText: 'e.g., 2026-27',
              prefixIcon: const Icon(Icons.calendar_month),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: _busy ? null : _createYear,
              icon: const Icon(Icons.add),
              label: const Text('Create & Continue'),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (_activeYearId.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _newYearId = _activeYearId;
                    _currentStep = 1;
                  });
                },
                child: Text('Use $_activeYearId'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep2ChooseMethod() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(
            icon: Icons.wb_auto,
            title: 'Step 2: Choose Setup Method',
            subtitle: 'How would you like to set up your data?',
          ),
          const SizedBox(height: 24),
          _methodCard(
            icon: Icons.upload_file,
            title: 'Import from CSV/Excel',
            subtitle: 'Recommended • Fast bulk import',
            isSelected: _setupMethod == 'import',
            onTap: () {
              setState(() {
                _setupMethod = 'import';
                _currentStep = 2;
              });
            },
          ),
          const SizedBox(height: 16),
          _methodCard(
            icon: Icons.edit,
            title: 'Manual Setup',
            subtitle: 'Add data one by one',
            isSelected: _setupMethod == 'manual',
            onTap: () {
              setState(() => _setupMethod = 'manual');
              _snack('Manual setup: Use individual screens from dashboard');
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStep3ImportData() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(
            icon: Icons.cloud_upload,
            title: 'Step 3: Import School Data',
            subtitle: 'Upload CSV files for each data type',
          ),
          const SizedBox(height: 24),
          _importButton(
            icon: Icons.class_,
            title: 'Import Classes & Sections',
            subtitle: _classSectionsData == null
                ? 'No file selected'
                : '${_classSectionsData!.rows.length} rows loaded',
            hasData: _classSectionsData != null,
            hasErrors: _classSectionsData?.issues.isNotEmpty ?? false,
            onTap: () => _pickAndParseCSV('classes'),
          ),
          const SizedBox(height: 12),
          _importButton(
            icon: Icons.badge,
            title: 'Import Students',
            subtitle: _studentsData == null
                ? 'No file selected'
                : '${_studentsData!.rows.length} rows loaded',
            hasData: _studentsData != null,
            hasErrors: _studentsData?.issues.isNotEmpty ?? false,
            onTap: () => _pickAndParseCSV('students'),
          ),
          const SizedBox(height: 12),
          _importButton(
            icon: Icons.family_restroom,
            title: 'Import Parents',
            subtitle: _parentsData == null
                ? 'No file selected (optional)'
                : '${_parentsData!.rows.length} rows loaded',
            hasData: _parentsData != null,
            hasErrors: _parentsData?.issues.isNotEmpty ?? false,
            onTap: () => _pickAndParseCSV('parents'),
          ),
          const SizedBox(height: 12),
          _importButton(
            icon: Icons.assignment,
            title: 'Import Teacher Assignments',
            subtitle: _teacherAssignmentsData == null
                ? 'No file selected (optional)'
                : '${_teacherAssignmentsData!.rows.length} rows loaded',
            hasData: _teacherAssignmentsData != null,
            hasErrors: _teacherAssignmentsData?.issues.isNotEmpty ?? false,
            onTap: () => _pickAndParseCSV('assignments'),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _currentStep = 1),
                  child: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: (_classSectionsData != null || _studentsData != null)
                      ? () => setState(() => _currentStep = 3)
                      : null,
                  child: const Text('Preview & Import'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep4Preview() {
    final yearId = _newYearId.isNotEmpty ? _newYearId : _activeYearId;
    int totalRecords = 0;
    int totalErrors = 0;

    if (_classSectionsData != null) {
      totalRecords += _classSectionsData!.rows.length;
      totalErrors += _classSectionsData!.issues.length;
    }
    if (_studentsData != null) {
      totalRecords += _studentsData!.rows.length;
      totalErrors += _studentsData!.issues.length;
    }
    if (_parentsData != null) {
      totalRecords += _parentsData!.rows.length;
      totalErrors += _parentsData!.issues.length;
    }
    if (_teacherAssignmentsData != null) {
      totalRecords += _teacherAssignmentsData!.rows.length;
      totalErrors += _teacherAssignmentsData!.issues.length;
    }

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(
            icon: Icons.preview,
            title: 'Step 4: Preview & Confirm',
            subtitle: 'Review before importing',
          ),
          const SizedBox(height: 24),
          _infoBox(
            icon: Icons.school,
            text: 'Importing to year: $yearId',
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          _previewCard('Classes/Sections', _classSectionsData?.rows.length ?? 0, _classSectionsData?.issues.length ?? 0),
          const SizedBox(height: 8),
          _previewCard('Students', _studentsData?.rows.length ?? 0, _studentsData?.issues.length ?? 0),
          const SizedBox(height: 8),
          _previewCard('Parents', _parentsData?.rows.length ?? 0, _parentsData?.issues.length ?? 0),
          const SizedBox(height: 8),
          _previewCard('Teacher Assignments', _teacherAssignmentsData?.rows.length ?? 0, _teacherAssignmentsData?.issues.length ?? 0),
          const SizedBox(height: 24),
          if (totalErrors > 0)
            _infoBox(
              icon: Icons.warning,
              text: '⚠️ $totalErrors errors found. Fix errors before importing.',
              color: Colors.orange,
            ),
          if (totalErrors == 0) ...[
            _infoBox(
              icon: Icons.check_circle,
              text: '✅ $totalRecords records ready to import',
              color: Colors.green,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _currentStep = 2),
                    child: const Text('Back'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _importAll,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Import Now'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep5Complete() {
    return _glassCard(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green.withValues(alpha: 0.1),
            ),
            child: const Icon(
              Icons.check_circle,
              size: 80,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '✅ Setup Complete!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Your school data has been imported successfully.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.dashboard),
              label: const Text('Go to Dashboard'),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widgets
  Widget _glassCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: child,
    );
  }

  Widget _stepHeader({required IconData icon, required String title, required String subtitle}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoBox({required IconData icon, required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color.withValues(alpha: 0.9)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _methodCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey[700],
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _importButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool hasData,
    required bool hasErrors,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hasErrors
              ? Colors.red.withValues(alpha: 0.05)
              : hasData
                  ? Colors.green.withValues(alpha: 0.05)
                  : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasErrors
                ? Colors.red
                : hasData
                    ? Colors.green
                    : Colors.grey[300]!,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: hasErrors ? Colors.red : hasData ? Colors.green : Colors.grey),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              hasErrors
                  ? Icons.error
                  : hasData
                      ? Icons.check_circle
                      : Icons.upload_file,
              color: hasErrors ? Colors.red : hasData ? Colors.green : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewCard(String label, int total, int errors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Row(
            children: [
              if (total > 0)
                Text(
                  '$total records',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              if (errors > 0) ...[
                const SizedBox(width: 8),
                Icon(Icons.error, color: Colors.red, size: 16),
                const SizedBox(width: 4),
                Text('$errors errors', style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
