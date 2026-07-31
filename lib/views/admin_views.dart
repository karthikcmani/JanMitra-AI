// ignore_for_file: deprecated_member_use, unnecessary_underscores
import 'package:flutter/material.dart';
import '../models/grievance.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'citizen_views.dart';

class AdminDashboardView extends StatelessWidget {
  final VoidCallback onNavigateToTriage;
  final VoidCallback onNavigateToHeatmap;
  final VoidCallback onNavigateToAnalytics;

  const AdminDashboardView({
    super.key,
    required this.onNavigateToTriage,
    required this.onNavigateToHeatmap,
    required this.onNavigateToAnalytics,
  });

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSub = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    final escalatedGrievances = appState.grievances
        .where((g) => g.status == GrievanceStatus.escalated || g.priority == GrievancePriority.urgent)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner
          CustomGlassCard(
            gradientColors: const [Color(0xFF1E1B4B), Color(0xFF312E81)],
            borderColor: AppTheme.aiPurple.withOpacity(0.6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.aiPurple.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.admin_panel_settings_rounded, size: 14, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'ADMINISTRATIVE DECISION SUPPORT ENGINE',
                            style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const Row(
                      children: [
                        Icon(Icons.auto_graph_rounded, size: 14, color: AppTheme.accentTeal),
                        SizedBox(width: 4),
                        Text('SLA AI GUARDIAN', style: TextStyle(color: AppTheme.accentTeal, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'District Governance Intelligence & SLA Analytics Dashboard',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Real-time automated triage, spatial bottleneck clustering, and departmental resource optimization for municipal authorities.',
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Executive Summary 4-Metric Grid
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  title: 'Total Complaints',
                  value: '${appState.totalCount}',
                  subtext: 'Across 5 Wards',
                  icon: Icons.receipt_long_rounded,
                  iconColor: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  title: 'SLA Compliance',
                  value: '${appState.overallSlaCompliance.toStringAsFixed(1)}%',
                  subtext: '+2.4% vs last week',
                  icon: Icons.speed_rounded,
                  iconColor: AppTheme.successGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  title: 'SLA Escalations',
                  value: '${appState.escalatedCount}',
                  subtext: 'Requires Immediate Action',
                  icon: Icons.warning_amber_rounded,
                  iconColor: AppTheme.dangerRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  title: 'AI Triage Accuracy',
                  value: '96.8%',
                  subtext: 'Auto-clustered 24 tickets',
                  icon: Icons.psychology_rounded,
                  iconColor: AppTheme.aiPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Action Navigation Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onNavigateToTriage,
                  icon: const Icon(Icons.playlist_add_check_circle_rounded, size: 16),
                  label: const Text('AI Triage Queue'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onNavigateToHeatmap,
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: const Text('Regional Heatmap'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onNavigateToAnalytics,
                  icon: const Icon(Icons.bar_chart_rounded, size: 16),
                  label: const Text('Dept Metrics'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Critical SLA Bottlenecks Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded, color: AppTheme.dangerRed, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'High Priority SLA Bottlenecks & Alerts',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                ],
              ),
              Text(
                '${escalatedGrievances.length} Urgent',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.dangerRed),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Escalated List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: escalatedGrievances.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = escalatedGrievances[index];
              return CustomGlassCard(
                borderColor: AppTheme.dangerRed.withOpacity(0.5),
                onTap: () {
                  appState.setSelectedGrievance(item);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => GrievanceDetailModal(grievance: item),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.id,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.dangerRed, fontSize: 12),
                        ),
                        StatusBadge(status: item.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.title,
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: textSub),
                    ),
                    const SizedBox(height: 10),

                    // AI Recommendation Box
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.aiPurple.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.aiPurple.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, size: 16, color: AppTheme.aiPurple),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'AI Executive Recommendation:',
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.aiPurple),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.aiActionRecommendation,
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textPrimary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// --- AI Triage Queue View ---
class AiTriageQueueView extends StatelessWidget {
  const AiTriageQueueView({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

    // Sorted by urgency score descending
    final sortedGrievances = List<Grievance>.from(appState.grievances)
      ..sort((a, b) => b.urgencyScore.compareTo(a.urgencyScore));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Automated AI Triage Queue',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Grievances ordered by AI Priority Score (0-100%). High-impact community issues are surfaced automatically.',
            style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
          ),
          const SizedBox(height: 14),

          Expanded(
            child: ListView.separated(
              itemCount: sortedGrievances.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = sortedGrievances[index];
                return CustomGlassCard(
                  onTap: () {
                    appState.setSelectedGrievance(item);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => GrievanceDetailModal(grievance: item),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.aiPurple.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'AI Score: ${item.urgencyScore}%',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.aiPurple,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              PriorityBadge(priority: item.priority),
                            ],
                          ),
                          StatusBadge(status: item.status),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.title,
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          CategoryBadge(category: item.category),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.ward,
                              style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'AI Action: ${item.aiActionRecommendation}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- Regional Heatmap & Ward Bottleneck View ---
class RegionalHeatmapView extends StatelessWidget {
  const RegionalHeatmapView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

    final wardsData = [
      {'ward': 'Ward 12 (Central Zone)', 'count': 14, 'risk': 'CRITICAL', 'color': AppTheme.dangerRed, 'issue': 'Major Pipe Burst in Sector 4'},
      {'ward': 'Ward 7 (North Zone)', 'count': 8, 'risk': 'HIGH', 'color': AppTheme.warningAmber, 'issue': 'MG Road Flyover Potholes'},
      {'ward': 'Ward 15 (East Zone)', 'count': 5, 'risk': 'MODERATE', 'color': AppTheme.primaryBlue, 'issue': 'Transformer Voltage Surge'},
      {'ward': 'Ward 3 (South Zone)', 'count': 3, 'risk': 'LOW', 'color': AppTheme.accentTeal, 'issue': 'Market Yard Waste Collection'},
      {'ward': 'Ward 19 (West Zone)', 'count': 2, 'risk': 'LOW', 'color': AppTheme.successGreen, 'issue': 'Bypass Streetlight Defect'},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Geographic Grievance Heatmap & Bottlenecks',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Spatial complaint density visualizer detecting root cause anomalies across municipal wards.',
            style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
          ),
          const SizedBox(height: 16),

          // Spatial Heatmap Simulation Card
          CustomGlassCard(
            borderColor: AppTheme.dangerRed.withOpacity(0.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.map_rounded, color: AppTheme.dangerRed, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'MUNICIPAL DENSITY GRID MAP',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.dangerRed),
                        ),
                      ],
                    ),
                    Text('LIVE CLUSTER RADAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentTeal)),
                  ],
                ),
                const SizedBox(height: 14),

                // Heatmap Visual Blocks
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.3,
                  ),
                  itemCount: wardsData.length,
                  itemBuilder: (context, index) {
                    final item = wardsData[index];
                    final Color color = item['color'] as Color;

                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color, width: 1.5),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item['ward'] as String,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item['count']} Complaints',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Root Cause Insights Card
          CustomGlassCard(
            gradientColors: [
              AppTheme.aiPurple.withOpacity(0.15),
              AppTheme.primaryBlue.withOpacity(0.15),
            ],
            borderColor: AppTheme.aiPurple.withOpacity(0.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.psychology_rounded, color: AppTheme.aiPurple),
                    SizedBox(width: 8),
                    Text(
                      'AI Root Cause Anomaly Detection',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.aiPurple),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '• Ward 12 Anomaly: 300% spike in water supply grievances detected between 14:00 and 18:00 yesterday. Root cause linked to 40-year old main feed pipe fatigue.',
                  style: TextStyle(fontSize: 12, height: 1.4, color: textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Recommended Preventive Action: Schedule full sub-line replacement during low-demand night window (01:00 AM - 04:00 AM).',
                  style: TextStyle(fontSize: 12, height: 1.4, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Department Analytics View ---
class DepartmentAnalyticsView extends StatelessWidget {
  const DepartmentAnalyticsView({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

    final depts = appState.departmentMetrics;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Department Performance Analytics & Benchmarks',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Comparative resolution metrics, SLA compliance performance, and average turnaround times across municipal agencies.',
            style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
          ),
          const SizedBox(height: 16),

          // Visual Donut Chart Summary
          CustomGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DEPARTMENTAL SLA COMPLIANCE RATIO',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: CustomPaint(
                        painter: DonutChartPainter(
                          values: depts.map((d) => d.slaCompliancePercent).toList(),
                          colors: const [
                            AppTheme.primaryBlue,
                            AppTheme.aiPurple,
                            AppTheme.successGreen,
                            AppTheme.warningAmber,
                            AppTheme.accentTeal,
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            '92.5%\nAvg SLA',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: depts.map((d) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Icon(d.icon, size: 14, color: AppTheme.primaryBlue),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    d.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                                Text(
                                  '${d.slaCompliancePercent}%',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Department List Cards
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: depts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final dept = depts[index];
              return CustomGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(dept.icon, size: 18, color: AppTheme.primaryBlue),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              dept.name,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.successGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${dept.slaCompliancePercent}% SLA',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.successGreen),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _deptStat('Total', '${dept.totalComplaints}'),
                        _deptStat('Resolved', '${dept.resolvedComplaints}'),
                        _deptStat('Pending', '${dept.pendingComplaints}'),
                        _deptStat('Avg SLA Time', '${dept.avgResolutionHours}h'),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _deptStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
      ],
    );
  }
}
