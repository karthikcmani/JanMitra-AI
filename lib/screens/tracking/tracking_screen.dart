import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/grievance_model.dart';
import '../../providers/grievance_provider.dart';
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
  final TextEditingController _clarificationController = TextEditingController();
  bool _isSubmittingClarification = false;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialComplaintId;
  }

  @override
  void dispose() {
    _clarificationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grievancesAsync = ref.watch(myGrievancesProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Grievance Live Audit & Tracking'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(myGrievancesProvider),
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: grievancesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 54, color: AppTheme.danger),
                const SizedBox(height: 12),
                Text('Failed to load tracking data: ${err.toString()}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(myGrievancesProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (grievances) {
          if (grievances.isEmpty) {
            return _buildNoComplaintsView();
          }

          if (_selectedId == null || !grievances.any((g) => g.id == _selectedId)) {
            _selectedId = grievances.first.id;
          }

          final currentGrievance = grievances.firstWhere((g) => g.id == _selectedId);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Grievance Number',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedId,
                  isExpanded: true,
                  dropdownColor: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkSurface
                      : Colors.white,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                  ),
                  items: grievances
                      .map(
                        (g) => DropdownMenuItem(
                          value: g.id,
                          child: Text(
                            '${g.grievanceNumber} • ${g.getDisplayTitle()}',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedId = val;
                    });
                  },
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),

                _buildSummaryCard(currentGrievance),
                const SizedBox(height: 24),

                if (currentGrievance.status.toLowerCase() == 'clarification_required') ...[
                  _buildClarificationRequiredCard(currentGrievance),
                  const SizedBox(height: 24),
                ],

                const Text(
                  'Live Audit History & Action Log',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                _buildLiveAuditTimeline(currentGrievance),
              ],
            ),
          );
        },
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
              'No Active Grievances Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please submit a new grievance first to view real-time audit logs and status updates.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/complaints/new'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('File Grievance'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(GrievanceModel grievance) {
    final displayTitle = grievance.getDisplayTitle();
    final shortBriefing = grievance.getShortBriefing();

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
                grievance.grievanceNumber,
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
                  color: _getStatusColor(grievance.status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  grievance.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _getStatusColor(grievance.status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            displayTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (shortBriefing != null && shortBriefing.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.05)
                    : AppTheme.lightBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Text(
                'Briefing: $shortBriefing',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.35,
                ),
              ),
            ),
          ],
          if (grievance.departmentId != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.account_balance_outlined, size: 14, color: AppTheme.primaryBlue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Department: ${grievance.departmentId}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
          ],
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
                'Submitted: ${_formatDate(grievance.createdAt)}',
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

  Widget _buildClarificationRequiredCard(GrievanceModel grievance) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.warning, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.help_outline_rounded, color: AppTheme.warning, size: 22),
              SizedBox(width: 8),
              Text(
                'Action Required: Official Clarification Requested',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'The reviewing officer has requested additional details regarding your petition. Please enter your clarification response below:',
            style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _clarificationController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Enter missing survey number, land details, or additional evidence description...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: CustomButton(
              text: _isSubmittingClarification ? 'Submitting...' : 'Submit Clarification Response',
              onPressed: _isSubmittingClarification
                  ? null
                  : () {
                      _handleClarificationSubmit(grievance);
                    },
            ),
          ),

        ],
      ),
    );
  }

  void _handleClarificationSubmit(GrievanceModel grievance) async {
    final text = _clarificationController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _isSubmittingClarification = true;
    });
    try {
      final repo = ref.read(grievanceRepositoryProvider);
      await repo.submitClarification(
        grievanceId: grievance.id,
        responseText: text,
      );
      _clarificationController.clear();
      ref.invalidate(myGrievancesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clarification response submitted successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingClarification = false;
        });
      }
    }
  }


  Widget _buildLiveAuditTimeline(GrievanceModel grievance) {
    final logs = grievance.auditLogs;

    if (logs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: const Text(
          'No official audit entries recorded yet.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        children: List.generate(logs.length, (index) {
          final log = logs[index];
          final isLast = index == logs.length - 1;

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
                      color: _getActorColor(log.actorRole),
                    ),
                    child: Icon(
                      _getActorIcon(log.actorRole),
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 44,
                      color: AppTheme.borderLight,
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            log.actionType.replaceAll('_', ' ').toUpperCase(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                          Text(
                            _formatDate(log.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'By: ${log.actorRole.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _getActorColor(log.actorRole),
                        ),
                      ),
                      if (log.newState != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Status Changed → ${log.newState}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                      if (log.remarks != null && log.remarks!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          log.remarks!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
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

  Color _getActorColor(String role) {
    switch (role.toLowerCase()) {
      case 'official':
      case 'admin':
        return AppTheme.primaryBlue;
      case 'citizen':
        return AppTheme.success;
      case 'system':
      default:
        return const Color(0xFF7C3AED);
    }
  }

  IconData _getActorIcon(String role) {
    switch (role.toLowerCase()) {
      case 'official':
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      case 'citizen':
        return Icons.person_rounded;
      case 'system':
      default:
        return Icons.smart_toy_rounded;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
      case 'intake_received':
        return AppTheme.primaryBlue;
      case 'clarification_required':
        return AppTheme.warning;
      case 'under_analysis':
      case 'under_processing':
      case 'forwarded':
        return const Color(0xFF7C3AED);
      case 'resolved':
      case 'closed':
        return AppTheme.success;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
