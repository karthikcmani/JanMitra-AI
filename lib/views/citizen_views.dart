// ignore_for_file: deprecated_member_use, unnecessary_underscores
import 'package:flutter/material.dart';
import '../models/grievance.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

class CitizenHomeView extends StatelessWidget {
  final VoidCallback onNavigateToFileGrievance;
  final VoidCallback onNavigateToGrievancesList;

  const CitizenHomeView({
    super.key,
    required this.onNavigateToFileGrievance,
    required this.onNavigateToGrievancesList,
  });

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

    final grievances = appState.grievances;
    final recentGrievances = grievances.take(3).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          CustomGlassCard(
            gradientColors: const [Color(0xFF0F172A), Color(0xFF1E293B)],
            borderColor: AppTheme.primaryBlue.withOpacity(0.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentTeal.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_outlined, size: 13, color: AppTheme.accentTeal),
                          SizedBox(width: 5),
                          Text(
                            'CITIZEN INTEL PORTAL',
                            style: TextStyle(
                              color: AppTheme.accentTeal,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Row(
                      children: [
                        CircleAvatar(radius: 4, backgroundColor: AppTheme.successGreen),
                        SizedBox(width: 6),
                        Text(
                          'AI GRID ACTIVE',
                          style: TextStyle(color: AppTheme.successGreen, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Empowering Citizens through Instant AI Public Grievance Resolution',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Report civic issues with intelligent triage, instant duplicate detection, and direct administrative escalation.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onNavigateToFileGrievance,
                        icon: const Icon(Icons.add_task_rounded, size: 18),
                        label: const Text('File New Grievance'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Statistics Grid
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  title: 'Active Complaints',
                  value: '${appState.inProgressCount + appState.escalatedCount}',
                  subtext: 'In resolution pipeline',
                  icon: Icons.pending_actions_rounded,
                  iconColor: AppTheme.warningAmber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  title: 'Resolved',
                  value: '${appState.resolvedCount}',
                  subtext: 'Within target SLA',
                  icon: Icons.task_alt_rounded,
                  iconColor: AppTheme.successGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // AI Smart Assistant Quick Action Card
          CustomGlassCard(
            borderColor: AppTheme.aiPurple.withOpacity(0.4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    gradient: AppTheme.aiGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'JanMitra AI Voice & Text Bot',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Speak in Hindi/English to query grievance status or report issues verbally.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppTheme.aiPurple),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Recent Grievance Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Grievances Near You',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              TextButton(
                onPressed: onNavigateToGrievancesList,
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Recent Grievances List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentGrievances.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = recentGrievances[index];
              return GrievanceCard(
                grievance: item,
                onTap: () {
                  appState.setSelectedGrievance(item);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => GrievanceDetailModal(grievance: item),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// --- Grievance Card Component ---
class GrievanceCard extends StatelessWidget {
  final Grievance grievance;
  final VoidCallback onTap;

  const GrievanceCard({
    super.key,
    required this.grievance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSub = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return CustomGlassCard(
      onTap: onTap,
      borderColor: grievance.status == GrievanceStatus.escalated
          ? AppTheme.dangerRed.withOpacity(0.5)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                grievance.id,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
              ),
              Row(
                children: [
                  PriorityBadge(priority: grievance.priority),
                  const SizedBox(width: 8),
                  StatusBadge(status: grievance.status),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            grievance.title,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            grievance.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: textSub,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),

          // Location & Duplicate count
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 14, color: AppTheme.accentTeal),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  grievance.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: textSub),
                ),
              ),
              if (grievance.duplicateCount > 1) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.aiPurple.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${grievance.duplicateCount} Duplicates Clustered',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.aiPurple,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // AI Action & Upvote Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 14, color: AppTheme.aiPurple),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'AI Triage Score: ${grievance.urgencyScore}% Urgency',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.aiPurple,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => appState.upvoteGrievance(grievance.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.thumb_up_alt_outlined, size: 13, color: AppTheme.primaryBlue),
                      const SizedBox(width: 4),
                      Text(
                        '${grievance.upvotes}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- File Grievance Screen with AI Triage Prediction ---
class FileGrievanceView extends StatefulWidget {
  final VoidCallback onSuccessSubmitted;

  const FileGrievanceView({super.key, required this.onSuccessSubmitted});

  @override
  State<FileGrievanceView> createState() => _FileGrievanceViewState();
}

class _FileGrievanceViewState extends State<FileGrievanceView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  String _selectedWard = 'Ward 12 (Central Zone)';
  GrievanceCategory _selectedCategory = GrievanceCategory.waterSupply;

  int _predictedUrgency = 75;
  GrievancePriority _predictedPriority = GrievancePriority.high;
  String _predictedAiAction = 'Automated dispatch to Water Works Maintenance division.';
  bool _duplicateDetected = false;

  final List<String> _wards = [
    'Ward 12 (Central Zone)',
    'Ward 7 (North Zone)',
    'Ward 15 (East Zone)',
    'Ward 3 (South Zone)',
    'Ward 19 (West Zone)',
  ];

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onInputChanged);
    _descController.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    final text = '${_titleController.text} ${_descController.text}'.toLowerCase();
    setState(() {
      if (text.contains('leak') || text.contains('water') || text.contains('burst') || text.contains('sewage')) {
        _predictedUrgency = 92;
        _predictedPriority = GrievancePriority.urgent;
        _predictedAiAction = 'Emergency Water Pipeline Crew Dispatch + 4 Water Tanker Allocation.';
        _duplicateDetected = true;
      } else if (text.contains('fire') || text.contains('spark') || text.contains('electric') || text.contains('transformer')) {
        _predictedUrgency = 88;
        _predictedPriority = GrievancePriority.high;
        _predictedAiAction = 'Electricity Board Emergency Lineman Dispatch.';
        _duplicateDetected = false;
      } else if (text.contains('pothole') || text.contains('accident') || text.contains('road')) {
        _predictedUrgency = 80;
        _predictedPriority = GrievancePriority.high;
        _predictedAiAction = 'PWD Cold-Mix Asphalt Patching Unit Assignment.';
        _duplicateDetected = text.contains('mg road');
      } else {
        _predictedUrgency = 60;
        _predictedPriority = GrievancePriority.medium;
        _predictedAiAction = 'Standard Municipal Service Routing.';
        _duplicateDetected = false;
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lodge AI-Assisted Grievance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Provide details below. JanMitra AI automatically evaluates urgency, checks duplicate reports, and dispatches the optimal resolution squad.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 18),

            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Grievance Title / Problem Headline',
                hintText: 'e.g. Major Underground Pipe Burst near Sector 4',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title_rounded),
              ),
              validator: (val) => val == null || val.isEmpty ? 'Please enter a title' : null,
            ),
            const SizedBox(height: 14),

            // Category Dropdown
            DropdownButtonFormField<GrievanceCategory>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Department / Category',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category_rounded),
              ),
              items: GrievanceCategory.values.map((cat) {
                return DropdownMenuItem(
                  value: cat,
                  child: Row(
                    children: [
                      Icon(cat.icon, size: 16, color: AppTheme.primaryBlue),
                      const SizedBox(width: 8),
                      Text(cat.label),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
            const SizedBox(height: 14),

            // Location & Ward
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Street / Landmark',
                      hintText: 'Sector 4 Junction',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.pin_drop_rounded),
                    ),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedWard,
                    decoration: const InputDecoration(
                      labelText: 'Municipal Ward',
                      border: OutlineInputBorder(),
                    ),
                    items: _wards.map((w) {
                      return DropdownMenuItem(value: w, child: Text(w, style: const TextStyle(fontSize: 12)));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedWard = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Description
            TextFormField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Detailed Problem Description',
                hintText: 'Explain the issue, number of people affected, or potential safety hazards...',
                border: OutlineInputBorder(),
              ),
              validator: (val) => val == null || val.isEmpty ? 'Please describe the grievance' : null,
            ),
            const SizedBox(height: 18),

            // Live AI Triage Prediction Box
            CustomGlassCard(
              gradientColors: [
                AppTheme.aiPurple.withOpacity(0.12),
                AppTheme.primaryBlue.withOpacity(0.12),
              ],
              borderColor: AppTheme.aiPurple.withOpacity(0.4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.psychology_rounded, color: AppTheme.aiPurple, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'LIVE AI TRIAGE PREDICTOR',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.aiPurple,
                            ),
                          ),
                        ],
                      ),
                      PriorityBadge(priority: _predictedPriority),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Urgency Score:',
                        style: TextStyle(fontSize: 12, color: textPrimary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_predictedUrgency%',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: _predictedUrgency / 100,
                            minHeight: 8,
                            backgroundColor: Colors.black12,
                            color: _predictedUrgency > 85 ? AppTheme.dangerRed : AppTheme.warningAmber,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'AI Recommendation: $_predictedAiAction',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),

                  if (_duplicateDetected) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.warningAmber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.warningAmber),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.warningAmber),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Duplicate Cluster Warning: 14 similar complaints detected in Ward 12. Filing this will attach your report to Master Ticket JM-2026-8891 for boosted SLA priority.',
                              style: TextStyle(fontSize: 11, color: AppTheme.warningAmber),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    appState.fileNewGrievance(
                      title: _titleController.text,
                      description: _descController.text,
                      category: _selectedCategory,
                      location: _locationController.text,
                      ward: _selectedWard,
                      urgencyScore: _predictedUrgency,
                      priority: _predictedPriority,
                      aiAction: _predictedAiAction,
                      similarityAlert: _duplicateDetected
                          ? 'Automated duplicate match: Attached to Ward 12 Master Grievance'
                          : null,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Grievance filed successfully with AI Triage Assignment!'),
                        backgroundColor: AppTheme.successGreen,
                      ),
                    );
                    widget.onSuccessSubmitted();
                  }
                },
                icon: const Icon(Icons.send_rounded),
                label: const Text('SUBMIT GRIEVANCE TO GOVERNANCE GRID'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Grievance List Screen ---
class GrievanceListView extends StatelessWidget {
  const GrievanceListView({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

    final filtered = appState.filteredGrievances;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search box
          TextField(
            onChanged: (val) => appState.setSearchQuery(val),
            decoration: InputDecoration(
              hintText: 'Search grievances by ID, location, ward, or keyword...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: appState.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => appState.setSearchQuery(''),
                    )
                  : null,
              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
          ),
          const SizedBox(height: 12),

          // Category Filter Horizontal Scroll
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All Categories'),
                  selected: appState.categoryFilter == null,
                  onSelected: (_) => appState.setCategoryFilter(null),
                ),
                const SizedBox(width: 8),
                ...GrievanceCategory.values.map((cat) {
                  final isSelected = appState.categoryFilter == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: Icon(cat.icon, size: 14),
                      label: Text(cat.label),
                      selected: isSelected,
                      onSelected: (_) {
                        appState.setCategoryFilter(isSelected ? null : cat);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Active filter count header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${filtered.length} Grievances',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              if (appState.categoryFilter != null || appState.statusFilter != null || appState.searchQuery.isNotEmpty)
                TextButton(
                  onPressed: () => appState.clearFilters(),
                  child: const Text('Clear Filters'),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 48, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                        const SizedBox(height: 12),
                        Text(
                          'No grievances match current filters',
                          style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return GrievanceCard(
                        grievance: item,
                        onTap: () {
                          appState.setSelectedGrievance(item);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => GrievanceDetailModal(grievance: item),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// --- Grievance Detail Modal Bottom Sheet ---
class GrievanceDetailModal extends StatelessWidget {
  final Grievance grievance;

  const GrievanceDetailModal({super.key, required this.grievance});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSub = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBg : AppTheme.lightBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle bar
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          grievance.id,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          PriorityBadge(priority: grievance.priority),
                          const SizedBox(width: 8),
                          StatusBadge(status: grievance.status),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Text(
                    grievance.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      CategoryBadge(category: grievance.category),
                      const SizedBox(width: 10),
                      Icon(Icons.location_on_outlined, size: 14, color: AppTheme.accentTeal),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          grievance.location,
                          style: TextStyle(fontSize: 12, color: textSub),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Description
                  CustomGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PROBLEM DESCRIPTION',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: textSub,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          grievance.description,
                          style: TextStyle(fontSize: 13, color: textPrimary, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // AI Triage Analysis Card
                  CustomGlassCard(
                    gradientColors: [
                      AppTheme.aiPurple.withOpacity(0.15),
                      AppTheme.primaryBlue.withOpacity(0.15),
                    ],
                    borderColor: AppTheme.aiPurple.withOpacity(0.4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.psychology_rounded, color: AppTheme.aiPurple),
                                SizedBox(width: 8),
                                Text(
                                  'JanMitra AI Decision Support Analysis',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.aiPurple,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Score: ${grievance.urgencyScore}%',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.aiPurple),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Recommended Executive Action:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSub),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          grievance.aiActionRecommendation,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
                        ),
                        if (grievance.similarityAlert != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.lightbulb_outline, size: 14, color: AppTheme.warningAmber),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  grievance.similarityAlert!,
                                  style: const TextStyle(fontSize: 11.5, color: AppTheme.warningAmber),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Officer Assigned Box
                  CustomGlassCard(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.badge_outlined, color: AppTheme.primaryBlue),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ASSIGNED ADMINISTRATIVE OFFICER',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textSub),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                grievance.assignedOfficer,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Timeline Lifecycle Header
                  Text(
                    'Grievance Resolution Lifecycle',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  TimelineWidget(steps: grievance.timeline),
                  const SizedBox(height: 20),

                  // Admin Action Buttons if in Admin mode
                  if (appState.userRole == UserRole.admin) ...[
                    const Divider(),
                    const SizedBox(height: 10),
                    Text(
                      'Administrative Actions',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              appState.updateGrievanceStatus(
                                grievance.id,
                                GrievanceStatus.inProgress,
                                officerNote: 'Officer dispatched crew to site.',
                              );
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningAmber),
                            child: const Text('Mark In Progress'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              appState.updateGrievanceStatus(
                                grievance.id,
                                GrievanceStatus.resolved,
                                officerNote: 'Field inspection complete & issue resolved.',
                              );
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen),
                            child: const Text('Mark Resolved'),
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
  }
}

// AppState Inherited Widget Helper for fast clean state access across subviews
class AppStateProvider extends InheritedWidget {
  final AppState state;

  const AppStateProvider({
    super.key,
    required this.state,
    required super.child,
  });

  static AppState of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<AppStateProvider>();
    return provider!.state;
  }

  @override
  bool updateShouldNotify(covariant AppStateProvider oldWidget) => true;
}
