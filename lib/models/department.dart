import 'package:flutter/material.dart';

class DepartmentMetric {
  final String name;
  final IconData icon;
  final int totalComplaints;
  final int resolvedComplaints;
  final int pendingComplaints;
  final double slaCompliancePercent; // e.g. 94.2%
  final double avgResolutionHours; // e.g. 18.5 hrs
  final double satisfactionScore; // e.g. 4.6 / 5.0
  final List<double> weeklyTrend; // Trend data points for charting

  DepartmentMetric({
    required this.name,
    required this.icon,
    required this.totalComplaints,
    required this.resolvedComplaints,
    required this.pendingComplaints,
    required this.slaCompliancePercent,
    required this.avgResolutionHours,
    required this.satisfactionScore,
    required this.weeklyTrend,
  });
}
