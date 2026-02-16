import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_logo.dart';

class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    this.footer,
    this.onBack,
    this.maxWidth = 980,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final List<Widget>? footer;
  final VoidCallback? onBack;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primaryContainer.withValues(alpha: 0.55),
              scheme.surface,
              scheme.secondaryContainer.withValues(alpha: 0.45),
            ],
            stops: const [0, 0.55, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: isWide
                    ? Row(
                        children: [
                          Expanded(
                            child: _LeftHero(
                              title: title,
                              subtitle: subtitle,
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 460,
                            child: _AuthCard(
                              onBack: onBack,
                              footer: footer,
                              child: child,
                            ),
                          ),
                        ],
                      )
                    : _AuthCard(
                        onBack: onBack,
                        footer: footer,
                        child: child,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.child,
    required this.footer,
    required this.onBack,
  });

  final Widget child;
  final List<Widget>? footer;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    const headerSlot = 48.0;

    return Card(
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (onBack != null)
                  IconButton(
                    tooltip: 'Back',
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                  )
                else
                  const SizedBox(width: headerSlot),
                const Expanded(
                  child: Center(
                    child: AppLogo(height: 58),
                  ),
                ),
                const SizedBox(width: headerSlot),
              ],
            ),
            const SizedBox(height: 10),
            child,
            if (footer != null && footer!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...footer!,
            ],
          ],
        ),
      ),
    );
  }
}

class _LeftHero extends StatelessWidget {
  const _LeftHero({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primary.withValues(alpha: 0.85),
                    scheme.tertiary.withValues(alpha: 0.7),
                    scheme.secondary.withValues(alpha: 0.6),
                  ],
                ),
              ),
              child: CustomPaint(
                painter: _DotsPainter(color: scheme.onPrimary.withValues(alpha: 0.12)),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppLogo(height: 76),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onPrimary,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: scheme.onPrimary.withValues(alpha: 0.9),
                        ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Tip: Start with Admin → Setup Wizard to create classes, teacher, parent, and students.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onPrimary.withValues(alpha: 0.92),
                        ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(Icons.lock_outline, color: scheme.onPrimary.withValues(alpha: 0.9)),
                      const SizedBox(width: 8),
                      Text(
                        'Secure Firebase login',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onPrimary.withValues(alpha: 0.92),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
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

class _DotsPainter extends CustomPainter {
  const _DotsPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    const gap = 28.0;
    final r = math.max(1.4, math.min(2.2, size.shortestSide / 250));

    for (double y = 0; y < size.height; y += gap) {
      for (double x = 0; x < size.width; x += gap) {
        final dx = (y / gap).floor().isEven ? x : x + gap / 2;
        canvas.drawCircle(Offset(dx, y), r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPainter oldDelegate) => oldDelegate.color != color;
}
