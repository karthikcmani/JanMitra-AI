// ignore_for_file: deprecated_member_use, unnecessary_underscores
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/grievance.dart';
import '../theme/app_theme.dart';

// --- Custom Glassmorphic Card ---
class CustomGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? borderColor;
  final List<Color>? gradientColors;

  const CustomGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.borderColor,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark ? AppTheme.darkCard : AppTheme.lightCard;
    final defaultBorder = isDark ? AppTheme.darkCardBorder : AppTheme.lightCardBorder;

    Widget content = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: gradientColors == null ? defaultBg : null,
        gradient: gradientColors != null
            ? LinearGradient(
                colors: gradientColors!,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? defaultBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: content,
        ),
      );
    }

    return content;
  }
}

// --- Status Badge Widget ---
class StatusBadge extends StatelessWidget {
  final GrievanceStatus status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Priority Badge Widget ---
class PriorityBadge extends StatelessWidget {
  final GrievancePriority priority;

  const PriorityBadge({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    final color = priority.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        priority.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// --- Category Badge Widget ---
class CategoryBadge extends StatelessWidget {
  final GrievanceCategory category;

  const CategoryBadge({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon, size: 13, color: AppTheme.primaryBlue),
          const SizedBox(width: 5),
          Text(
            category.label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Metric Card Widget ---
class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtext;
  final IconData icon;
  final Color iconColor;
  final LinearGradient? gradient;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtext,
    required this.icon,
    required this.iconColor,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomGlassCard(
      gradientColors: gradient?.colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                  color: gradient != null
                      ? Colors.white.withOpacity(0.85)
                      : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: gradient != null
                      ? Colors.white.withOpacity(0.2)
                      : iconColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: gradient != null ? Colors.white : iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: gradient != null
                  ? Colors.white
                  : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: gradient != null
                  ? Colors.white.withOpacity(0.9)
                  : AppTheme.accentTeal,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Interactive Timeline Widget ---
class TimelineWidget extends StatelessWidget {
  final List<TimelineStep> steps;

  const TimelineWidget({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final subText = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isLast = index == steps.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline line and circle node
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: step.isCompleted
                          ? AppTheme.successGreen
                          : AppTheme.warningAmber.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: step.isCompleted ? AppTheme.successGreen : AppTheme.warningAmber,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        step.isCompleted ? Icons.check : Icons.hourglass_top_rounded,
                        size: 13,
                        color: step.isCompleted ? Colors.white : AppTheme.warningAmber,
                      ),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: step.isCompleted
                            ? AppTheme.successGreen.withOpacity(0.6)
                            : isDark
                                ? AppTheme.darkCardBorder
                                : AppTheme.lightCardBorder,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              // Timeline step description
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              step.title,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: primaryText,
                              ),
                            ),
                          ),
                          Text(
                            step.timestamp,
                            style: TextStyle(
                              fontSize: 11,
                              color: subText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        step.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: subText,
                          height: 1.3,
                        ),
                      ),
                      if (step.actor != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.person_outline, size: 12, color: AppTheme.primaryBlue),
                            const SizedBox(width: 4),
                            Text(
                              step.actor!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// --- Custom Analytics Donut Chart Painter ---
class DonutChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;

  DonutChartPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final double total = values.fold(0, (sum, item) => sum + item);
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);
    final strokeWidth = radius * 0.38;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    double startAngle = -pi / 2;

    for (int i = 0; i < values.length; i++) {
      final sweepAngle = (values[i] / total) * 2 * pi - 0.05; // small gap
      paint.color = colors[i % colors.length];

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        max(0, sweepAngle),
        false,
        paint,
      );

      startAngle += sweepAngle + 0.05;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- Custom Bar Chart Painter ---
class BarChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color barColor;
  final Color gridColor;

  BarChartPainter({
    required this.values,
    required this.labels,
    required this.barColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double maxVal = values.fold(1, (m, v) => max(m, v));
    final double chartHeight = size.height - 24;
    final double barWidth = (size.width / values.length) * 0.55;
    final double spacing = size.width / values.length;

    final paintGrid = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    // Draw horizontal grid lines
    for (int i = 0; i <= 3; i++) {
      final y = chartHeight * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }

    final paintBar = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < values.length; i++) {
      final val = values[i];
      final height = (val / maxVal) * chartHeight;
      final x = (i * spacing) + (spacing - barWidth) / 2;
      final y = chartHeight - height;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, height),
        const Radius.circular(6),
      );

      canvas.drawRRect(rect, paintBar);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
