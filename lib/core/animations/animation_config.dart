import 'package:flutter/material.dart';

/// Centralized animation configuration for consistent animation patterns across the app.
class AnimationConfig {
  // Duration Constants
  static const Duration kFastDuration = Duration(milliseconds: 300);
  static const Duration kDefaultDuration = Duration(milliseconds: 500);
  static const Duration kSlowDuration = Duration(milliseconds: 700);

  // Splash-specific durations
  static const Duration kSplashLogoDuration = Duration(milliseconds: 400);
  static const Duration kSplashTaglineDuration = Duration(milliseconds: 300);
  static const Duration kSplashProgressDuration = Duration(milliseconds: 200);
  static const Duration kSplashTaglineWordStagger = Duration(milliseconds: 100);
  static const Duration kSplashMinimumDisplay = Duration(milliseconds: 2000);

  // Curve Constants
  static const Curve kDefaultCurve = Curves.easeInOutCubic;
  static const Curve kEntryCurve = Curves.easeOut;
  static const Curve kExitCurve = Curves.easeIn;
  static const Curve kBouncyCurve = Curves.elasticOut;

  // Animation Delays
  static const Duration kModalEnterDelay = Duration(milliseconds: 0);
  static const Duration kFormFieldStagger = Duration(milliseconds: 50);
  static const Duration kListItemStagger = Duration(milliseconds: 50);

  // Page Transition - Slide + Fade Combo
  static const Duration kPageTransitionDuration = Duration(milliseconds: 500);
  static const Curve kPageTransitionCurve = Curves.easeInOutCubic;
  static const double kPageSlideDistance = 1.0; // Full screen width
}
