import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/grievance_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/official_repository.dart';
import '../../theme/app_theme.dart';

class OfficialSearchFilterState {
  final String query;
  final String status;
  final String? priority;
  final String? departmentId;

  const OfficialSearchFilterState({
    this.query = '',
    this.status = 'ALL',
    this.priority,
    this.departmentId,
  });

  OfficialSearchFilterState copyWith({
    String? query,
    String? status,
    String? priority,
    String? departmentId,
    bool clearPriority = false,
    bool clearDept = false,
  }) {
    return OfficialSearchFilterState(
      query: query ?? this.query,
      status: status ?? this.status,
      priority: clearPriority ? null : (priority ?? this.priority),
      departmentId: clearDept ? null : (departmentId ?? this.departmentId),
    );
  }
}

final officialFilterNotifierProvider = StateProvider.autoDispose<OfficialSearchFilterState>((ref) {
  final user = ref.watch(authProvider).currentUser;
  final dept = (user?.role == 'official' && user?.departmentId != null) ? user!.departmentId : null;
  return OfficialSearchFilterState(departmentId: dept);
});

final officialFilteredGrievancesProvider = FutureProvider.autoDispose<List<GrievanceModel>>((ref) async {
  final filter = ref.watch(officialFilterNotifierProvider);
  final repo = ref.watch(officialRepositoryProvider);

  return await repo.searchGrievances(
    query: filter.query.isNotEmpty ? filter.query : null,
    status: filter.status == 'ALL' ? null : filter.status.toLowerCase(),
    priority: filter.priority,
    departmentId: filter.departmentId,
  );
});

class OfficialDashboardScreen extends ConsumerStatefulWidget {
  const OfficialDashboardScreen({super.key});

  @override
  ConsumerState<OfficialDashboardScreen> createState() => _OfficialDashboardScreenState();
}

class _OfficialDashboardScreenState extends ConsumerState<OfficialDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _triggerSearch() {
    final query = _searchController.text.trim();
    ref.read(officialFilterNotifierProvider.notifier).update((s) => s.copyWith(query: query));
  }

  void _clearFilters() {
    _searchController.clear();
    final user = ref.read(authProvider).currentUser;
    final dept = (user?.role == 'official' && user?.departmentId != null) ? user!.departmentId : null;
    ref.read(officialFilterNotifierProvider.notifier).state = OfficialSearchFilterState(departmentId: dept);
  }

  void _quickUpdateStatus(GrievanceModel item, String newStatus, {String? targetDept, String? remarks}) async {
    try {
      final repo = ref.read(officialRepositoryProvider);
      await repo.submitAction(
        grievanceId: item.id,
        departmentName: targetDept ?? item.departmentId ?? item.predictedDepartment ?? 'Revenue & General Administration',
        newStatus: newStatus,
        remarks: remarks ?? 'Updated by Official Decision Support Workspace',
      );
      ref.invalidate(officialSummaryProvider);
      ref.invalidate(attentionQueueProvider);
      ref.invalidate(departmentWorkloadProvider);
      ref.invalidate(officialFilteredGrievancesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.grievanceNumber} status updated to ${newStatus.replaceAll('_', ' ').toUpperCase()}'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  void _showActionDialog(GrievanceModel item) {
    final remarksController = TextEditingController();
    final questionController = TextEditingController();

    const allowedDepts = [
      'Kerala Water Authority (KWA)',
      'Public Works Department (PWD)',
      'Kerala State Electricity Board (KSEB)',
      'Local Self Government Department (LSGD / Panchayat)',
      'Revenue & General Administration',
    ];

    const allowedStatuses = [
      'forwarded',
      'clarification_required',
      'under_processing',
      'under_analysis',
      'intake_received',
      'resolved',
    ];

    String getInitialDept(GrievanceModel g) {
      final dept = g.departmentId ?? g.predictedDepartment ?? '';
      if (allowedDepts.contains(dept)) return dept;
      if (dept.contains('KWA') || dept.contains('Water')) return 'Kerala Water Authority (KWA)';
      if (dept.contains('PWD') || dept.contains('Works')) return 'Public Works Department (PWD)';
      if (dept.contains('KSEB') || dept.contains('Electricity')) return 'Kerala State Electricity Board (KSEB)';
      if (dept.contains('LSGD') || dept.contains('Panchayat')) return 'Local Self Government Department (LSGD / Panchayat)';
      if (dept.contains('Revenue')) return 'Revenue & General Administration';
      return 'Kerala Water Authority (KWA)';
    }

    String selectedStatus = allowedStatuses.contains(item.status.toLowerCase()) ? item.status.toLowerCase() : 'forwarded';
    String selectedDept = getInitialDept(item);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: Text('Official Governance Action — ${item.grievanceNumber}'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Citizen: ${item.citizenName ?? item.citizenId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  if (item.citizenPhone != null)
                    Text('Phone: ${item.citizenPhone}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),

                  // AI Decision Support Panel
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.smart_toy_rounded, size: 18, color: AppTheme.primaryBlue),
                            SizedBox(width: 6),
                            Text(
                              'AI-Assisted Decision Support Panel',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.primaryBlue),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Suggested Dept: ${item.departmentId ?? item.predictedDepartment ?? "Kerala Water Authority (KWA)"}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('Priority: ${item.priority.toUpperCase()}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        const Text(
                          'Legal Grounding: Kerala Public Services Act, 2012',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Disclaimer: AI-assisted recommendation. Administrative official retains final decision-making responsibility.',
                          style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  const Text('Target Department:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  DropdownButton<String>(
                    value: selectedDept,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'Kerala Water Authority (KWA)', child: Text('Kerala Water Authority (KWA)', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'Public Works Department (PWD)', child: Text('Public Works Department (PWD)', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'Kerala State Electricity Board (KSEB)', child: Text('Kerala State Electricity Board (KSEB)', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'Local Self Government Department (LSGD / Panchayat)', child: Text('Local Self Government Department (LSGD)', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'Revenue & General Administration', child: Text('Revenue & General Administration', style: TextStyle(fontSize: 12))),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedDept = val);
                    },
                  ),

                  const SizedBox(height: 12),
                  const Text('Administrative Action / Status:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  DropdownButton<String>(
                    value: selectedStatus,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'forwarded', child: Text('Approve & Forward to Department')),
                      DropdownMenuItem(value: 'clarification_required', child: Text('Request Citizen Clarification')),
                      DropdownMenuItem(value: 'under_processing', child: Text('Mark Under Active Processing')),
                      DropdownMenuItem(value: 'under_analysis', child: Text('Under AI Analysis')),
                      DropdownMenuItem(value: 'intake_received', child: Text('Intake Received')),
                      DropdownMenuItem(value: 'resolved', child: Text('Mark Resolved & Closed')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedStatus = val);
                    },
                  ),

                  if (selectedStatus == 'clarification_required') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: questionController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Clarification Question for Citizen',
                        hintText: 'e.g. Please state survey number or attach location sketch',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),
                  TextField(
                    controller: remarksController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Official Decision Remarks',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                onPressed: () async {
                  try {
                    final repo = ref.read(officialRepositoryProvider);
                    await repo.submitAction(
                      grievanceId: item.id,
                      departmentName: selectedDept,
                      newStatus: selectedStatus,
                      remarks: remarksController.text.trim().isNotEmpty ? remarksController.text.trim() : null,
                      question: questionController.text.trim().isNotEmpty ? questionController.text.trim() : null,
                    );
                    ref.invalidate(officialSummaryProvider);
                    ref.invalidate(attentionQueueProvider);
                    ref.invalidate(departmentWorkloadProvider);
                    ref.invalidate(officialFilteredGrievancesProvider);
                    if (context.mounted) {
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Action submitted for ${item.grievanceNumber}'), backgroundColor: AppTheme.success),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppTheme.danger),
                      );
                    }
                  }
                },
                child: const Text('Submit Action', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).currentUser;
    final officialDept = currentUser?.departmentId ?? 'Official Department';

    final summaryAsync = ref.watch(officialSummaryProvider);
    final grievancesAsync = ref.watch(officialFilteredGrievancesProvider);
    final workloadAsync = ref.watch(departmentWorkloadProvider);
    final currentFilter = ref.watch(officialFilterNotifierProvider);

    final isFiltered = currentFilter.query.isNotEmpty ||
        currentFilter.status != 'ALL' ||
        (currentFilter.departmentId != null && currentFilter.departmentId != currentUser?.departmentId) ||
        currentFilter.priority != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(currentUser?.departmentId != null ? '${currentUser!.departmentId} Portal' : 'Official Copilot Workspace'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(officialSummaryProvider);
              ref.invalidate(attentionQueueProvider);
              ref.invalidate(departmentWorkloadProvider);
              ref.invalidate(officialFilteredGrievancesProvider);
            },
            tooltip: 'Refresh Workspace Data',
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              final router = GoRouter.of(context);
              await ref.read(authProvider.notifier).logout();
              router.go('/login');
            },
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(officialSummaryProvider);
          ref.invalidate(attentionQueueProvider);
          ref.invalidate(departmentWorkloadProvider);
          ref.invalidate(officialFilteredGrievancesProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logged In Official Department Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_rounded, color: AppTheme.primaryBlue, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentUser?.fullName ?? 'Government Official',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryBlue),
                          ),
                          Text(
                            'Department: $officialDept',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Interactive Analytics Cards
              summaryAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Text('Summary error: $e', style: const TextStyle(color: AppTheme.danger)),
                data: (summary) => _buildSummaryCards(summary),
              ),

              const SizedBox(height: 20),

              // Search & Filter Bar
              _buildSearchAndFilterBar(),

              const SizedBox(height: 16),

              // Active Filter Header
              if (isFiltered) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Filter: ${currentFilter.departmentId ?? ""} ${currentFilter.status != "ALL" ? currentFilter.status : ""} ${currentFilter.priority ?? ""}'.trim(),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                        ),
                      ),
                      InkWell(
                        onTap: _clearFilters,
                        child: const Text('Reset Dept Filter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.danger)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Grievance List Header & Async Results
              grievancesAsync.when(
                loading: () => const Column(
                  children: [
                    SizedBox(height: 20),
                    Center(child: CircularProgressIndicator()),
                    SizedBox(height: 20),
                  ],
                ),
                error: (e, s) => Text('Search error: $e', style: const TextStyle(color: AppTheme.danger)),
                data: (grievances) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${currentFilter.departmentId ?? officialDept} Queue (${grievances.length})',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                          ),
                          if (isFiltered)
                            TextButton(
                              onPressed: _clearFilters,
                              child: const Text('Reset'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (grievances.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.grey),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'No pending grievances registered for ${currentFilter.departmentId ?? officialDept}.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...grievances.map((g) => _buildGrievanceCard(g)),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // Department Workload Overview (Interactive Taps)
              const Text(
                'Department Workload Distribution (Tap to filter)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
              ),
              const SizedBox(height: 10),
              workloadAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Text('Workload error: $e', style: const TextStyle(color: AppTheme.danger)),
                data: (workloads) => _buildWorkloadList(workloads),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(OfficialDashboardSummaryModel summary) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Grievances',
                summary.totalGrievances.toString(),
                Icons.folder_open_rounded,
                AppTheme.primaryBlue,
                () => _clearFilters(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                'Pending Review',
                summary.pending.toString(),
                Icons.pending_actions_rounded,
                AppTheme.warning,
                () => _clearFilters(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'High Priority',
                summary.highPriority.toString(),
                Icons.priority_high_rounded,
                AppTheme.danger,
                () {
                  ref.read(officialFilterNotifierProvider.notifier).update((s) => s.copyWith(priority: 'high'));
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                'Clarification Req.',
                summary.clarificationRequired.toString(),
                Icons.help_outline_rounded,
                const Color(0xFF7C3AED),
                () {
                  ref.read(officialFilterNotifierProvider.notifier).update((s) => s.copyWith(status: 'CLARIFICATION_REQUIRED'));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
                    Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    final currentFilter = ref.watch(officialFilterNotifierProvider);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search by title, number, or citizen name...',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _triggerSearch(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                onPressed: _triggerSearch,
                child: const Text('Search', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['ALL', 'FORWARDED', 'CLARIFICATION_REQUIRED', 'UNDER_PROCESSING', 'RESOLVED'].map((st) {
                final isSel = currentFilter.status == st;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(st.replaceAll('_', ' '), style: TextStyle(fontSize: 11, color: isSel ? Colors.white : AppTheme.textPrimary)),
                    selected: isSel,
                    selectedColor: AppTheme.primaryBlue,
                    onSelected: (val) {
                      if (val) {
                        ref.read(officialFilterNotifierProvider.notifier).update((s) => s.copyWith(status: st));
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrievanceCard(GrievanceModel item) {
    final dept = item.departmentId ?? item.predictedDepartment ?? 'Revenue & General Administration';
    final ocrSnippet = item.rawOcrText ?? item.originalText ?? item.description ?? '';
    final hasMalayalamText = ocrSnippet.contains('വിപിൻ') || ocrSnippet.contains('തൃക്കാക്കര') || ocrSnippet.contains('മാനസിക') || ocrSnippet.contains('ഹരാസ്മെന്റ്');

    final displayTitle = (item.title != null && !item.title!.contains('Gr5rFBDXEAEHk3g'))
        ? item.title!
        : 'Petition #${item.grievanceNumber} — Malayalam Document Scan';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: () => context.push('/official/grievance/${item.id}'),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grievance Header Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item.grievanceNumber, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.primaryBlue)),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (item.priority.toLowerCase() == 'high' ? AppTheme.danger : Colors.orange).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.priority.toUpperCase(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: item.priority.toLowerCase() == 'high' ? AppTheme.danger : Colors.orange),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Chip(
                        label: Text(item.status.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                        backgroundColor: _getStatusColor(item.status),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Title & Citizen Info
              Text(displayTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              if (item.citizenName != null) ...[
                const SizedBox(height: 2),
                Text('Citizen: ${item.citizenName} ${item.citizenPhone != null ? "• Phone: ${item.citizenPhone}" : ""}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],

              if (ocrSnippet.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: hasMalayalamText ? Colors.amber.withValues(alpha: 0.1) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: hasMalayalamText ? Colors.amber.shade300 : Colors.grey.shade300),
                  ),
                  child: Text(
                    'Extracted Text: $ocrSnippet',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black87),
                  ),
                ),
              ],

              const SizedBox(height: 8),

              // AI Decision Support Banner
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.smart_toy_rounded, size: 16, color: AppTheme.primaryBlue),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'AI Recommendation: $dept • Kerala Public Services Act, 2012',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryBlue),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Quick Official Action Toolbar
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _quickUpdateStatus(item, 'forwarded', targetDept: dept, remarks: 'Forwarded to $dept for action'),
                    icon: const Icon(Icons.send_rounded, size: 13),
                    label: const Text('Forward Dept', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _quickUpdateStatus(item, 'clarification_required', remarks: 'Requested additional citizen details'),
                    icon: const Icon(Icons.help_outline_rounded, size: 13, color: Colors.purple),
                    label: const Text('Ask Citizen', style: TextStyle(fontSize: 11, color: Colors.purple)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _quickUpdateStatus(item, 'resolved', remarks: 'Grievance verified and resolved by Official'),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 13, color: AppTheme.success),
                    label: const Text('Resolve', style: TextStyle(fontSize: 11, color: AppTheme.success)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _showActionDialog(item),
                    icon: const Icon(Icons.gavel_rounded, size: 13, color: Colors.white),
                    label: const Text('Govern', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => context.push('/official/grievance/${item.id}'),
                    icon: const Icon(Icons.description_outlined, size: 13, color: Colors.white),
                    label: const Text('View File', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkloadList(List<DepartmentWorkloadModel> workloads) {
    return Column(
      children: workloads.map((w) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () {
              ref.read(officialFilterNotifierProvider.notifier).update((s) => s.copyWith(departmentId: w.departmentName));
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      w.departmentName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Row(
                    children: [
                      _buildMiniBadge('Pending: ${w.pending}', AppTheme.warning),
                      const SizedBox(width: 4),
                      _buildMiniBadge('Forwarded: ${w.forwarded}', AppTheme.primaryBlue),
                      const SizedBox(width: 4),
                      _buildMiniBadge('Total: ${w.total}', AppTheme.textMuted),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMiniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'forwarded':
        return AppTheme.primaryBlue;
      case 'clarification_required':
        return AppTheme.warning;
      case 'resolved':
      case 'closed':
        return AppTheme.success;
      case 'under_analysis':
        return Colors.blue;
      case 'intake_received':
        return Colors.amber;
      default:
        return const Color(0xFF7C3AED);
    }
  }
}
