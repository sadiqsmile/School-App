import 'package:flutter/material.dart';

/// Modern card component with gradient support
class ModernCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final Color? backgroundColor;
  final Gradient? gradient;
  final double borderRadius;
  final VoidCallback? onTap;
  final BorderSide? border;

  const ModernCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.all(0),
    this.backgroundColor,
    this.gradient,
    this.borderRadius = 12,
    this.onTap,
    this.border,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final container = Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: gradient == null ? (backgroundColor ?? Colors.white) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: child,
    );

    return onTap != null
        ? Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(borderRadius),
              child: container,
            ),
          )
        : container;
  }
}

/// Modern empty state widget
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;
  final Widget? action;

  const EmptyStateWidget({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    this.action,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: (iconColor ?? Colors.blue).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 64,
              color: iconColor ?? Colors.blue,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 24),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Modern error state widget
class ErrorStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  const ErrorStateWidget({
    Key? key,
    required this.title,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.red,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Modern loading state widget
class LoadingStateWidget extends StatelessWidget {
  final String? message;
  final bool showBackground;

  const LoadingStateWidget({
    Key? key,
    this.message,
    this.showBackground = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const CircularProgressIndicator(
            strokeWidth: 2.5,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 20),
          Text(
            message!,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );

    return showBackground
        ? Center(child: content)
        : SizedBox.expand(
            child: Center(child: content),
          );
  }
}

/// Modern header widget with gradient
class ModernHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  final Color? backgroundColor;
  final Gradient? gradient;

  const ModernHeader({
    Key? key,
    required this.title,
    this.subtitle,
    this.action,
    this.backgroundColor,
    this.gradient,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: gradient == null ? (backgroundColor ?? Colors.blue) : null,
        gradient: gradient,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(16),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withOpacity(0.9),
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (action != null) action!,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Modern info card
class InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? color;
  final double? width;

  const InfoCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.value,
    this.color,
    this.width,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? Colors.blue;
    return SizedBox(
      width: width,
      child: ModernCard(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cardColor,
            cardColor.withOpacity(0.8),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modern status badge
class StatusBadge extends StatelessWidget {
  final String label;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;

  const StatusBadge({
    Key? key,
    required this.label,
    this.backgroundColor,
    this.textColor,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? Colors.blue;
    final textCol = textColor ?? Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bgColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: bgColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: bgColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Modern divider with label
class LabeledDivider extends StatelessWidget {
  final String label;
  final Color? color;

  const LabeledDivider({
    Key? key,
    required this.label,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dividerColor = color ?? Colors.grey.shade300;
    return Row(
      children: [
        Expanded(child: Divider(color: dividerColor)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: dividerColor)),
      ],
    );
  }
}
