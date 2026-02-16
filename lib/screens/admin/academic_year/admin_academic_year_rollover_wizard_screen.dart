import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../services/academic_year_admin_service.dart';
import '../../../widgets/loading_view.dart';

class AdminAcademicYearRolloverWizardScreen extends ConsumerStatefulWidget {
  const AdminAcademicYearRolloverWizardScreen({
    super.key,
    required this.activeYearId,
  });

  final String activeYearId;

  @override
  ConsumerState<AdminAcademicYearRolloverWizardScreen> createState() => _AdminAcademicYearRolloverWizardScreenState();
}

class _AdminAcademicYearRolloverWizardScreenState extends ConsumerState<AdminAcademicYearRolloverWizardScreen> {
  int _step = 0;

  late final TextEditingController _fromCtrl;
  late final TextEditingController _toCtrl;
  late final TextEditingController _finalClassCtrl;

  bool _onlyActiveStudents = true;
  bool _copyClassSections = true;
  bool _setActiveAfter = true;

  bool _busy = false;
  String? _busyMessage;

  RolloverPreview? _preview;
  String? _previewError;

  @override
  void initState() {
    super.initState();
    _fromCtrl = TextEditingController(text: widget.activeYearId);
    _toCtrl = TextEditingController();
    _finalClassCtrl = TextEditingController(text: '10');
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _finalClassCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  int? _finalClass() {
    final n = int.tryParse(_finalClassCtrl.text.trim());
    return n;
  }

  Future<void> _createYearIfNeeded() async {
    final toYear = _toCtrl.text.trim();
    if (toYear.isEmpty) {
      _snack('Please enter the new academic year ID');
      return;
    }

    setState(() {
      _busy = true;
      _busyMessage = 'Creating academic year…';
    });

    try {
      await ref.read(academicYearAdminServiceProvider).createAcademicYear(yearId: toYear, label: toYear);
      if (!mounted) return;
      _snack('Year created/ensured');
    } catch (e) {
      if (!mounted) return;
      _snack('Failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _runPreview() async {
    final toYear = _toCtrl.text.trim();
    if (toYear.isEmpty) {
      _snack('Please enter the new academic year ID');
      return;
    }

    final finalClass = _finalClass();
    if (finalClass == null || finalClass < 1) {
      _snack('Final class must be a number (example: 10)');
      return;
    }

    setState(() {
      _preview = null;
      _previewError = null;
      _busy = true;
      _busyMessage = 'Preparing preview…';
    });

    try {
      final p = await ref.read(academicYearAdminServiceProvider).previewPromotion(
            finalClassNumber: finalClass,
            onlyActiveStudents: _onlyActiveStudents,
          );
      if (!mounted) return;
      setState(() {
        _preview = p;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _previewError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _execute() async {
    final fromYear = _fromCtrl.text.trim();
    final toYear = _toCtrl.text.trim();

    if (fromYear.isEmpty || toYear.isEmpty) {
      _snack('Please fill From/To year');
      return;
    }

    final finalClass = _finalClass();
    if (finalClass == null || finalClass < 1) {
      _snack('Final class must be a number');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm rollover'),
        content: Text(
          'This will promote base students and (optionally) copy year class/sections.\n\n'
          'From: $fromYear\n'
          'To: $toYear\n'
          'Final class: $finalClass\n\n'
          'Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Run')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _busy = true;
      _busyMessage = 'Starting…';
    });

    try {
      await ref.read(academicYearAdminServiceProvider).rolloverAndPromoteStudents(
            fromYearId: fromYear,
            toYearId: toYear,
            finalClassNumber: finalClass,
            onlyActiveStudents: _onlyActiveStudents,
            copyClassSections: _copyClassSections,
            setActiveYearAfter: _setActiveAfter,
            onProgress: (p) {
              if (!mounted) return;
              setState(() {
                _busyMessage = p.message;
              });
            },
          );

      if (!mounted) return;
      _snack('Rollover completed');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _snack('Failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(firebaseAuthUserProvider).asData?.value;
    if (authUser == null) {
      return const Scaffold(body: Center(child: Text('Please login again.')));
    }

    final preview = _preview;

    return Scaffold(
      appBar: AppBar(title: const Text('Academic Year Rollover Wizard')),
      body: Stack(
        children: [
          Stepper(
            currentStep: _step,
            onStepContinue: _busy
                ? null
                : () {
                    if (_step < 2) {
                      setState(() => _step++);
                    }
                  },
            onStepCancel: _busy
                ? null
                : () {
                    if (_step > 0) setState(() => _step--);
                  },
            steps: [
              Step(
                title: const Text('1) Year settings'),
                isActive: _step >= 0,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _fromCtrl,
                      decoration: const InputDecoration(
                        labelText: 'From year (current/closing year)',
                        hintText: 'example: 2025-26',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _toCtrl,
                      decoration: const InputDecoration(
                        labelText: 'To year (new year)',
                        hintText: 'example: 2026-27',
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _busy ? null : _createYearIfNeeded,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Create/ensure new academic year'),
                    ),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      value: _setActiveAfter,
                      onChanged: _busy ? null : (v) => setState(() => _setActiveAfter = v ?? true),
                      title: const Text('Set new year as active after rollover'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      value: _copyClassSections,
                      onChanged: _busy ? null : (v) => setState(() => _copyClassSections = v ?? true),
                      title: const Text('Copy year class/sections to new year'),
                      subtitle: const Text('Helps teacher assignment UI in the new year.'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              Step(
                title: const Text('2) Promotion settings'),
                isActive: _step >= 1,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _finalClassCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Final class number',
                        hintText: 'example: 10',
                      ),
                    ),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      value: _onlyActiveStudents,
                      onChanged: _busy ? null : (v) => setState(() => _onlyActiveStudents = v ?? true),
                      title: const Text('Only promote active students'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _busy ? null : _runPreview,
                      icon: const Icon(Icons.preview_outlined),
                      label: const Text('Preview changes'),
                    ),
                    if (_previewError != null) ...[
                      const SizedBox(height: 8),
                      Text('Preview error: $_previewError', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                    if (preview != null) ...[
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Students considered: ${preview.consideredStudents}'),
                              Text('To promote: ${preview.promoteCount}'),
                              Text('To mark as alumni: ${preview.alumniCount}'),
                              Text('Skipped (needs fixing): ${preview.skippedCount}'),
                              if (preview.issues.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                const Text('Examples of skipped:', style: TextStyle(fontWeight: FontWeight.w700)),
                                for (final i in preview.issues.take(10))
                                  Text('${i.studentId}: ${i.message}', style: const TextStyle(fontSize: 12)),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Step(
                title: const Text('3) Run rollover'),
                isActive: _step >= 2,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'This will batch-update student records. You can keep the app open and watch progress.\n\n'
                      'Note: Students with non-numeric class (like KG) will be skipped; fix them and run again.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _busy ? null : _execute,
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Run rollover now'),
                    ),
                  ],
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
                          const SizedBox(height: 10),
                          if (_busyMessage != null) Text(_busyMessage!, textAlign: TextAlign.center),
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
  }
}
