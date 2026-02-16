import 'package:flutter/material.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.title,
    required this.message,
    this.primaryActionLabel,
    this.onPrimaryAction,
  });

  final String title;
  final String message;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
        ),
        if (primaryActionLabel != null && onPrimaryAction != null) ...[
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onPrimaryAction,
            child: Text(primaryActionLabel!),
          ),
        ],
      ],
    );
  }
}
