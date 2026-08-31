import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/grievance_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/official_repository.dart';
import '../../theme/app_theme.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'ALL';
  String _selectedDeptFilter = 'ALL';
  bool _isSearching = false;
  List<GrievanceModel>? _searchResults;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _triggerSearch({String? status, String? dept, String? priority}) async {
    final query = _searchController.text.trim();
    final effectiveStatus = status ?? (_selectedStatusFilter == 'ALL' ? null : _selectedStatusFilter.toLowerCase());
    final effectiveDept = dept ?? (_selectedDeptFilter == 'ALL' ? null : _selectedDeptFilter);

    setState(() {
      _isSearching = true;
      if (status != null) _selectedStatusFilter = status;
      if (dept != null) _selectedDeptFilter = dept;
    });

    try {
      final repo = ref.read(officialRepositoryProvider);
      final results = await repo.searchGrievances(
        query: query.isNotEmpty ? query : null,
        status: effectiveStatus,
        departmentId: effectiveDept,
        priority: priority,
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

  void _showAdminActionDialog(GrievanceModel item) {
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
    String? selectedOfficialId;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final officialsAsync = ref.watch(officialUsersProvider);
          final officialsList = officialsAsync.asData?.value ?? [];

          return AlertDialog(
            title: Text('Admin Control — ${item.grievanceNumber}'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Citizen Name: ${item.citizenName ?? item.citizenId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  if (item.citizenPhone != null)
                    Text('Phone: ${item.citizenPhone}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),

                  // AI Decision Support Card
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
                              'AI Decision Support (Statutory)',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.primaryBlue),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Suggested Dept: ${item.predictedDepartment ?? "Revenue"}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text('Legal Grounding: ${item.decisionSupport?.statutoryRelevance ?? "Kerala Public Services Act, 2012"}', style: const TextStyle(fontSize: 11)),
                        Text('Reasoning: ${item.aiExplanation ?? item.decisionSupport?.reasoning ?? "N/A"}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  const Text('Assign Department:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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

                  if (officialsList.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('Assign Official Staff Member:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    DropdownButton<String?>(
                      value: selectedOfficialId,
                      isExpanded: true,
                      hint: const Text('Select Department Officer', style: TextStyle(fontSize: 12)),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Auto-assign by Department', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic))),
                        ...officialsList.map((u) {
                          final id = u['id']?.toString();
                          final name = u['full_name']?.toString() ?? 'Official';
                          final dept = u['department_id']?.toString() ?? '';
                          return DropdownMenuItem<String?>(
                            value: id,
                            child: Text('$name ($dept)', style: const TextStyle(fontSize: 12)),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setModalState(() => selectedOfficialId = val);
                      },
                    ),
                  ],

                  const SizedBox(height: 12),
                  const Text('Update Status:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  DropdownButton<String>(
                    value: selectedStatus,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'forwarded', child: Text('Forward to Department')),
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
                        labelText: 'Clarification Question',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),
                  TextField(
                    controller: remarksController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Admin Remarks',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              ElevatedButton(
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
                    if (context.mounted) {
                      Navigator.pop(dialogContext);
                      ref.invalidate(officialSummaryProvider);
                      ref.invalidate(attentionQueueProvider);
                      ref.invalidate(departmentWorkloadProvider);
                      ref.invalidate(officialUsersProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Admin action updated successfully!'), backgroundColor: AppTheme.success),
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
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                child: const Text('Submit Action', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showManageOfficialDialog(Map<String, dynamic> user) {
    const allowedDepts = [
      'Kerala Water Authority (KWA)',
      'Public Works Department (PWD)',
      'Kerala State Electricity Board (KSEB)',
      'Local Self Government Department (LSGD / Panchayat)',
      'Revenue & General Administration',
    ];

    String selectedDept = allowedDepts.contains(user['department_id'])
        ? user['department_id']
        : 'Kerala Water Authority (KWA)';
    bool isActive = user['is_active'] ?? true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: Text('Manage Official — ${user['full_name']}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email: ${user['email']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 12),
                const Text('Assigned Department:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                DropdownButton<String>(
                  value: selectedDept,
                  isExpanded: true,
                  items: allowedDepts.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedDept = val);
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Official Account Active', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  value: isActive,
                  onChanged: (val) => setModalState(() => isActive = val),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final repo = ref.read(officialRepositoryProvider);
                    await repo.updateOfficialUser(
                      userId: user['id'],
                      isActive: isActive,
                      departmentId: selectedDept,
                    );
                    if (context.mounted) {
                      Navigator.pop(dialogContext);
                      ref.invalidate(officialUsersProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Official user updated successfully!'), backgroundColor: AppTheme.success),
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
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
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
        title: const Text('JanMitra AI — System Admin Dashboard'),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(officialSummaryProvider);
              ref.invalidate(attentionQueueProvider);
              ref.invalidate(departmentWorkloadProvider);
              ref.invalidate(officialUsersProvider);
            },
            tooltip: 'Refresh Analytics',
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
          ref.invalidate(officialUsersProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Admin Header Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF334155)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shield_outlined, color: Colors.amber, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Administrative Operations Command Center',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Real-time state overview, departmental workload analysis, official staff roster management, and complete administrative control.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Summary Stat Cards (Interactive Taps)
              const Text('System Analytics & Quick Filter Matrix', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              summaryAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Text('Summary error: $e', style: const TextStyle(color: AppTheme.danger)),
                data: (summary) => _buildAdminSummaryCards(summary),
              ),

              const SizedBox(height: 20),

              // Search & Filter Panel
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Master Grievance Search & Governance',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: 'Search by Title, Grievance #, or Citizen Name...',
                                prefixIcon: Icon(Icons.search_rounded),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onSubmitted: (_) => _triggerSearch(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _triggerSearch(),
                            icon: const Icon(Icons.filter_list_rounded, size: 18),
                            label: const Text('Filter'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const Text('Status: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            DropdownButton<String>(
                              value: _selectedStatusFilter,
                              style: const TextStyle(fontSize: 12, color: Colors.black),
                              items: const [
                                DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                                DropdownMenuItem(value: 'intake_received', child: Text('Intake Received')),
                                DropdownMenuItem(value: 'under_analysis', child: Text('Under Analysis')),
                                DropdownMenuItem(value: 'under_processing', child: Text('Under Processing')),
                                DropdownMenuItem(value: 'clarification_required', child: Text('Clarification Required')),
                                DropdownMenuItem(value: 'forwarded', child: Text('Forwarded')),
                                DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedStatusFilter = val);
                                  _triggerSearch();
                                }
                              },
                            ),
                            const SizedBox(width: 16),
                            const Text('Department: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            DropdownButton<String>(
                              value: _selectedDeptFilter,
                              style: const TextStyle(fontSize: 12, color: Colors.black),
                              items: const [
                                DropdownMenuItem(value: 'ALL', child: Text('All Departments')),
                                DropdownMenuItem(value: 'Kerala Water Authority (KWA)', child: Text('KWA')),
                                DropdownMenuItem(value: 'Public Works Department (PWD)', child: Text('PWD')),
                                DropdownMenuItem(value: 'Kerala State Electricity Board (KSEB)', child: Text('KSEB')),
                                DropdownMenuItem(value: 'Local Self Government Department (LSGD / Panchayat)', child: Text('LSGD')),
                                DropdownMenuItem(value: 'Revenue & General Administration', child: Text('Revenue')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedDeptFilter = val);
                                  _triggerSearch();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Search Results vs Needs Attention Queue
              if (_isSearching && _searchResults != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Search Results (${_searchResults!.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _selectedStatusFilter = 'ALL';
                          _selectedDeptFilter = 'ALL';
                          _isSearching = false;
                          _searchResults = null;
                        });
                      },
                      child: const Text('Clear Search'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ..._searchResults!.map((g) => _buildGrievanceAdminCard(g)),
              ] else ...[
                const Text('Administrative Attention Queue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                attentionAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Text('Queue error: $e', style: const TextStyle(color: AppTheme.danger)),
                  data: (queue) => Column(
                    children: queue.take(5).map((g) => _buildGrievanceAdminCard(g)).toList(),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Admin Department Workload Breakdown (Interactive Taps)
              const Text('Statewide Departmental Workload Matrix (Tap to filter)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              workloadAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Text('Workload error: $e', style: const TextStyle(color: AppTheme.danger)),
                data: (workloads) => Column(
                  children: workloads.map((w) => _buildWorkloadCard(w)).toList(),
                ),
              ),

              const SizedBox(height: 24),

              // Registered Official Roster & Staff Management (Interactive Actions)
              const Text('Statewide Government Official Roster (Tap to manage)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              ref.watch(officialUsersProvider).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => const SizedBox.shrink(),
                data: (officials) {
                  if (officials.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Text('No registered department officials found.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                    );
                  }
                  return Column(
                    children: officials.map((u) => _buildOfficialUserCard(u)).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfficialUserCard(Map<String, dynamic> user) {
    final isActive = user['is_active'] ?? true;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showManageOfficialDialog(user),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppTheme.primaryBlue,
                radius: 18,
                child: Icon(Icons.badge_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user['full_name'] ?? 'Official User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(
                      'Dept: ${user['department_id'] ?? "Unassigned"} • Email: ${user['email']}',
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.success.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isActive ? 'Active Staff' : 'Inactive',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isActive ? AppTheme.success : AppTheme.danger),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 18, color: Colors.grey),
                onPressed: () => _showManageOfficialDialog(user),
                tooltip: 'Edit Official User',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminSummaryCards(dynamic summary) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard('Total', summary.totalGrievances.toString(), AppTheme.primaryBlue, Icons.folder_special_rounded, () {
                setState(() {
                  _searchController.clear();
                  _selectedStatusFilter = 'ALL';
                  _selectedDeptFilter = 'ALL';
                  _isSearching = false;
                  _searchResults = null;
                });
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statCard('Pending', summary.pending.toString(), Colors.orange, Icons.hourglass_top_rounded, () {
                _triggerSearch(status: 'intake_received');
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statCard('Active', summary.underProcessing.toString(), AppTheme.secondaryTeal, Icons.sync_rounded, () {
                _triggerSearch(status: 'under_processing');
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statCard('Clarify', summary.clarificationRequired.toString(), Colors.purple, Icons.help_outline_rounded, () {
                _triggerSearch(status: 'clarification_required');
              }),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _statCard('Forwarded', summary.forwarded.toString(), Colors.indigo, Icons.send_rounded, () {
                _triggerSearch(status: 'forwarded');
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statCard('Resolved', summary.resolved.toString(), AppTheme.success, Icons.check_circle_rounded, () {
                _triggerSearch(status: 'resolved');
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statCard('High Prio', summary.highPriority.toString(), AppTheme.danger, Icons.priority_high_rounded, () {
                _triggerSearch(priority: 'high');
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statCard('Today', summary.todayReceived.toString(), Colors.teal, Icons.today_rounded, () {
                _triggerSearch();
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, Color color, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color)),
              Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.9)), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrievanceAdminCard(GrievanceModel item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: () => context.push('/official/grievance/${item.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item.grievanceNumber, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, fontSize: 13)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(item.status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.status.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getStatusColor(item.status)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(item.title ?? 'No Title', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 4),
              Text(
                item.description ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
              if (item.rawOcrText != null && item.rawOcrText!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    'Extracted OCR: ${item.rawOcrText}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black87),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Dept: ${item.departmentId ?? item.predictedDepartment ?? "Unassigned"}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => context.push('/official/grievance/${item.id}'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('View File', style: TextStyle(fontSize: 11)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _showAdminActionDialog(item),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Admin Action', style: TextStyle(fontSize: 11, color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkloadCard(dynamic workload) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _triggerSearch(dept: workload.departmentName),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              const Icon(Icons.corporate_fare_rounded, color: AppTheme.primaryBlue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(workload.departmentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(
                      'Total: ${workload.total} | Pending: ${workload.pending} | Processing: ${workload.underProcessing} | Resolved: ${workload.resolved}',
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'resolved':
      case 'closed':
        return AppTheme.success;
      case 'clarification_required':
        return Colors.purple;
      case 'forwarded':
        return Colors.indigo;
      case 'under_processing':
        return AppTheme.secondaryTeal;
      case 'under_analysis':
        return Colors.blue;
      case 'intake_received':
        return Colors.amber;
      default:
        return Colors.orange;
    }
  }
}
