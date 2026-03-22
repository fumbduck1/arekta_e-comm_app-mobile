import 'package:flutter/material.dart';
import 'animation_config.dart';

/// Custom PageRoute with combined Slide + Fade transition animation.
/// Slides from right (-1.0 to 0.0) and fades in (0.0 to 1.0) simultaneously.
class CustomPageRoute<T> extends PageRoute<T> {
  CustomPageRoute({
    required this.builder,
    required RouteSettings settings,
    required this.duration,
    required this.transitionCurve,
  }) : super(settings: settings);

  final WidgetBuilder builder;
  final Duration duration;
  final Curve transitionCurve;

  @override
  Color? get barrierColor => null;

  @override
  String get barrierLabel => '';

  @override
  bool get barrierDismissible => false;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => duration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Create combined animation: Slide + Fade
    // Slide: from right (offset -1.0) to center (0.0)
    final slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: transitionCurve));

    // Fade: from transparent (0.0) to opaque (1.0)
    final fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: animation, curve: transitionCurve));

    // Combine both animations using Listenable.merge()
    return SlideTransition(
      position: slideAnimation,
      child: FadeTransition(opacity: fadeAnimation, child: child),
    );
  }

  Widget buildSecondaryTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Optional: Add exit animation for the previous page
    // Fade out slightly as new page slides in
    final slideAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(-0.3, 0.0)).animate(
          CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeIn),
        );

    final fadeAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeIn),
    );

    return SlideTransition(
      position: slideAnimation,
      child: FadeTransition(opacity: fadeAnimation, child: child),
    );
  }
}

/// Factory function to create CustomPageRoute with default config
CustomPageRoute<T> createCustomPageRoute<T>({
  required WidgetBuilder builder,
  required RouteSettings settings,
  Duration? duration,
  Curve? curve,
}) {
  return CustomPageRoute<T>(
    builder: builder,
    settings: settings,
    duration: duration ?? AnimationConfig.kPageTransitionDuration,
    transitionCurve: curve ?? AnimationConfig.kPageTransitionCurve,
  );
}
