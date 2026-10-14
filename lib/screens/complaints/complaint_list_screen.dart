import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/grievance_model.dart';
import '../../providers/grievance_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../main_citizen_shell.dart';

class ComplaintListScreen extends ConsumerStatefulWidget {
  const ComplaintListScreen({super.key});

  @override
  ConsumerState<ComplaintListScreen> createState() =>
      _ComplaintListScreenState();
}

class _ComplaintListScreenState extends ConsumerState<ComplaintListScreen> {
  @override
  Widget build(BuildContext context) {
    final grievancesAsync = ref.watch(myGrievancesProvider);
    final activeFilter = ref.watch(complaintFilterProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Complaints & Grievances'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh List',
            onPressed: () => ref.invalidate(myGrievancesProvider),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'File New Grievance',
            onPressed: () => context.push('/complaints/new'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context).cardTheme.color,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', activeFilter),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pending', activeFilter, label: 'Pending (In Progress)'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Resolved', activeFilter, label: 'Resolved (Completed)'),
                  const SizedBox(width: 8),
                  _buildFilterChip('under_processing', activeFilter),
                  const SizedBox(width: 8),
                  _buildFilterChip('under_analysis', activeFilter),
                  const SizedBox(width: 8),
                  _buildFilterChip('clarification_required', activeFilter),
                  const SizedBox(width: 8),
                  _buildFilterChip('draft', activeFilter),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderLight),

          // List View
          Expanded(
            child: grievancesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.danger),
                      const SizedBox(height: 12),
                      Text(
                        formatApiErrorMessage(err),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => ref.invalidate(myGrievancesProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (grievances) {
                final filtered = grievances.where((g) {
                  final statusLower = g.status.toLowerCase();
                  final filterLower = activeFilter.toLowerCase();
                  if (filterLower == 'all') return true;
                  if (filterLower == 'pending') {
                    return statusLower != 'resolved' && statusLower != 'closed';
                  }
                  if (filterLower == 'resolved') {
                    return statusLower == 'resolved' || statusLower == 'closed';
                  }
                  return statusLower == filterLower;
                }).toList();

                if (filtered.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(myGrievancesProvider),
                    child: ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: _buildEmptyState(),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(myGrievancesProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _buildGrievanceCard(item);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/complaints/new'),
        backgroundColor: AppTheme.primaryBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'File Grievance',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String statusKey, String activeFilter, {String? label}) {
    final displayLabel = label ??
        (statusKey == 'All'
            ? 'All'
            : statusKey.replaceAll('_', ' ').toUpperCase());
    final isSelected = activeFilter.toLowerCase() == statusKey.toLowerCase();

    return ChoiceChip(
      label: Text(displayLabel),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          ref.read(complaintFilterProvider.notifier).state = statusKey;
        }
      },
      selectedColor: AppTheme.primaryBlue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.textPrimary,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 11,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder_off_outlined,
                size: 56,
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Complaints / Grievances Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'No grievances match your selected filter. Tap below to submit a new complaint.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToTracking(GrievanceModel item) {
    ref.read(selectedTrackingGrievanceIdProvider.notifier).state = item.id;
    final shellController = MainCitizenShellController.of(context);
    if (shellController != null) {
      shellController.onSelectTab(2);
    } else {
      context.push('/tracking');
    }
  }

  Widget _buildGrievanceCard(GrievanceModel item) {
    final statusColor = _getStatusColor(item.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _navigateToTracking(item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.grievanceNumber,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.status.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                item.getDisplayTitle(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (item.getShortBriefing() != null) ...[
                const SizedBox(height: 6),
                Text(
                  item.getShortBriefing()!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.account_balance_rounded, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.departmentId ?? 'Department: Auto AI Routing',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20, color: AppTheme.borderLight),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => _navigateToTracking(item),
                    icon: const Icon(Icons.my_location_rounded, size: 16),
                    label: const Text('Track Timeline'),
                  ),
                  Text(
                    _formatDate(item.createdAt),
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return Colors.orange;
      case 'under_analysis':
      case 'submitted':
        return AppTheme.primaryBlue;
      case 'under_processing':
        return const Color(0xFF7C3AED);
      case 'clarification_required':
        return AppTheme.danger;
      case 'resolved':
        return AppTheme.success;
      default:
        return AppTheme.textSecondary;
    }
  }
}
