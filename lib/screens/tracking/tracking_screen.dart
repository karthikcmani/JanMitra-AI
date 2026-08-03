import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/complaint_model.dart';
import '../../providers/complaint_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_button.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  final String? initialComplaintId;

  const TrackingScreen({super.key, this.initialComplaintId});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialComplaintId;
  }

  @override
  Widget build(BuildContext context) {
    final complaintState = ref.watch(complaintProvider);
    final complaints = complaintState.complaints;

    if (_selectedId == null && complaints.isNotEmpty) {
      _selectedId = complaints.first.id;
    }

    final currentComplaint = complaints
        .where((c) => c.id == _selectedId)
        .firstOrNull;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Grievance Tracking'),
        automaticallyImplyLeading: false,
      ),
      body: complaints.isEmpty
          ? _buildNoComplaintsView()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Select Complaint Dropdown
                  const Text(
                    'Select Grievance ID',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedId,
                    dropdownColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? AppTheme.darkSurface
                        : Colors.white,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                    ),
                    items: complaints
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              '${c.id} - ${c.title}',
                              style: TextStyle(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedId = val;
                      });
                    },
                    decoration: const InputDecoration(),
                  ),
                  const SizedBox(height: 20),

                  if (currentComplaint != null) ...[
                    _buildSummaryCard(currentComplaint),
                    const SizedBox(height: 24),
                    const Text(
                      'Resolution Progress Timeline',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildStatusTimeline(currentComplaint),
                    const SizedBox(height: 28),
                    _buildStatusUpdaterCard(currentComplaint),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildNoComplaintsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.location_off_outlined,
              size: 64,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Complaints Found to Track',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please submit a new grievance first to track live resolution stages.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/complaints/new'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('File Complaint'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(ComplaintModel complaint) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                complaint.id,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryBlue,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(complaint.status).withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  complaint.status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _getStatusColor(complaint.status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            complaint.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Submitted on: ${_formatDate(complaint.createdAt)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline(ComplaintModel complaint) {
    final stages = ['Submitted', 'Verification', 'Forwarded', 'Resolved'];
    final currentStageIndex = stages.indexOf(complaint.status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        children: List.generate(stages.length, (index) {
          final stage = stages[index];
          final isDone = index <= currentStageIndex;
          final isCurrent = index == currentStageIndex;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? (isCurrent
                                ? AppTheme.primaryBlue
                                : AppTheme.success)
                          : AppTheme.borderLight,
                    ),
                    child: Icon(
                      isDone ? Icons.check : Icons.circle_outlined,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  if (index < stages.length - 1)
                    Container(
                      width: 2,
                      height: 40,
                      color: index < currentStageIndex
                          ? AppTheme.success
                          : AppTheme.borderLight,
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stage,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isCurrent
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isDone
                              ? AppTheme.textPrimary
                              : AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getStageDescription(stage),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildStatusUpdaterCard(ComplaintModel complaint) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Simulate Official Status Transition',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Status transition stages are prepared for FastAPI backend API updates.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (complaint.status != 'Resolved') ...[
                Expanded(
                  child: CustomButton(
                    text: 'Advance to Next Stage',
                    onPressed: () {
                      final stages = [
                        'Submitted',
                        'Verification',
                        'Forwarded',
                        'Resolved',
                      ];
                      final currentIndex = stages.indexOf(complaint.status);
                      if (currentIndex < stages.length - 1) {
                        final next = stages[currentIndex + 1];
                        ref
                            .read(complaintProvider.notifier)
                            .updateStatus(complaint.id, next);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Status updated to: $next'),
                            backgroundColor: AppTheme.success,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ] else ...[
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.success,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Grievance Fully Resolved',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _getStageDescription(String stage) {
    switch (stage) {
      case 'Submitted':
        return 'Grievance received and registered in JanMitra AI database.';
      case 'Verification':
        return 'Document & locality inspection in progress by nodal officer.';
      case 'Forwarded':
        return 'Forwarded to Municipal Executive Department for field execution.';
      case 'Resolved':
        return 'Resolution completed and verified by citizen feedback.';
      default:
        return '';
    }
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
