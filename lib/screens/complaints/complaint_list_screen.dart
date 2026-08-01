import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/complaint_model.dart';
import '../../providers/complaint_provider.dart';
import '../../theme/app_theme.dart';

class ComplaintListScreen extends ConsumerStatefulWidget {
  const ComplaintListScreen({super.key});

  @override
  ConsumerState<ComplaintListScreen> createState() =>
      _ComplaintListScreenState();
}

class _ComplaintListScreenState extends ConsumerState<ComplaintListScreen> {
  String _selectedStatus = 'All';

  @override
  Widget build(BuildContext context) {
    final complaintState = ref.watch(complaintProvider);

    final filteredComplaints = complaintState.complaints.where((c) {
      if (_selectedStatus == 'All') return true;
      return c.status == _selectedStatus;
    }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Complaints'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'File New Complaint',
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
                  _buildFilterChip('All'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Submitted'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Verification'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Forwarded'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Resolved'),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderLight),
          // List View
          Expanded(
            child: filteredComplaints.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredComplaints.length,
                    itemBuilder: (context, index) {
                      final complaint = filteredComplaints[index];
                      return _buildComplaintCard(complaint);
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
          'File Complaint',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String status) {
    final isSelected = _selectedStatus == status;
    return ChoiceChip(
      label: Text(status),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedStatus = status;
          });
        }
      },
      selectedColor: AppTheme.primaryBlue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.textPrimary,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
                color: AppTheme.primaryBlue.withAlpha(20),
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
              'No Complaints Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'No grievances match your selected status filter. Tap below to submit a new complaint.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplaintCard(ComplaintModel complaint) {
    final statusColor = _getStatusColor(complaint.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    complaint.id,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    complaint.status,
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
              complaint.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              complaint.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.business_rounded,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  complaint.department,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  complaint.district,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const Divider(height: 20, color: AppTheme.borderLight),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {
                    context.push('/tracking?id=${complaint.id}');
                  },
                  icon: const Icon(Icons.my_location_rounded, size: 16),
                  label: const Text('Track Timeline'),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: 'Edit',
                      onPressed: () {
                        context.push('/complaints/edit/${complaint.id}');
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: AppTheme.danger,
                      ),
                      tooltip: 'Delete',
                      onPressed: () => _confirmDelete(complaint.id),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Complaint'),
        content: Text(
          'Are you sure you want to delete grievance $id? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ref.read(complaintProvider.notifier).deleteComplaint(id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Complaint $id deleted.'),
                  backgroundColor: AppTheme.danger,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Submitted':
        return AppTheme.primaryBlue;
      case 'Verification':
        return AppTheme.warning;
      case 'Forwarded':
        return const Color(0xFF7C3AED);
      case 'Resolved':
        return AppTheme.success;
      default:
        return AppTheme.textSecondary;
    }
  }
}
