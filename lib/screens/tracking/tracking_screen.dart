import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../models/grievance_model.dart';
import '../../providers/grievance_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/custom_button.dart';
import '../../services/api_service.dart';
import '../../widgets/attachment_preview_dialog.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  final String? initialComplaintId;

  const TrackingScreen({super.key, this.initialComplaintId});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  String? _selectedId;
  final TextEditingController _clarificationController = TextEditingController();
  final Map<String, TextEditingController> _interviewControllers = {};
  bool _isSubmittingClarification = false;
  bool _isSubmittingInterview = false;
  bool _isFullTextExpanded = false;
  final Set<String> _expandedAttachments = {};
  FlutterTts? _flutterTts;
  String? _speakingAttachmentId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialComplaintId;
  }

  @override
  void dispose() {
    _flutterTts?.stop();
    _clarificationController.dispose();
    for (final controller in _interviewControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _toggleSpeakTranscript(String attachmentId, String text) async {
    if (_speakingAttachmentId == attachmentId) {
      await _flutterTts?.stop();
      if (mounted) {
        setState(() {
          _speakingAttachmentId = null;
        });
      }
      return;
    }

    _flutterTts ??= FlutterTts();
    await _flutterTts!.setLanguage('ml-IN');
    await _flutterTts!.setSpeechRate(0.48);
    await _flutterTts!.setVolume(1.0);
    await _flutterTts!.setPitch(1.0);

    _flutterTts!.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _speakingAttachmentId = null;
        });
      }
    });

    _flutterTts!.setErrorHandler((msg) {
      if (mounted) {
        setState(() {
          _speakingAttachmentId = null;
        });
      }
    });

    if (mounted) {
      setState(() {
        _speakingAttachmentId = attachmentId;
      });
    }
    await _flutterTts!.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    final grievancesAsync = ref.watch(myGrievancesProvider);
    final navSelectedId = ref.watch(selectedTrackingGrievanceIdProvider);

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
                Text(
                  formatApiErrorMessage(err),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                ),
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

          if (navSelectedId != null && grievances.any((g) => g.id == navSelectedId)) {
            _selectedId = navSelectedId;
          } else if (_selectedId == null || !grievances.any((g) => g.id == _selectedId)) {
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
                  key: ValueKey('tracking_select_$_selectedId'),
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
                      _isFullTextExpanded = false;
                    });
                    if (val != null) {
                      ref.read(selectedTrackingGrievanceIdProvider.notifier).state = val;
                    }
                  },
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),

                _buildSummaryCard(currentGrievance),
                const SizedBox(height: 24),

                _buildExtractedPetitionTextCard(currentGrievance),
                const SizedBox(height: 24),

                if (currentGrievance.subGrievances.isNotEmpty) ...[
                  _buildSubGrievancesCard(currentGrievance),
                  const SizedBox(height: 24),
                ],

                if (currentGrievance.attachments.isNotEmpty) ...[
                  _buildAttachmentsCard(currentGrievance),
                  const SizedBox(height: 24),
                ],

                if (currentGrievance.summary != null || currentGrievance.issues.isNotEmpty) ...[
                  _buildAIIntelligenceCard(currentGrievance),
                  const SizedBox(height: 24),
                ],

                if (currentGrievance.interviewQuestions.isNotEmpty) ...[
                  _buildInterviewEngineCard(currentGrievance),
                  const SizedBox(height: 24),
                ],

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
          if (grievance.status.toLowerCase() == 'multi_issue_split') ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.account_tree_outlined, size: 16, color: Color(0xFF0284C7)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Multi-department petition: Partitioned into sub-tickets below for parallel processing.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  ),
                ],
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
              Icon(
                grievance.filingType == 'on_behalf' ? Icons.handshake_outlined : Icons.person_outline_rounded,
                size: 14,
                color: grievance.filingType == 'on_behalf' ? Colors.deepPurple : AppTheme.primaryBlue,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Petitioner: ${grievance.getPetitionerDisplay()}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: grievance.filingType == 'on_behalf' ? Colors.deepPurple : AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
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

  Widget _buildExtractedPetitionTextCard(GrievanceModel grievance) {
    final fullText = grievance.getFullPetitionText() ?? grievance.getShortBriefing() ?? 'No raw text available.';
    final isLong = fullText.length > 250;
    final displayText = (!_isFullTextExpanded && isLong)
        ? '${fullText.substring(0, 240)}...'
        : fullText;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.article_rounded, color: AppTheme.primaryBlue, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Extracted Petition & Complaint Text',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                tooltip: 'Copy Full Petition Text',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: fullText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Petition text copied to clipboard!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.04)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: SelectableText(
              displayText,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.5,
                fontFamily: 'Roboto',
              ),
            ),
          ),
          if (isLong) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isFullTextExpanded = !_isFullTextExpanded;
                  });
                },
                icon: Icon(
                  _isFullTextExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                ),
                label: Text(
                  _isFullTextExpanded ? 'Show Less' : 'Show Full Extracted Text (${fullText.length} chars)',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubGrievancesCard(GrievanceModel grievance) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_tree_rounded, color: Color(0xFF0284C7), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Departmental Sub-Tickets',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Multi-issue petition split across ${grievance.subGrievances.length} departments',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...grievance.subGrievances.map((sub) {
            final deptColor = _getDepartmentColor(sub.departmentId ?? '');
            final statusColor = _getStatusColor(sub.status);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.04)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(_getDepartmentIcon(sub.departmentId ?? ''), size: 16, color: deptColor),
                          const SizedBox(width: 6),
                          Text(
                            sub.grievanceNumber,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: deptColor,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          sub.status.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    sub.departmentId ?? 'Assigned Department',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  if (sub.category != null && sub.category!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Category: ${sub.category}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                  if (sub.title != null && sub.title!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      sub.title!,
                      style: const TextStyle(fontSize: 12, height: 1.3),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAIIntelligenceCard(GrievanceModel grievance) {
    final summary = grievance.summary;
    final issues = grievance.issues;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: AppTheme.primaryBlue, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'AI Grievance Intelligence',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'STATUS: ${(grievance.aiProcessingStatus ?? "COMPLETED").toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildMetricBadge('Severity', grievance.severity?.toUpperCase() ?? 'MEDIUM', AppTheme.warning),
              _buildMetricBadge('Priority Score', '${grievance.priority.toUpperCase()} (${grievance.priorityScore ?? 50}/100)', _getPriorityBadgeColor(grievance.priority)),
              _buildMetricBadge('SLA Target', '${grievance.slaTargetDays ?? (grievance.priority.toLowerCase() == "critical" ? 2 : grievance.priority.toLowerCase() == "high" ? 5 : 10)} Days', AppTheme.secondaryTeal),
            ],
          ),
          if (summary != null && summary.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Fact-Bounded AI Summary:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.05)
                    : AppTheme.lightBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Text(
                summary,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
          ],
          if (issues.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Multi-Issue Decomposition (${issues.length} Issues Detected):',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...issues.map((issue) => _buildIssueCard(issue)),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueCard(GrievanceIssueModel issue) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Issue #${issue.issueNumber}: ${issue.title}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  issue.category,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.secondaryTeal),
                ),
              ),
            ],
          ),
          if (issue.subcategory != null && issue.subcategory!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Subcategory: ${issue.subcategory}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
            ),
          ],
          if (issue.description != null && issue.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              issue.description!,
              style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
            ),
          ],
          if (issue.extractedFacts != null && issue.extractedFacts!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: issue.extractedFacts!.entries.map((e) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${e.key}: ${e.value}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryBlue),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInterviewEngineCard(GrievanceModel grievance) {
    final seenPending = <String>{};
    final pendingQuestions = grievance.interviewQuestions
        .where((q) => q.status == 'PENDING' && seenPending.add(q.question.trim().toLowerCase()))
        .toList();
    final seenAnswered = <String>{};
    final answeredQuestions = grievance.interviewQuestions
        .where((q) => q.status == 'ANSWERED' && seenAnswered.add(q.question.trim().toLowerCase()))
        .toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF7C3AED), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.quiz_rounded, color: Color(0xFF7C3AED), size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Interactive AI Clarification Interview',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF7C3AED),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'The AI assistant has identified missing facts required to process your grievance faster. Please answer the dynamic questions below:',
            style: TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.35),
          ),
          const SizedBox(height: 14),

          if (pendingQuestions.isNotEmpty) ...[
            ...pendingQuestions.asMap().entries.map((entry) {
              final idx = entry.key;
              final q = entry.value;
              _interviewControllers[q.id] ??= TextEditingController();
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Q${idx + 1}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF7C3AED),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            q.question,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (q.required)
                          const Text(
                            '* Required',
                            style: TextStyle(fontSize: 10, color: AppTheme.danger, fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _interviewControllers[q.id],
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Enter your response here...',
                        contentPadding: const EdgeInsets.all(10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: _isSubmittingInterview ? 'Submitting Answers...' : 'Submit Interview Answers & Re-Analyze',
                onPressed: _isSubmittingInterview ? null : () => _handleInterviewSubmit(grievance, pendingQuestions),
              ),
            ),
          ],

          if (answeredQuestions.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Answered Interview Questions:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED)),
            ),
            const SizedBox(height: 8),
            ...answeredQuestions.map((q) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.success),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          q.question,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  void _handleInterviewSubmit(GrievanceModel grievance, List<GrievanceInterviewQuestionModel> pendingQuestions) async {
    final responses = <Map<String, String>>[];
    for (final q in pendingQuestions) {
      final text = _interviewControllers[q.id]?.text.trim() ?? '';
      if (text.isNotEmpty) {
        responses.add({
          'question_id': q.id,
          'response_text': text,
          'answer_text': text,
        });
      }
    }

    if (responses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please answer at least one interview question before submitting.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    setState(() {
      _isSubmittingInterview = true;
    });

    try {
      final repo = ref.read(grievanceRepositoryProvider);
      await repo.submitInterviewResponses(
        grievanceId: grievance.id,
        responses: responses,
      );
      ref.invalidate(myGrievancesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Interview responses submitted successfully! Grievance re-analyzed.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting answers: ${e.toString()}'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingInterview = false;
        });
      }
    }
  }

  Widget _buildClarificationRequiredCard(GrievanceModel grievance) {
    String? officialNote = grievance.officialClarificationQuestion;
    if (officialNote == null || officialNote.trim().isEmpty) {
      for (final log in grievance.auditLogs.reversed) {
        if (log.actorRole == 'official' && (log.remarks?.isNotEmpty ?? false)) {
          officialNote = log.remarks;
          break;
        }
      }
    }

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
            'The reviewing officer has requested additional details regarding your petition. Please review the officer\'s instructions below:',
            style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
          ),
          if (officialNote != null && officialNote.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade700, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.assignment_ind_rounded, size: 20, color: Colors.amber.shade900),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Officer\'s Specific Clarification Request:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    officialNote.trim(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            'Enter your clarification response below:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
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
      case 'multi_issue_split':
        return const Color(0xFF0284C7);
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

  IconData _getDepartmentIcon(String dept) {
    final d = dept.toLowerCase();
    if (d.contains('water') || d.contains('kwa')) return Icons.water_drop_rounded;
    if (d.contains('revenue') || d.contains('land')) return Icons.landscape_rounded;
    if (d.contains('road') || d.contains('pwd')) return Icons.add_road_rounded;
    if (d.contains('electric') || d.contains('kseb')) return Icons.electric_bolt_rounded;
    if (d.contains('panchayat') || d.contains('lsgd')) return Icons.location_city_rounded;
    return Icons.account_balance_rounded;
  }

  Color _getDepartmentColor(String dept) {
    final d = dept.toLowerCase();
    if (d.contains('water') || d.contains('kwa')) return const Color(0xFF0284C7);
    if (d.contains('revenue') || d.contains('land')) return const Color(0xFFD97706);
    if (d.contains('road') || d.contains('pwd')) return const Color(0xFF4F46E5);
    if (d.contains('electric') || d.contains('kseb')) return const Color(0xFFEA580C);
    if (d.contains('panchayat') || d.contains('lsgd')) return const Color(0xFF059669);
    return AppTheme.primaryBlue;
  }

  Color _getPriorityBadgeColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return AppTheme.danger;
      case 'high':
        return Colors.deepOrange;
      case 'medium':
        return Colors.orange;
      case 'low':
      default:
        return AppTheme.success;
    }
  }

  String _formatDate(DateTime date) {
    return formatToIST(date);
  }

  Widget _buildAttachmentsCard(GrievanceModel grievance) {
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
            children: [
              const Icon(Icons.attach_file_rounded, color: AppTheme.primaryBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Original Documents & Petitions (${grievance.attachments.length})',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...grievance.attachments.map((att) {
            final isCompleted = att.extractionStatus == 'completed';
            final isExpanded = _expandedAttachments.contains(att.id);
            final rawText = att.rawExtractedText ?? '';
            final isLong = rawText.length > 200;
            final kind = getAttachmentKind(att.originalFilename, att.mimeType);
            final isAudio = kind == AttachmentKind.audio;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.04)
                    : (isAudio ? const Color(0xFF7C3AED).withValues(alpha: 0.03) : Colors.grey.shade50),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isAudio ? const Color(0xFF7C3AED).withValues(alpha: 0.3) : AppTheme.borderLight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isAudio
                            ? Icons.mic_rounded
                            : (kind == AttachmentKind.pdf ? Icons.picture_as_pdf_rounded : Icons.description_outlined),
                        color: isAudio ? const Color(0xFF7C3AED) : AppTheme.primaryBlue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          att.originalFilename.isNotEmpty
                              ? att.originalFilename
                              : (isAudio ? 'Voice Petition Recording' : 'Petition Document'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? AppTheme.success.withValues(alpha: 0.15)
                              : Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          att.extractionStatus.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isCompleted ? AppTheme.success : Colors.deepOrange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (rawText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isAudio ? 'Extracted Voice Transcript:' : 'Extracted Petition Text:',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: rawText));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isAudio ? 'Voice transcript copied!' : 'Attachment text copied!'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              children: [
                                Icon(Icons.copy_rounded, size: 13, color: AppTheme.primaryBlue),
                                SizedBox(width: 4),
                                Text(
                                  'Copy',
                                  style: TextStyle(fontSize: 11, color: AppTheme.primaryBlue, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      (!isExpanded && isLong) ? '${rawText.substring(0, 190)}...' : rawText,
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                    if (isLong)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(50, 24),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            setState(() {
                              if (isExpanded) {
                                _expandedAttachments.remove(att.id);
                              } else {
                                _expandedAttachments.add(att.id);
                              }
                            });
                          },
                          child: Text(
                            isExpanded ? 'Show Less' : 'Show Full Extracted Text',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 10),
                  if (isAudio)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.play_circle_filled_rounded, size: 16),
                          label: const Text(
                            'Listen to Voice Petition',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _showAttachmentPreview(context, grievance.id, att),
                        ),
                        if (att.rawExtractedText != null && att.rawExtractedText!.isNotEmpty)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              visualDensity: VisualDensity.compact,
                              foregroundColor: _speakingAttachmentId == att.id ? AppTheme.danger : const Color(0xFF7C3AED),
                              side: BorderSide(
                                color: _speakingAttachmentId == att.id ? AppTheme.danger : const Color(0xFF7C3AED),
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: Icon(
                              _speakingAttachmentId == att.id ? Icons.stop_circle_rounded : Icons.record_voice_over_rounded,
                              size: 16,
                            ),
                            label: Text(
                              _speakingAttachmentId == att.id ? 'Stop Speech' : 'Speak Petition (TTS)',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () => _toggleSpeakTranscript(att.id, att.rawExtractedText!),
                          ),
                      ],
                    )
                  else
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                      label: const Text(
                        'View Original Document',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _showAttachmentPreview(context, grievance.id, att),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showAttachmentPreview(BuildContext context, String grievanceId, GrievanceAttachmentModel att) {
    final baseUrl = ref.read(apiServiceProvider).baseUrl;
    final fileUrl = att.originalFilename.isNotEmpty
        ? '$baseUrl/grievances/$grievanceId/attachments/${att.id}/${att.originalFilename}'
        : '$baseUrl/grievances/$grievanceId/attachments/${att.id}';
    showAttachmentPreviewModal(
      context,
      fileUrl: fileUrl,
      attachment: att,
    );
  }
}
