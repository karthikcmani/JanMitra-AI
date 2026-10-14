import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/grievance_model.dart';
import '../repositories/grievance_repository.dart';
import 'theme_provider.dart';

final grievanceRepositoryProvider = Provider<GrievanceRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return GrievanceRepository(apiService);
});

final myGrievancesProvider = FutureProvider.autoDispose<List<GrievanceModel>>((ref) async {
  final repository = ref.watch(grievanceRepositoryProvider);
  return await repository.getMyGrievances();
});

/// Shared filter for complaint list screen ('All', 'Pending', 'Resolved', etc.)
final complaintFilterProvider = StateProvider<String>((ref) => 'All');

/// Active grievance ID currently focused on the Live Audit & Tracking screen
final selectedTrackingGrievanceIdProvider = StateProvider<String?>((ref) => null);


enum IntakeExtractionStep {
  idle,
  uploading,
  extracting,
  completed,
  failed,
}

class GrievanceIntakeState {
  final String intakeMode; // 'ocr_handwritten', 'direct_text', 'voice_stt'
  final String? selectedFilePath;
  final String? selectedFileName;
  final int? selectedFileSizeBytes;
  final GrievanceModel? grievance;
  final GrievanceAttachmentModel? attachment;
  final NormalizedExtractionResultModel? extractionResult;
  final IntakeExtractionStep extractionStep;
  final String? rawExtractedText;
  final String verifiedText;
  final String? errorMessage;
  final bool isConfirmed;
  final bool isLoading;
  final String? autoLaunchAction; // 'live_camera' or 'live_voice'

  const GrievanceIntakeState({
    this.intakeMode = 'ocr_handwritten',
    this.selectedFilePath,
    this.selectedFileName,
    this.selectedFileSizeBytes,
    this.grievance,
    this.attachment,
    this.extractionResult,
    this.extractionStep = IntakeExtractionStep.idle,
    this.rawExtractedText,
    this.verifiedText = '',
    this.errorMessage,
    this.isConfirmed = false,
    this.isLoading = false,
    this.autoLaunchAction,
  });

  GrievanceIntakeState copyWith({
    String? intakeMode,
    String? selectedFilePath,
    String? selectedFileName,
    int? selectedFileSizeBytes,
    GrievanceModel? grievance,
    GrievanceAttachmentModel? attachment,
    NormalizedExtractionResultModel? extractionResult,
    IntakeExtractionStep? extractionStep,
    String? rawExtractedText,
    String? verifiedText,
    String? errorMessage,
    bool? isConfirmed,
    bool? isLoading,
    String? autoLaunchAction,
    bool clearAutoLaunch = false,
  }) {
    return GrievanceIntakeState(
      intakeMode: intakeMode ?? this.intakeMode,
      selectedFilePath: selectedFilePath ?? this.selectedFilePath,
      selectedFileName: selectedFileName ?? this.selectedFileName,
      selectedFileSizeBytes: selectedFileSizeBytes ?? this.selectedFileSizeBytes,
      grievance: grievance ?? this.grievance,
      attachment: attachment ?? this.attachment,
      extractionResult: extractionResult ?? this.extractionResult,
      extractionStep: extractionStep ?? this.extractionStep,
      rawExtractedText: rawExtractedText ?? this.rawExtractedText,
      verifiedText: verifiedText ?? this.verifiedText,
      errorMessage: errorMessage,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      isLoading: isLoading ?? this.isLoading,
      autoLaunchAction: clearAutoLaunch ? null : (autoLaunchAction ?? this.autoLaunchAction),
    );
  }
}

final grievanceIntakeProvider =
    StateNotifierProvider<GrievanceIntakeNotifier, GrievanceIntakeState>((ref) {
  final repository = ref.watch(grievanceRepositoryProvider);
  return GrievanceIntakeNotifier(repository);
});

class GrievanceIntakeNotifier extends StateNotifier<GrievanceIntakeState> {
  final GrievanceRepository _repository;

  GrievanceIntakeNotifier(this._repository) : super(const GrievanceIntakeState());

  void selectIntakeMode(String mode, {String? autoLaunchAction}) {
    state = state.copyWith(
      intakeMode: mode,
      errorMessage: null,
      autoLaunchAction: autoLaunchAction,
      clearAutoLaunch: autoLaunchAction == null,
    );
  }

  void clearAutoLaunchAction() {
    state = state.copyWith(clearAutoLaunch: true);
  }

  void setPickedFile(String filePath, String fileName, int sizeBytes) {
    state = state.copyWith(
      selectedFilePath: filePath,
      selectedFileName: fileName,
      selectedFileSizeBytes: sizeBytes,
      extractionStep: IntakeExtractionStep.idle,
      rawExtractedText: null,
      verifiedText: '',
      isConfirmed: false,
      errorMessage: null,
    );
  }

  Future<void> uploadAndExtractDocument() async {
    if (state.selectedFilePath == null || state.selectedFileName == null) {
      state = state.copyWith(errorMessage: 'Please select a document file first.');
      return;
    }

    try {
      // Step 1: Initialize Draft on FastAPI Backend
      state = state.copyWith(
        isLoading: true,
        extractionStep: IntakeExtractionStep.uploading,
        errorMessage: null,
      );

      final isAudioFile = state.selectedFileName != null &&
          ['.m4a', '.wav', '.mp3', '.aac', '.ogg', '.opus', '.flac', '.webm']
              .any((ext) => state.selectedFileName!.toLowerCase().endsWith(ext));
      final isVoice = state.intakeMode == 'voice_stt' || isAudioFile;
      final draft = await _repository.createDraft(
        title: isVoice
            ? 'Voice Petition Intake: ${state.selectedFileName}'
            : 'Handwritten Petition Intake: ${state.selectedFileName}',
        intakeMode: isVoice ? 'voice_stt' : 'ocr_handwritten',
        originalLanguage: 'ml',
      );

      // Immediately persist the draft in state so citizen verification always has a valid grievance ID
      state = state.copyWith(grievance: draft);

      // Step 2: Upload File Attachment
      final attachment = await _repository.uploadAttachment(
        grievanceId: draft.id,
        filePath: state.selectedFilePath!,
        fileName: state.selectedFileName!,
        attachmentType: isVoice ? 'voice_recording' : 'handwritten_petition',
      );

      // Fast-path: If attachment was extracted during upload, complete immediately
      if (attachment.extractionStatus == 'completed' &&
          attachment.rawExtractedText != null &&
          attachment.rawExtractedText!.isNotEmpty) {
        state = state.copyWith(
            grievance: draft,
            attachment: attachment,
            rawExtractedText: attachment.rawExtractedText,
            verifiedText: attachment.rawExtractedText!,
            extractionStep: IntakeExtractionStep.completed,
            isLoading: false,
          );
        return;
      }

      // Step 3: Trigger Extraction Engine if not already completed
      state = state.copyWith(
        grievance: draft,
        attachment: attachment,
        extractionStep: IntakeExtractionStep.extracting,
      );

      final extractionResult = await _repository.extractAttachment(
        grievanceId: draft.id,
        attachmentId: attachment.id,
      );

      if (extractionResult.extractionStatus == 'completed' &&
          extractionResult.extractedText != null &&
          extractionResult.extractedText!.isNotEmpty) {
        state = state.copyWith(
          extractionResult: extractionResult,
          rawExtractedText: extractionResult.extractedText,
          verifiedText: extractionResult.extractedText!,
          extractionStep: IntakeExtractionStep.completed,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          extractionResult: extractionResult,
          rawExtractedText: null,
          verifiedText: '',
          extractionStep: IntakeExtractionStep.completed,
          isLoading: false,
          errorMessage: null,
        );
      }
    } on DioException catch (e) {
      final isAudioFile = state.selectedFileName != null &&
          ['.m4a', '.wav', '.mp3', '.aac', '.ogg', '.opus', '.flac', '.webm']
              .any((ext) => state.selectedFileName!.toLowerCase().endsWith(ext));
      final isVoice = state.intakeMode == 'voice_stt' || isAudioFile;
      final detail = e.response?.data?['detail']?.toString() ?? e.message;
      state = state.copyWith(
        extractionStep: IntakeExtractionStep.completed,
        isLoading: false,
        errorMessage: isVoice
            ? 'Note: Automatic voice transcription unavailable ($detail). Please verify or type the complaint text below.'
            : 'Note: Automatic OCR unavailable ($detail). Please type/verify the complaint text below.',
      );
    } catch (e) {
      final isAudioFile = state.selectedFileName != null &&
          ['.m4a', '.wav', '.mp3', '.aac', '.ogg', '.opus', '.flac', '.webm']
              .any((ext) => state.selectedFileName!.toLowerCase().endsWith(ext));
      final isVoice = state.intakeMode == 'voice_stt' || isAudioFile;
      state = state.copyWith(
        extractionStep: IntakeExtractionStep.completed,
        isLoading: false,
        errorMessage: isVoice
            ? 'Note: Automatic voice transcription unavailable. Please verify or type the complaint text below.'
            : 'Note: Automatic OCR unavailable. Please type/verify the complaint text below.',
      );
    }
  }

  void updateVerifiedText(String text) {
    state = state.copyWith(verifiedText: text);
  }

  Future<void> confirmVerification({
    String? petitionerName,
    String filingType = 'self',
    String? relationship,
    String? petitionerPhone,
  }) async {
    if (state.verifiedText.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Grievance text cannot be empty.');
      return;
    }

    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      var activeGrievance = state.grievance;
      if (activeGrievance == null) {
        final isVoice = state.intakeMode == 'voice_stt';
        activeGrievance = await _repository.createDraft(
          title: isVoice
              ? 'Voice Petition Intake: ${state.selectedFileName ?? "Live Audio"}'
              : 'Handwritten Petition Intake: ${state.selectedFileName ?? "Camera Scan"}',
          intakeMode: isVoice ? 'voice_stt' : 'ocr_handwritten',
          originalLanguage: 'ml',
          petitionerName: petitionerName,
          filingType: filingType,
          relationship: relationship,
          petitionerPhone: petitionerPhone,
        );
        state = state.copyWith(grievance: activeGrievance);
      }

      final confirmed = await _repository.verifyGrievance(
        grievanceId: activeGrievance.id,
        verifiedText: state.verifiedText.trim(),
        attachmentId: state.attachment?.id,
        petitionerName: petitionerName,
        filingType: filingType,
        relationship: relationship,
        petitionerPhone: petitionerPhone,
      );

      state = state.copyWith(
        grievance: confirmed,
        isConfirmed: true,
        isLoading: false,
      );
    } catch (e) {
      final msg = e is DioException
          ? (e.response?.data is Map && e.response?.data['detail'] != null
              ? e.response?.data['detail'].toString()
              : (e.message ?? e.toString()))
          : e.toString();
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to confirm grievance: $msg',
      );
    }
  }

  Future<GrievanceModel?> submitDirectText({
    required String title,
    required String text,
    String? petitionerName,
    String filingType = 'self',
    String? relationship,
    String? petitionerPhone,
  }) async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);
      final draft = await _repository.createDraft(
        title: title,
        intakeMode: 'direct_text',
        originalLanguage: 'ml',
        originalText: text,
        petitionerName: petitionerName,
        filingType: filingType,
        relationship: relationship,
        petitionerPhone: petitionerPhone,
      );
      state = state.copyWith(
        grievance: draft,
        rawExtractedText: text,
        verifiedText: text,
        isConfirmed: true,
        isLoading: false,
      );
      return draft;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to submit direct text grievance: ${e.toString()}',
      );
      return null;
    }
  }

  Future<Map<String, dynamic>> checkDuplicate({
    String? title,
    String? text,
  }) async {
    return await _repository.checkDuplicate(
      title: title,
      text: text,
      currentId: state.grievance?.id,
    );
  }

  void reset() {
    state = const GrievanceIntakeState();
  }
}
