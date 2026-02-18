import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Placeholder for teacher exam results entry.
/// 
/// Teachers use the existing exam marks entry screens. This screen is a stub
/// for future enhancement when a dedicated teacher results entry workflow is needed.
/// The approval workflow is managed by admins in admin_exam_results_management_screen.dart.
class TeacherExamResultsEntryScreen extends ConsumerWidget {
  const TeacherExamResultsEntryScreen({
    super.key,
    required this.yearId,
  });

  final String yearId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Results Entry'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Results Entry',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Teachers enter exam marks through the standard subject marks entry interface.\n\n'
                    'Results appear as "Draft" until approved by Admin.\n\n'
                    'Parents will see results only after Admin publishes them.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
