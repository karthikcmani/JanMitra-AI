import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
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

  // Live Voice Recording State
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Amplitude>? _amplitudeSub;
  Timer? _recordingTimer;
  bool _isRecordingVoice = false;
  int _recordingSeconds = 0;
  double _normalizedAmplitude = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingAutoLaunch();
    });
  }

  void _checkPendingAutoLaunch() {
    if (!mounted) return;
    final state = ref.read(grievanceIntakeProvider);
    final action = state.autoLaunchAction;
    if (action != null) {
      ref.read(grievanceIntakeProvider.notifier).clearAutoLaunchAction();
      if (action == 'live_camera') {
        _openLiveCameraViewfinder();
      } else if (action == 'live_voice') {
        _startLiveVoiceRecording();
      }
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _amplitudeSub?.cancel();
    _audioRecorder.dispose();
    _directTitleController.dispose();
    _directTextController.dispose();
    _verifiedTextController.dispose();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final mins = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  // ===========================================================================
  // 1. IN-APP LIVE CAMERA VIEWFINDER & OS CAMERA FALLBACK
  // ===========================================================================

  Future<void> _openLiveCameraViewfinder() async {
    if (kIsWeb) {
      await _captureFromSystemCamera();
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        await _captureFromSystemCamera();
        return;
      }

      if (!mounted) return;
      final XFile? capturedFile = await showModalBottomSheet<XFile?>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.black,
        builder: (ctx) => _LiveCameraViewfinderModal(
          cameras: cameras,
          onFallbackSystemCamera: () async {
            Navigator.of(ctx).pop(null);
            await _captureFromSystemCamera();
          },
        ),
      );

      if (capturedFile != null && mounted) {
        final bytes = await capturedFile.length();
        final fileName =
            'live_camera_petition_${DateTime.now().millisecondsSinceEpoch}.jpg';
        ref.read(grievanceIntakeProvider.notifier).setPickedFile(
              capturedFile.path,
              fileName,
              bytes,
            );
        await _triggerExtraction();
      }
    } catch (e) {
      // Fallback to OS camera intent if hardware camera preview fails
      await _captureFromSystemCamera();
    }
  }

  Future<void> _captureFromSystemCamera() async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
        maxWidth: 2048,
        maxHeight: 2048,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo != null && mounted) {
        final bytes = await photo.length();
        final fileName = photo.name.isNotEmpty
            ? photo.name
            : 'camera_petition_${DateTime.now().millisecondsSinceEpoch}.jpg';
        ref.read(grievanceIntakeProvider.notifier).setPickedFile(
              photo.path,
              fileName,
              bytes,
            );
        await _triggerExtraction();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera error: ${e.toString()}'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
        maxWidth: 2048,
        maxHeight: 2048,
      );

      if (image != null && mounted) {
        final bytes = await image.length();
        final fileName = image.name.isNotEmpty
            ? image.name
            : 'gallery_petition_${DateTime.now().millisecondsSinceEpoch}.jpg';
        ref.read(grievanceIntakeProvider.notifier).setPickedFile(
              image.path,
              fileName,
              bytes,
            );
        await _triggerExtraction();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gallery error: ${e.toString()}'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  // ===========================================================================
  // 2. IN-APP LIVE MICROPHONE AUDIO RECORDER
  // ===========================================================================

  Future<void> _startLiveVoiceRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Microphone permission is required to record voice grievances.',
              ),
              backgroundColor: AppTheme.danger,
            ),
          );
        }
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${tempDir.path}/live_voice_petition_$timestamp.m4a';

      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      );

      await _audioRecorder.start(config, path: filePath);

      _recordingTimer?.cancel();
      _amplitudeSub?.cancel();

      setState(() {
        _isRecordingVoice = true;
        _recordingSeconds = 0;
        _normalizedAmplitude = 0.2;
      });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _isRecordingVoice) {
          setState(() {
            _recordingSeconds++;
          });
        }
      });

      _amplitudeSub = _audioRecorder
          .onAmplitudeChanged(const Duration(milliseconds: 200))
          .listen((amp) {
        if (mounted && _isRecordingVoice) {
          // amp.current is typically between -60 dB (silent) and 0 dB (loud)
          final clamped = ((amp.current + 55.0) / 55.0).clamp(0.08, 1.0);
          setState(() {
            _normalizedAmplitude = clamped;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to start microphone recording: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  Future<void> _stopLiveVoiceRecording({bool cancel = false}) async {
    _recordingTimer?.cancel();
    _amplitudeSub?.cancel();

    try {
      final recordedPath = await _audioRecorder.stop();
      setState(() {
        _isRecordingVoice = false;
        _normalizedAmplitude = 0.0;
      });

      if (cancel || recordedPath == null) {
        return;
      }

      final file = File(recordedPath);
      if (await file.exists()) {
        final sizeBytes = await file.length();
        final fileName =
            'live_voice_petition_${DateTime.now().millisecondsSinceEpoch}.m4a';
        ref.read(grievanceIntakeProvider.notifier).setPickedFile(
              file.path,
              fileName,
              sizeBytes,
            );
        await _triggerExtraction();
      }
    } catch (e) {
      setState(() {
        _isRecordingVoice = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving voice recording: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  Future<void> _pickDocument({bool isAudio = false}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: isAudio
            ? ['wav', 'mp3', 'm4a', 'aac', 'flac', 'ogg', 'opus', 'webm']
            : ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        ref.read(grievanceIntakeProvider.notifier).setPickedFile(
              file.path!,
              file.name,
              file.size,
            );
        if (isAudio) {
          await _triggerExtraction();
        }
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

  Future<void> _confirmAndSubmitHandwritten() async {
    final notifier = ref.read(grievanceIntakeProvider.notifier);
    notifier.updateVerifiedText(_verifiedTextController.text);
    await notifier.confirmVerification();

    final state = ref.read(grievanceIntakeProvider);
    if (state.isConfirmed && state.grievance != null && mounted) {
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
              ref.invalidate(myGrievancesProvider);
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
            if (_isRecordingVoice) {
              _stopLiveVoiceRecording(cancel: true);
            }
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
                          title: 'Live Camera / OCR',
                          subtitle: 'Live Scan / Photo / PDF',
                          icon: Icons.camera_alt_rounded,
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
                          title: 'Live Voice Intake',
                          subtitle: 'Record Mic / Audio STT',
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

                  // MODE 1: HANDWRITTEN PETITION / LIVE CAMERA OCR FLOW
                  if (state.intakeMode == 'ocr_handwritten') ...[
                    _buildHandwrittenIntakeSection(state, isDark),
                  ],

                  // MODE 2: DIRECT TEXT FLOW
                  if (state.intakeMode == 'direct_text') ...[
                    _buildDirectTextSection(state, isDark),
                  ],

                  // MODE 3: LIVE VOICE RECORDING & AUDIO STT FLOW
                  if (state.intakeMode == 'voice_stt') ...[
                    _buildVoiceIntakeSection(state, isDark),
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
        if (_isRecordingVoice && modeKey != 'voice_stt') {
          _stopLiveVoiceRecording(cancel: true);
        }
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandwrittenIntakeSection(GrievanceIntakeState state, bool isDark) {
    final hasFile = state.selectedFileName != null && state.selectedFilePath != null;
    final isImage = hasFile && !state.selectedFileName!.toLowerCase().endsWith('.pdf');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Intake Source Card (In-App Live Camera Viewfinder + System Camera + Gallery + PDF)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasFile
                  ? AppTheme.primaryBlue.withValues(alpha: 0.4)
                  : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
              width: hasFile ? 1.5 : 1.0,
            ),
            boxShadow: [
              if (hasFile)
                BoxShadow(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.document_scanner_rounded,
                  size: 34,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Live Camera Petition Scanner & Photo Intake',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              const Text(
                'Use the live in-app camera viewfinder to frame and capture your handwritten or printed petition, or select from Gallery / PDF',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              // Primary CTA: In-App Live Camera Viewfinder
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openLiveCameraViewfinder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.camera_enhance_rounded, size: 22),
                  label: const Text(
                    'Open Live Camera Scanner (In-App Viewfinder)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Secondary Row: System Camera, Gallery, PDF
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _captureFromSystemCamera,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: BorderSide(color: AppTheme.primaryBlue.withValues(alpha: 0.6)),
                      ),
                      icon: const Icon(Icons.photo_camera_outlined, size: 17),
                      label: const Text(
                        'OS Camera',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickFromGallery,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: BorderSide(color: AppTheme.primaryBlue.withValues(alpha: 0.6)),
                      ),
                      icon: const Icon(Icons.photo_library_rounded, size: 17),
                      label: const Text(
                        'Gallery',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDocument(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 17),
                      label: const Text(
                        'PDF File',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (hasFile) ...[
          // Photo / Document Preview Card
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isImage && !kIsWeb && File(state.selectedFilePath!).existsSync()) ...[
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: Container(
                      height: 220,
                      width: double.infinity,
                      color: Colors.black12,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            File(state.selectedFilePath!),
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'Captured & Ready',
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                ListTile(
                  leading: Icon(
                    isImage ? Icons.image_rounded : Icons.picture_as_pdf_rounded,
                    color: AppTheme.primaryBlue,
                    size: 32,
                  ),
                  title: Text(
                    state.selectedFileName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  subtitle: Text(
                    'Original Citizen Artifact • ${((state.selectedFileSizeBytes ?? 0) / 1024).toStringAsFixed(1)} KB',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: TextButton.icon(
                    onPressed: _openLiveCameraViewfinder,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Retake', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Upload & Extract Trigger Button
          if (state.extractionStep == IntakeExtractionStep.idle) ...[
            CustomButton(
              text: 'Upload & Extract Malayalam Text via Multimodal OCR',
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
                          ? 'Uploading captured petition image to server...'
                          : 'AI Multimodal Intelligence: Extracting Malayalam & English text...',
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
          if (state.rawExtractedText != null && state.rawExtractedText!.isNotEmpty) ...[
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
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      const Row(
                        mainAxisSize: MainAxisSize.min,
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
                          'Engine: ${state.extractionResult?.engineName ?? "gemini_vision_ocr_v1"}',
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
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Colors.amber.shade900, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Manual Verification Required',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your captured photo is attached. Please enter or verify the complaint text below.',
                    style: TextStyle(fontSize: 12, height: 1.4, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),

          const Text(
            'Citizen Petition Text Entry / Verification (Required)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            'Please review or edit the extracted petition text below before confirming.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _verifiedTextController,
            maxLines: 6,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Type or verify your petition text here (Malayalam / English)...',
            ),
            style: const TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 20),

          CustomButton(
            text: 'Confirm Petition Text & Register Grievance',
            onPressed: _confirmAndSubmitHandwritten,
            isLoading: state.isLoading,
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

  Widget _buildVoiceIntakeSection(GrievanceIntakeState state, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Live Voice Recording & Audio File Upload Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isRecordingVoice
                  ? AppTheme.danger
                  : AppTheme.secondaryTeal.withValues(alpha: 0.4),
              width: _isRecordingVoice ? 2.0 : 1.2,
            ),
            boxShadow: [
              if (_isRecordingVoice)
                BoxShadow(
                  color: AppTheme.danger.withValues(alpha: 0.15),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _isRecordingVoice
                      ? AppTheme.danger.withValues(alpha: 0.15)
                      : AppTheme.secondaryTeal.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isRecordingVoice ? Icons.mic_none_rounded : Icons.mic_rounded,
                  size: 38,
                  color: _isRecordingVoice ? AppTheme.danger : AppTheme.secondaryTeal,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _isRecordingVoice
                    ? 'Recording Live Voice Grievance...'
                    : 'Live Malayalam & English Voice Intake',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: _isRecordingVoice ? AppTheme.danger : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isRecordingVoice
                    ? 'Speak clearly in Malayalam or English. Tap "Stop & Transcribe" when finished.'
                    : 'Record your complaint directly using your microphone or upload an existing audio recording',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              if (_isRecordingVoice) ...[
                // Live Recording Timer + Voice Level Meter
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppTheme.danger,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'LIVE • ${_formatDuration(_recordingSeconds)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: AppTheme.danger,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: _normalizedAmplitude,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.danger),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Microphone Input Level',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: () => _stopLiveVoiceRecording(cancel: false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.stop_circle_rounded, size: 22),
                        label: const Text(
                          'Stop & Auto-Transcribe',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: () => _stopLiveVoiceRecording(cancel: true),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.danger,
                          side: const BorderSide(color: AppTheme.danger),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Primary Live Microphone Recording Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _startLiveVoiceRecording,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.mic_rounded, size: 22),
                    label: const Text(
                      'Start Live Voice Recording (Malayalam / English)',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Secondary Option: Upload Audio File
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDocument(isAudio: true),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: BorderSide(color: AppTheme.secondaryTeal.withValues(alpha: 0.6)),
                    ),
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: Text(
                      state.selectedFileName != null
                          ? 'Change Audio File (${state.selectedFileName})'
                          : 'Or Browse / Upload Audio File (WAV, MP3, M4A, OGG)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (state.selectedFileName != null && !_isRecordingVoice) ...[
          // Audio File Metadata Card
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: const Icon(Icons.audio_file_rounded, color: AppTheme.secondaryTeal, size: 32),
              title: Text(
                state.selectedFileName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              subtitle: Text(
                'Voice Audio Artifact • ${((state.selectedFileSizeBytes ?? 0) / 1024).toStringAsFixed(1)} KB',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: TextButton.icon(
                onPressed: _triggerExtraction,
                icon: const Icon(Icons.sync_rounded, size: 16),
                label: const Text('Re-Transcribe', style: TextStyle(fontSize: 12)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Upload & Transcribe Trigger Button
          if (state.extractionStep == IntakeExtractionStep.idle) ...[
            CustomButton(
              text: 'Transcribe Malayalam / English Audio via AI STT',
              onPressed: _triggerExtraction,
              isLoading: state.isLoading,
            ),
          ],
        ],

        // STT Processing Indicator
        if (state.extractionStep == IntakeExtractionStep.uploading ||
            state.extractionStep == IntakeExtractionStep.extracting) ...[
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Transcribing Malayalam & English speech via High-Speed Whisper / Gemini Multimodal Audio STT...',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Transcription Completed Display & Verification Area
        if (state.extractionStep == IntakeExtractionStep.completed) ...[
          const SizedBox(height: 16),
          if (state.rawExtractedText != null && state.rawExtractedText!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.teal.shade50.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.record_voice_over_rounded, size: 18, color: AppTheme.secondaryTeal),
                          SizedBox(width: 6),
                          Text(
                            'AI Speech-to-Text Transcribed Petition',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryTeal,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Engine: ${state.extractionResult?.engineName ?? "multimodal_stt_v2"}',
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
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Colors.deepOrange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Audio Attached — Please Verify Text Below',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Your voice recording is attached. Please review or type your petition details in the box below before submitting.',
                    style: TextStyle(fontSize: 12, height: 1.4, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Citizen Verification Field
          const Text(
            'Citizen Petition Text Entry / Verification (Required)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            'Please review or edit your transcribed voice petition text before submitting.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _verifiedTextController,
            maxLines: 6,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Transcribed text will appear here. Edit if needed...',
            ),
            style: const TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 20),

          CustomButton(
            text: 'Confirm Petition Text & Register Grievance',
            onPressed: _confirmAndSubmitHandwritten,
            isLoading: state.isLoading,
            backgroundColor: AppTheme.success,
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// IN-APP LIVE CAMERA VIEWFINDER MODAL WIDGET
// =============================================================================

class _LiveCameraViewfinderModal extends StatefulWidget {
  final List<CameraDescription> cameras;
  final VoidCallback onFallbackSystemCamera;

  const _LiveCameraViewfinderModal({
    required this.cameras,
    required this.onFallbackSystemCamera,
  });

  @override
  State<_LiveCameraViewfinderModal> createState() =>
      _LiveCameraViewfinderModalState();
}

class _LiveCameraViewfinderModalState extends State<_LiveCameraViewfinderModal> {
  CameraController? _controller;
  int _selectedCameraIdx = 0;
  bool _isInitializing = true;
  bool _isTakingPicture = false;
  FlashMode _flashMode = FlashMode.off;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    // Prefer rear camera by default
    final rearIndex = widget.cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    _selectedCameraIdx = rearIndex != -1 ? rearIndex : 0;
    _initCamera(_selectedCameraIdx);
  }

  Future<void> _initCamera(int index) async {
    setState(() {
      _isInitializing = true;
      _cameraError = null;
    });

    final prevController = _controller;
    if (prevController != null) {
      await prevController.dispose();
    }

    final cameraDesc = widget.cameras[index];
    final controller = CameraController(
      cameraDesc,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _controller = controller;

    try {
      await controller.initialize();
      try {
        await controller.setFlashMode(_flashMode);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _cameraError = e.toString();
        });
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final nextMode = _flashMode == FlashMode.off
        ? FlashMode.torch
        : (_flashMode == FlashMode.torch ? FlashMode.auto : FlashMode.off);
    try {
      await _controller!.setFlashMode(nextMode);
      setState(() {
        _flashMode = nextMode;
      });
    } catch (_) {}
  }

  Future<void> _switchCamera() async {
    if (widget.cameras.length < 2) return;
    final nextIdx = (_selectedCameraIdx + 1) % widget.cameras.length;
    _selectedCameraIdx = nextIdx;
    await _initCamera(nextIdx);
  }

  Future<void> _snapPhoto() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isTakingPicture) {
      return;
    }

    setState(() {
      _isTakingPicture = true;
    });

    try {
      final XFile photo = await controller.takePicture();
      if (mounted) {
        Navigator.of(context).pop(photo);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTakingPicture = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Capture failed: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.92,
      child: Column(
        children: [
          // Top Camera Control Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            color: Colors.black,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                  tooltip: 'Close Scanner',
                ),
                const Row(
                  children: [
                    Icon(Icons.document_scanner_rounded, color: Colors.lightBlueAccent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Live Petition Scanner',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _toggleFlash,
                      icon: Icon(
                        _flashMode == FlashMode.torch
                            ? Icons.highlight_rounded
                            : (_flashMode == FlashMode.auto
                                ? Icons.flash_auto_rounded
                                : Icons.flash_off_rounded),
                        color: _flashMode == FlashMode.off
                            ? Colors.white70
                            : Colors.amberAccent,
                      ),
                      tooltip: 'Toggle Flash',
                    ),
                    if (widget.cameras.length > 1)
                      IconButton(
                        onPressed: _switchCamera,
                        icon: const Icon(
                          Icons.cameraswitch_rounded,
                          color: Colors.white,
                        ),
                        tooltip: 'Switch Camera',
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Live Camera Viewfinder Area
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: _isInitializing
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 12),
                          Text(
                            'Starting live camera viewfinder...',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : (_cameraError != null ||
                          _controller == null ||
                          !_controller!.value.isInitialized)
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.camera_alt_outlined,
                                  color: Colors.white54,
                                  size: 48,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Live preview unavailable on this device (${_cameraError ?? "Camera busy"}).',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: widget.onFallbackSystemCamera,
                                  icon: const Icon(Icons.photo_camera_rounded),
                                  label: const Text('Use System Camera App'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            Center(
                              child: CameraPreview(_controller!),
                            ),
                            // Petition Alignment Guide Frame Overlay
                            IgnorePointer(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                  vertical: 36,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.lightBlueAccent.withValues(alpha: 0.8),
                                      width: 2.0,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: Container(
                                      margin: const EdgeInsets.only(top: 12),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.65),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        'Align handwritten or printed petition within frame',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
            ),
          ),

          // Bottom Shutter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            color: Colors.black,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: widget.onFallbackSystemCamera,
                  icon: const Icon(Icons.camera_outlined, color: Colors.white70, size: 18),
                  label: const Text(
                    'OS Camera',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                GestureDetector(
                  onTap: _isTakingPicture ? null : _snapPhoto,
                  child: Container(
                    width: 74,
                    height: 74,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3.5),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _isTakingPicture ? Colors.grey : Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: _isTakingPicture
                          ? const Padding(
                              padding: EdgeInsets.all(18.0),
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: AppTheme.primaryBlue,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt_rounded,
                              color: AppTheme.primaryBlue,
                              size: 32,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 88),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
