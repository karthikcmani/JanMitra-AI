import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'JanMitra AI';
  static const String appTagline =
      'AI-assisted Public Grievance Intelligence Platform';
  static const String appSubtitle =
      'AI-assisted Public Grievance Intelligence and Administrative Decision Support Platform';
  static const String appVersion = 'Version 1.0.0';

  // Layout Spacing
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double cardRadius = 18.0;

  // Animation Durations
  static const Duration splashDuration = Duration(milliseconds: 2500);
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animNormal = Duration(milliseconds: 350);

  // Decorative Shadows
  static const List<BoxShadow> softShadow = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4)),
  ];
}
