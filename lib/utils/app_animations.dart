import 'package:flutter/material.dart';

/// Modern animation curves and transitions
class AppAnimations {
  /// Smooth entrance animation
  static Widget fadeInUp({
    required Widget child,
    Duration duration = const Duration(milliseconds: 600),
    double beginOpacity = 0,
    double endOpacity = 1,
    Offset beginOffset = const Offset(0, 30),
    Offset endOffset = Offset.zero,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: beginOpacity + (endOpacity - beginOpacity) * value,
          child: Transform.translate(
            offset: Offset(
              beginOffset.dx + (endOffset.dx - beginOffset.dx) * value,
              beginOffset.dy + (endOffset.dy - beginOffset.dy) * value,
            ),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  /// Pop entrance animation (scale + fade)
  static Widget popIn({
    required Widget child,
    Duration duration = const Duration(milliseconds: 400),
    Curve curve = Curves.elasticOut,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(scale: value, child: child),
        );
      },
      child: child,
    );
  }

  /// Slide transition
  static Route slideTransition({
    required Widget page,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return PageRouteBuilder(
      transitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.ease;

        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  /// Fade transition
  static Route fadeTransition({
    required Widget page,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return PageRouteBuilder(
      transitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  /// Scale transition
  static Route scaleTransition({
    required Widget page,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return PageRouteBuilder(
      transitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(scale: animation, child: child);
      },
    );
  }

  /// Shimmer loading effect
  static Widget shimmer({
    required Widget child,
    Duration duration = const Duration(milliseconds: 1000),
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: -2, end: 2),
      duration: duration,
      curve: Curves.linear,
      onEnd: () => TweenAnimationBuilder(
        tween: Tween(begin: -2, end: 2),
        duration: duration,
        curve: Curves.linear,
        builder: (_, __, ___) => Container(),
      ),
      builder: (context, value, child) {
        return ShaderMask(
          blendMode: BlendMode.lighten,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(value - 1, 0),
              end: Alignment(value + 1, 0),
              colors: [
                Colors.grey.shade300,
                Colors.grey.shade100,
                Colors.grey.shade300,
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }

  /// Pulse animation
  static Widget pulse({
    required Widget child,
    Duration duration = const Duration(milliseconds: 1500),
    double beginScale = 1,
    double endScale = 1.1,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: beginScale, end: endScale),
      duration: duration ~/ 2,
      curve: Curves.easeInOut,
      onEnd: () => TweenAnimationBuilder(
        tween: Tween(begin: endScale, end: beginScale),
        duration: duration ~/ 2,
        curve: Curves.easeInOut,
        builder: (_, __, ___) => Container(),
      ),
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: child,
    );
  }

  /// Bounce animation
  static Widget bounce({
    required Widget child,
    Duration duration = const Duration(milliseconds: 400),
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, -20 * value),
          child: child,
        );
      },
      child: child,
    );
  }
}

/// Modern page transition
class ModernPageTransition<T> extends MaterialPageRoute<T> {
  ModernPageTransition({
    required WidgetBuilder builder,
    RouteSettings? settings,
    bool maintainState = true,
    bool fullscreenDialog = false,
    Duration transitionDuration = const Duration(milliseconds: 400),
  }) : super(
    builder: builder,
    settings: settings,
    maintainState: maintainState,
    fullscreenDialog: fullscreenDialog,
  );

  @override
  Duration get transitionDuration => const Duration(milliseconds: 400);

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }
}

/// Debounced callback builder
class DebounceButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;
  final Duration debounce;

  const DebounceButton({
    Key? key,
    required this.onPressed,
    required this.child,
    this.debounce = const Duration(milliseconds: 500),
  }) : super(key: key);

  @override
  State<DebounceButton> createState() => _DebounceButtonState();
}

class _DebounceButtonState extends State<DebounceButton> {
  late Future<void> _lastCall;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _lastCall = Future.value();
  }

  void _onPressed() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      await _lastCall;
      widget.onPressed();
    } finally {
      if (mounted) {
        await Future.delayed(widget.debounce);
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isLoading ? null : _onPressed,
      child: Opacity(
        opacity: _isLoading ? 0.6 : 1,
        child: widget.child,
      ),
    );
  }
}
