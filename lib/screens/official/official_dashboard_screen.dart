import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/grievance_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/official_repository.dart';
import '../../theme/app_theme.dart';


class OfficialDashboardScreen extends ConsumerStatefulWidget {
  const OfficialDashboardScreen({super.key});

  @override
  ConsumerState<OfficialDashboardScreen> createState() => _OfficialDashboardScreenState();
}

class _OfficialDashboardScreenState extends ConsumerState<OfficialDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'ALL';
  bool _isSearching = false;
  List<GrievanceModel>? _searchResults;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _triggerSearch() async {
    final query = _searchController.text.trim();
    final status = _selectedStatusFilter == 'ALL' ? null : _selectedStatusFilter.toLowerCase();

    if (query.isEmpty && status == null) {
      setState(() {
        _isSearching = false;
        _searchResults = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final repo = ref.read(officialRepositoryProvider);
      final results = await repo.searchGrievances(
        query: query.isNotEmpty ? query : null,
        status: status,
      );
      if (mounted) {
        setState(() {
          _searchResults = results;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: ${e.toString()}'), backgroundColor: AppTheme.danger),
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
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: Text('Official Action — ${item.grievanceNumber}'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Citizen ID: ${item.citizenId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                              'AI-Assisted Decision Support',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.primaryBlue),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Suggested Dept: ${item.departmentId ?? "Kerala Water Authority (KWA)"}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
                        hintText: 'e.g. Please state survey number or attach tax receipt',
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
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Action submitted for ${item.grievanceNumber}')),
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
    final summaryAsync = ref.watch(officialSummaryProvider);
    final attentionAsync = ref.watch(attentionQueueProvider);
    final workloadAsync = ref.watch(departmentWorkloadProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Official Decision Support Workspace'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(officialSummaryProvider);
              ref.invalidate(attentionQueueProvider);
              ref.invalidate(departmentWorkloadProvider);
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
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Stat Cards
              summaryAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Text('Summary error: $e', style: const TextStyle(color: AppTheme.danger)),
                data: (summary) => _buildSummaryCards(summary),
              ),

              const SizedBox(height: 20),

              // Search & Filter Bar
              _buildSearchAndFilterBar(),

              const SizedBox(height: 20),

              // Search Results (if active)
              if (_isSearching && _searchResults != null) ...[
                Text(
                  'Search Results (${_searchResults!.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                ..._searchResults!.map((g) => _buildGrievanceCard(g)),
                const SizedBox(height: 24),
              ],

              // Needs Attention Queue
              const Text(
                'Grievances Needing Administrative Attention',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
              ),
              const SizedBox(height: 10),
              attentionAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Text('Attention queue error: $e', style: const TextStyle(color: AppTheme.danger)),
                data: (queue) {
                  if (queue.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No pending grievances in attention queue.', style: TextStyle(color: AppTheme.textSecondary)),
                    );
                  }
                  return Column(
                    children: queue.map((g) => _buildGrievanceCard(g)).toList(),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Department Workload Overview
              const Text(
                'Department Workload Distribution',
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
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _buildStatCard('Total Grievances', summary.totalGrievances.toString(), Icons.folder_open_rounded, AppTheme.primaryBlue),
        _buildStatCard('Pending Review', summary.pending.toString(), Icons.pending_actions_rounded, AppTheme.warning),
        _buildStatCard('High Priority', summary.highPriority.toString(), Icons.priority_high_rounded, AppTheme.danger),
        _buildStatCard('Clarification Req.', summary.clarificationRequired.toString(), Icons.help_outline_rounded, const Color(0xFF7C3AED)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
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
    );
  }

  Widget _buildSearchAndFilterBar() {
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
              children: ['ALL', 'UNDER_ANALYSIS', 'CLARIFICATION_REQUIRED', 'FORWARDED', 'RESOLVED'].map((st) {
                final isSel = _selectedStatusFilter == st;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(st.replaceAll('_', ' '), style: TextStyle(fontSize: 11, color: isSel ? Colors.white : AppTheme.textPrimary)),
                    selected: isSel,
                    selectedColor: AppTheme.primaryBlue,
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _selectedStatusFilter = st;
                        });
                        _triggerSearch();
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item.grievanceNumber, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.primaryBlue)),
                Chip(
                  label: Text(item.status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                  backgroundColor: _getStatusColor(item.status),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(item.title ?? 'No title provided', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            if (item.departmentId != null) ...[
              const SizedBox(height: 4),
              Text('Assigned Dept: ${item.departmentId}', style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.push('/official/grievance/${item.id}'),
                  icon: const Icon(Icons.description_outlined, size: 14),
                  label: const Text('View File', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                  onPressed: () => _showActionDialog(item),
                  icon: const Icon(Icons.gavel_rounded, size: 14, color: Colors.white),
                  label: const Text('Take Action', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkloadList(List<DepartmentWorkloadModel> workloads) {
    return Column(
      children: workloads.map((w) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderLight),
          ),
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
