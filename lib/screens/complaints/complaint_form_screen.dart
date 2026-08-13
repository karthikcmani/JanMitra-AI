import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/grievance_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class ComplaintFormScreen extends ConsumerStatefulWidget {
  final String? complaintId;

  const ComplaintFormScreen({super.key, this.complaintId});

  @override
  ConsumerState<ComplaintFormScreen> createState() => _ComplaintFormScreenState();
}

class _ComplaintFormScreenState extends ConsumerState<ComplaintFormScreen> {
  final _directTitleController = TextEditingController();
  final _directTextController = TextEditingController();
  final _verifiedTextController = TextEditingController();

  @override
  void dispose() {
    _directTitleController.dispose();
    _directTextController.dispose();
    _verifiedTextController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        ref.read(grievanceIntakeProvider.notifier).setPickedFile(
              file.path!,
              file.name,
              file.size,
            );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting file: ${e.toString()}'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  Future<void> _triggerExtraction() async {
    final notifier = ref.read(grievanceIntakeProvider.notifier);
    await notifier.uploadAndExtractDocument();

    final state = ref.read(grievanceIntakeProvider);
    if (state.extractionStep == IntakeExtractionStep.completed &&
        state.rawExtractedText != null) {
      _verifiedTextController.text = state.rawExtractedText!;
    }
  }

  void _confirmAndSubmitHandwritten() {
    final notifier = ref.read(grievanceIntakeProvider.notifier);
    notifier.updateVerifiedText(_verifiedTextController.text);
    notifier.confirmVerification();

    final state = ref.read(grievanceIntakeProvider);
    if (state.isConfirmed && state.grievance != null) {
      _showSuccessDialog(state.grievance!.grievanceNumber);
    }
  }

  Future<void> _submitDirectText() async {
    if (_directTitleController.text.trim().isEmpty ||
        _directTextController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both title and text content.'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    final notifier = ref.read(grievanceIntakeProvider.notifier);
    final grievance = await notifier.submitDirectText(
      title: _directTitleController.text.trim(),
      text: _directTextController.text.trim(),
    );

    if (grievance != null && mounted) {
      _showSuccessDialog(grievance.grievanceNumber);
    }
  }

  void _showSuccessDialog(String grievanceNumber) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 28),
            SizedBox(width: 10),
            Text('Intake Confirmed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Grievance registered under ID:\n$grievanceNumber',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your grievance text has been explicitly confirmed and stored in the intelligence pipeline for administrative review.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(grievanceIntakeProvider.notifier).reset();
              context.pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(grievanceIntakeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grievance Intelligence Intake'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            ref.read(grievanceIntakeProvider.notifier).reset();
            context.pop();
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Intake Mode Selection Banner
                  Text(
                    'Select Intake Mechanism',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildModeCard(
                          title: 'Handwritten Petition',
                          subtitle: 'Malayalam Image / PDF OCR',
                          icon: Icons.document_scanner_rounded,
                          modeKey: 'ocr_handwritten',
                          activeMode: state.intakeMode,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildModeCard(
                          title: 'Direct Text Input',
                          subtitle: 'Malayalam / English',
                          icon: Icons.edit_note_rounded,
                          modeKey: 'direct_text',
                          activeMode: state.intakeMode,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildModeCard(
                          title: 'Voice Intake',
                          subtitle: 'Malayalam Audio',
                          icon: Icons.mic_rounded,
                          modeKey: 'voice_stt',
                          activeMode: state.intakeMode,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (state.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.danger),
                      ),
                      child: Text(
                        state.errorMessage!,
                        style: const TextStyle(color: AppTheme.danger, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // MODE 1: HANDWRITTEN PETITION / OCR FLOW
                  if (state.intakeMode == 'ocr_handwritten') ...[
                    _buildHandwrittenIntakeSection(state, isDark),
                  ],

                  // MODE 2: DIRECT TEXT FLOW
                  if (state.intakeMode == 'direct_text') ...[
                    _buildDirectTextSection(state, isDark),
                  ],

                  // MODE 3: VOICE INPUT FLOW
                  if (state.intakeMode == 'voice_stt') ...[
                    _buildVoicePlaceholderSection(isDark),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String modeKey,
    required String activeMode,
    required bool isDark,
  }) {
    final isSelected = modeKey == activeMode;
    return InkWell(
      onTap: () {
        ref.read(grievanceIntakeProvider.notifier).selectIntakeMode(modeKey);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryBlue.withValues(alpha: 0.15)
              : (isDark ? AppTheme.darkSurface : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryBlue : Colors.grey,
              size: 26,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppTheme.primaryBlue : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandwrittenIntakeSection(GrievanceIntakeState state, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // File Selection Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              const Icon(Icons.cloud_upload_outlined, size: 40, color: AppTheme.primaryBlue),
              const SizedBox(height: 8),
              const Text(
                'Upload Malayalam Handwritten Petition',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 4),
              const Text(
                'Supported formats: JPG, PNG, WEBP, PDF (Max 10MB)',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDocument,
                icon: const Icon(Icons.folder_open_rounded),
                label: Text(
                  state.selectedFileName ?? 'Browse / Select File',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (state.selectedFileName != null) ...[
          // Original Artifact Metadata Card
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: Icon(
                state.selectedFileName!.endsWith('.pdf')
                    ? Icons.picture_as_pdf_rounded
                    : Icons.image_rounded,
                color: AppTheme.primaryBlue,
                size: 32,
              ),
              title: Text(
                state.selectedFileName!,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Text(
                'Original Citizen Source File • Untouched Original (${((state.selectedFileSizeBytes ?? 0) / 1024).toStringAsFixed(1)} KB)',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Upload & Extract Trigger Button
          if (state.extractionStep == IntakeExtractionStep.idle) ...[
            CustomButton(
              text: 'Upload & Extract Malayalam Text via Cloud Vision OCR',
              onPressed: _triggerExtraction,
              isLoading: state.isLoading,
            ),
          ],
        ],

        // Extraction Step Loading Progress Indicator
        if (state.extractionStep == IntakeExtractionStep.uploading ||
            state.extractionStep == IntakeExtractionStep.extracting) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      state.extractionStep == IntakeExtractionStep.uploading
                          ? 'Uploading original petition artifact to server...'
                          : 'Processing OCR extraction via Google Cloud Vision API (DOCUMENT_TEXT_DETECTION)...',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Extraction Completed Display & Verification Area
        if (state.extractionStep == IntakeExtractionStep.completed) ...[
          const SizedBox(height: 16),
          // AI/OCR Raw Extracted Text Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.smart_toy_rounded, size: 18, color: AppTheme.primaryBlue),
                        SizedBox(width: 6),
                        Text(
                          'AI / OCR Extracted Raw Text',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Engine: ${state.extractionResult?.engineName ?? "google_cloud_vision_v1"}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  state.rawExtractedText ?? '',
                  style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.black87),
                ),
                if (state.extractionResult?.confidenceScore != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Derived OCR Confidence Score: ${(state.extractionResult!.confidenceScore! * 100).toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade800, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Citizen Review & Verification Editable Field
          const Text(
            'Citizen Verification & Correction (Required)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            'Please review and correct any Malayalam text misinterpretations before confirming.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _verifiedTextController,
            maxLines: 5,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Verified Malayalam petition text...',
            ),
            style: const TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 20),

          // Explicit Confirmation Button
          CustomButton(
            text: 'Explicitly Confirm Extracted Text & Register Grievance',
            onPressed: _confirmAndSubmitHandwritten,
            backgroundColor: AppTheme.success,
          ),
        ],
      ],
    );
  }

  Widget _buildDirectTextSection(GrievanceIntakeState state, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomTextField(
          controller: _directTitleController,
          label: 'Grievance Title',
          hint: 'e.g., Road repair request in Ward 4',
          prefixIcon: Icons.title_rounded,
        ),
        const SizedBox(height: 16),
        const Text(
          'Direct Text Content (Malayalam / English)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _directTextController,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'Enter your grievance details clearly...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        CustomButton(
          text: 'Submit Direct Text Grievance',
          onPressed: _submitDirectText,
          isLoading: state.isLoading,
        ),
      ],
    );
  }

  Widget _buildVoicePlaceholderSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        children: [
          Icon(Icons.mic_none_rounded, size: 48, color: Colors.amber.shade800),
          const SizedBox(height: 12),
          Text(
            'Malayalam Voice Input Arriving Soon',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.amber.shade900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Malayalam Voice Intake (Speech-to-Text) will be integrated in the upcoming development phase. Please use Handwritten Petition OCR or Direct Text Input to file your grievance today.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}
