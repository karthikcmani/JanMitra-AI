import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/grievance_model.dart';
import '../../repositories/official_repository.dart';
import '../../theme/app_theme.dart';

final officialGrievanceDetailProvider = FutureProvider.family.autoDispose<GrievanceModel, String>((ref, id) async {
  final repo = ref.watch(officialRepositoryProvider);
  final results = await repo.searchGrievances(query: id);
  if (results.isNotEmpty) {
    return results.firstWhere((g) => g.id == id || g.grievanceNumber == id, orElse: () => results.first);
  }
  final all = await repo.searchGrievances();
  return all.firstWhere((g) => g.id == id || g.grievanceNumber == id, orElse: () => throw Exception('Grievance not found'));
});

class OfficialGrievanceDetailScreen extends ConsumerStatefulWidget {
  final String grievanceId;

  const OfficialGrievanceDetailScreen({super.key, required this.grievanceId});

  @override
  ConsumerState<OfficialGrievanceDetailScreen> createState() => _OfficialGrievanceDetailScreenState();
}

class _OfficialGrievanceDetailScreenState extends ConsumerState<OfficialGrievanceDetailScreen> {
  final _remarksController = TextEditingController();
  final _questionController = TextEditingController();

  String _selectedDept = 'Kerala Water Authority (KWA)';
  String _selectedStatus = 'forwarded';
  bool _isSubmitting = false;

  static const _allowedDepts = [
    'Kerala Water Authority (KWA)',
    'Public Works Department (PWD)',
    'Kerala State Electricity Board (KSEB)',
    'Local Self Government Department (LSGD / Panchayat)',
    'Revenue & General Administration',
  ];

  @override
  void dispose() {
    _remarksController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  void _initFormFields(GrievanceModel g) {
    final currentDept = g.departmentId ?? g.predictedDepartment ?? '';
    if (_allowedDepts.contains(currentDept)) {
      _selectedDept = currentDept;
    } else if (currentDept.contains('KWA') || currentDept.contains('Water')) {
      _selectedDept = 'Kerala Water Authority (KWA)';
    } else if (currentDept.contains('PWD') || currentDept.contains('Works')) {
      _selectedDept = 'Public Works Department (PWD)';
    } else if (currentDept.contains('KSEB') || currentDept.contains('Electricity')) {
      _selectedDept = 'Kerala State Electricity Board (KSEB)';
    } else if (currentDept.contains('LSGD') || currentDept.contains('Panchayat')) {
      _selectedDept = 'Local Self Government Department (LSGD / Panchayat)';
    } else {
      _selectedDept = 'Revenue & General Administration';
    }

    if (['forwarded', 'clarification_required', 'under_processing', 'resolved', 'closed'].contains(g.status.toLowerCase())) {
      _selectedStatus = g.status.toLowerCase();
    }
  }

  Future<void> _submitOfficialAction(GrievanceModel item) async {
    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(officialRepositoryProvider);
      await repo.submitAction(
        grievanceId: item.id,
        departmentName: _selectedDept,
        newStatus: _selectedStatus,
        remarks: _remarksController.text.trim().isNotEmpty ? _remarksController.text.trim() : null,
        question: _questionController.text.trim().isNotEmpty ? _questionController.text.trim() : null,
      );

      ref.invalidate(officialGrievanceDetailProvider(widget.grievanceId));
      ref.invalidate(officialSummaryProvider);
      ref.invalidate(attentionQueueProvider);
      ref.invalidate(departmentWorkloadProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action submitted for ${item.grievanceNumber}'),
            backgroundColor: AppTheme.success,
          ),
        );
        _remarksController.clear();
        _questionController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grievanceAsync = ref.watch(officialGrievanceDetailProvider(widget.grievanceId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Grievance File #${widget.grievanceId.substring(0, widget.grievanceId.length > 8 ? 8 : widget.grievanceId.length)}'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(officialGrievanceDetailProvider(widget.grievanceId)),
            tooltip: 'Reload File',
          ),
        ],
      ),
      body: grievanceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.danger),
                const SizedBox(height: 12),
                Text('Error loading grievance: ${err.toString()}', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(officialGrievanceDetailProvider(widget.grievanceId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (g) {
          _initFormFields(g);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Banner
                _buildHeaderCard(g),

                const SizedBox(height: 16),

                // Citizen & Submission Details
                _buildCitizenSection(g),

                const SizedBox(height: 16),

                // Document Evidence & OCR Section
                _buildDocumentEvidenceSection(g),

                const SizedBox(height: 16),

                // AI Decision Support Panel (Statutory)
                _buildAIDecisionSupportPanel(g),

                const SizedBox(height: 16),

                // Official Governance Action Form
                _buildOfficialActionForm(g),

                const SizedBox(height: 16),

                // Audit Trail Timeline
                _buildAuditTrailTimeline(g),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(GrievanceModel g) {
    final statusColor = _getStatusColor(g.status);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  g.grievanceNumber,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.primaryBlue),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    g.status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(g.title ?? 'Untitled Grievance', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.business_rounded, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Assigned Dept: ${g.departmentId ?? g.predictedDepartment ?? "Revenue & General Admin"}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCitizenSection(GrievanceModel g) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.person_outline_rounded, color: AppTheme.primaryBlue, size: 20),
                SizedBox(width: 8),
                Text('Citizen Submission & Context', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(child: Text('Citizen Name: ${g.citizenName ?? "Anonymous / Registered Citizen"}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                if (g.citizenPhone != null)
                  Text('Phone: ${g.citizenPhone}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 10),
            const Text('Verified Petition Content:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                (g.originalText != null && g.originalText!.isNotEmpty)
                    ? g.originalText!
                    : (g.rawOcrText != null && g.rawOcrText!.isNotEmpty)
                        ? g.rawOcrText!
                        : (g.description ?? 'No written petition body provided.'),
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentEvidenceSection(GrievanceModel g) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.description_outlined, color: AppTheme.primaryBlue, size: 20),
                SizedBox(width: 8),
                Text('Document Evidence & OCR Analysis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const Divider(height: 20),
            if (g.attachments.isEmpty)
              const Text('No uploaded attachments associated with this grievance.', style: TextStyle(fontSize: 12, color: Colors.grey))
            else
              Column(
                children: g.attachments.map((att) {
                  final isCompleted = att.extractionStatus == 'completed';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.insert_drive_file_outlined, color: AppTheme.primaryBlue, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                att.originalFilename.isNotEmpty ? att.originalFilename : 'Attachment Document',
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
                        if (att.rawExtractedText != null && att.rawExtractedText!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text('Extracted OCR Text:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                            att.rawExtractedText!,
                            style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black87),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIDecisionSupportPanel(GrievanceModel g) {
    final ds = g.decisionSupport;
    final suggestedDept = ds?.suggestedDepartment ?? g.predictedDepartment ?? "Kerala Water Authority (KWA)";
    final statutory = ds?.statutoryRelevance ?? "Kerala Public Services Act, 2012";
    final reasoning = ds?.reasoning ?? g.aiExplanation ?? "Assigned based on natural language petition context.";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.smart_toy_rounded, size: 22, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'AI-Assisted Administrative Decision Support Panel',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.primaryBlue),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${((ds?.confidenceScore ?? 0.88) * 100).toInt()}% Confidence',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Suggested Authority: $suggestedDept', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text('Statutory Reference: $statutory', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(height: 6),
          Text('AI Reasoning: $reasoning', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black87)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: Colors.deepOrange),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'AI-assisted recommendation. Administrative official retains final decision-making responsibility.',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialActionForm(GrievanceModel g) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.gavel_rounded, color: AppTheme.primaryBlue, size: 20),
                SizedBox(width: 8),
                Text('Official Governance & Action Execution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const Divider(height: 20),

            const Text('Select Department / Authority:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue: _selectedDept,
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
              items: _allowedDepts.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedDept = val);
              },
            ),

            const SizedBox(height: 12),
            const Text('Update Grievance Status:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
              items: const [
                DropdownMenuItem(value: 'forwarded', child: Text('Approve & Forward to Department')),
                DropdownMenuItem(value: 'clarification_required', child: Text('Request Citizen Clarification')),
                DropdownMenuItem(value: 'under_processing', child: Text('Mark Under Active Processing')),
                DropdownMenuItem(value: 'resolved', child: Text('Mark Resolved & Closed')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedStatus = val);
              },
            ),

            if (_selectedStatus == 'clarification_required') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _questionController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Clarification Question for Citizen',
                  hintText: 'e.g. Please provide survey number or specify house location',
                  border: OutlineInputBorder(),
                ),
              ),
            ],

            const SizedBox(height: 12),
            TextField(
              controller: _remarksController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Official Action Remarks / Decision Record',
                hintText: 'Enter official decision, instructions, or resolution notes...',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : () => _submitOfficialAction(g),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: _isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                label: Text(
                  _isSubmitting ? 'Submitting Action...' : 'Execute Official Action',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditTrailTimeline(GrievanceModel g) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.history_rounded, color: AppTheme.primaryBlue, size: 20),
                SizedBox(width: 8),
                Text('Persisted Governance Audit Log Timeline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const Divider(height: 20),
            if (g.auditLogs.isEmpty)
              const Text('No audit logs recorded for this grievance yet.', style: TextStyle(fontSize: 12, color: Colors.grey))
            else
              Column(
                children: g.auditLogs.map((log) {
                  final actionStr = log.actionType.replaceAll('_', ' ');
                  final dateStr = log.createdAt.toString().split('.').first;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.circle, size: 10, color: AppTheme.primaryBlue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    actionStr.isNotEmpty ? actionStr : 'ACTION',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  Text(
                                    dateStr,
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ),
                              if (log.remarks != null && log.remarks!.isNotEmpty)
                                Text(
                                  log.remarks!,
                                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
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
