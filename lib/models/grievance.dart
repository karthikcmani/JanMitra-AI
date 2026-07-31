import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum GrievanceStatus {
  submitted,
  underReview,
  inProgress,
  resolved,
  escalated,
}

extension GrievanceStatusExtension on GrievanceStatus {
  String get label {
    switch (this) {
      case GrievanceStatus.submitted:
        return 'Submitted';
      case GrievanceStatus.underReview:
        return 'Under AI Triage';
      case GrievanceStatus.inProgress:
        return 'Work In Progress';
      case GrievanceStatus.resolved:
        return 'Resolved';
      case GrievanceStatus.escalated:
        return 'Escalated (SLA Alert)';
    }
  }

  Color get color {
    switch (this) {
      case GrievanceStatus.submitted:
        return AppTheme.primaryBlue;
      case GrievanceStatus.underReview:
        return AppTheme.aiPurple;
      case GrievanceStatus.inProgress:
        return AppTheme.warningAmber;
      case GrievanceStatus.resolved:
        return AppTheme.successGreen;
      case GrievanceStatus.escalated:
        return AppTheme.dangerRed;
    }
  }

  IconData get icon {
    switch (this) {
      case GrievanceStatus.submitted:
        return Icons.send_rounded;
      case GrievanceStatus.underReview:
        return Icons.psychology_rounded;
      case GrievanceStatus.inProgress:
        return Icons.build_circle_rounded;
      case GrievanceStatus.resolved:
        return Icons.check_circle_rounded;
      case GrievanceStatus.escalated:
        return Icons.warning_amber_rounded;
    }
  }
}

enum GrievancePriority {
  urgent,
  high,
  medium,
  low,
}

extension GrievancePriorityExtension on GrievancePriority {
  String get label {
    switch (this) {
      case GrievancePriority.urgent:
        return 'P1 - Urgent';
      case GrievancePriority.high:
        return 'P2 - High';
      case GrievancePriority.medium:
        return 'P3 - Medium';
      case GrievancePriority.low:
        return 'P4 - Low';
    }
  }

  Color get color {
    switch (this) {
      case GrievancePriority.urgent:
        return AppTheme.dangerRed;
      case GrievancePriority.high:
        return AppTheme.warningAmber;
      case GrievancePriority.medium:
        return AppTheme.primaryBlue;
      case GrievancePriority.low:
        return AppTheme.accentTeal;
    }
  }
}

enum GrievanceCategory {
  waterSupply,
  roadsAndInfrastructure,
  electricity,
  sanitation,
  publicHealth,
  streetlights,
  publicTransport,
}

extension GrievanceCategoryExtension on GrievanceCategory {
  String get label {
    switch (this) {
      case GrievanceCategory.waterSupply:
        return 'Water Supply';
      case GrievanceCategory.roadsAndInfrastructure:
        return 'Roads & Infrastructure';
      case GrievanceCategory.electricity:
        return 'Electricity & Power';
      case GrievanceCategory.sanitation:
        return 'Sanitation & Waste';
      case GrievanceCategory.publicHealth:
        return 'Public Health';
      case GrievanceCategory.streetlights:
        return 'Street Lighting';
      case GrievanceCategory.publicTransport:
        return 'Public Transport';
    }
  }

  IconData get icon {
    switch (this) {
      case GrievanceCategory.waterSupply:
        return Icons.water_drop_rounded;
      case GrievanceCategory.roadsAndInfrastructure:
        return Icons.add_road_rounded;
      case GrievanceCategory.electricity:
        return Icons.electric_bolt_rounded;
      case GrievanceCategory.sanitation:
        return Icons.cleaning_services_rounded;
      case GrievanceCategory.publicHealth:
        return Icons.health_and_safety_rounded;
      case GrievanceCategory.streetlights:
        return Icons.lightbulb_rounded;
      case GrievanceCategory.publicTransport:
        return Icons.directions_bus_rounded;
    }
  }
}

class TimelineStep {
  final String title;
  final String timestamp;
  final String description;
  final bool isCompleted;
  final String? actor;

  TimelineStep({
    required this.title,
    required this.timestamp,
    required this.description,
    required this.isCompleted,
    this.actor,
  });
}

class Grievance {
  final String id;
  final String title;
  final String description;
  final GrievanceCategory category;
  final GrievancePriority priority;
  GrievanceStatus status;
  final int urgencyScore; // 0 to 100
  final String location;
  final String ward;
  final int duplicateCount;
  final DateTime filedAt;
  DateTime? resolvedAt;
  final String assignedOfficer;
  final String aiActionRecommendation;
  final String sentiment; // e.g. "Severe Frustration", "High Concern", "Neutral"
  final String? similarityAlert;
  int upvotes;

  final List<TimelineStep> timeline;

  Grievance({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    required this.urgencyScore,
    required this.location,
    required this.ward,
    required this.duplicateCount,
    required this.filedAt,
    this.resolvedAt,
    required this.assignedOfficer,
    required this.aiActionRecommendation,
    required this.sentiment,
    this.similarityAlert,
    this.upvotes = 1,
    required this.timeline,
  });
}
