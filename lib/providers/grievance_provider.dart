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

  void selectIntakeMode(String mode) {
    state = state.copyWith(intakeMode: mode, errorMessage: null);
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

      final draft = await _repository.createDraft(
        title: 'Handwritten Petition Intake: ${state.selectedFileName}',
        intakeMode: 'ocr_handwritten',
        originalLanguage: 'ml',
      );

      // Step 2: Upload File Attachment
      final attachment = await _repository.uploadAttachment(
        grievanceId: draft.id,
        filePath: state.selectedFilePath!,
        fileName: state.selectedFileName!,
        attachmentType: 'handwritten_petition',
      );

      // Step 3: Trigger Extraction Engine
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
      final detail = e.response?.data?['detail']?.toString() ?? e.message;
      state = state.copyWith(
        extractionStep: IntakeExtractionStep.completed,
        isLoading: false,
        errorMessage: 'Note: Automatic OCR unavailable ($detail). Please type/verify the complaint text below.',
      );
    } catch (e) {
      state = state.copyWith(
        extractionStep: IntakeExtractionStep.completed,
        isLoading: false,
        errorMessage: 'Note: Automatic OCR unavailable. Please type/verify the complaint text below.',
      );
    }
  }

  void updateVerifiedText(String text) {
    state = state.copyWith(verifiedText: text);
  }

  Future<void> confirmVerification() async {
    if (state.verifiedText.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Grievance text cannot be empty.');
      return;
    }

    if (state.grievance == null) {
      state = state.copyWith(errorMessage: 'No active grievance draft found.');
      return;
    }

    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      final confirmed = await _repository.verifyGrievance(
        grievanceId: state.grievance!.id,
        verifiedText: state.verifiedText.trim(),
        attachmentId: state.attachment?.id,
      );

      state = state.copyWith(
        grievance: confirmed,
        isConfirmed: true,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to confirm grievance: ${e.toString()}',
      );
    }
  }

  Future<GrievanceModel?> submitDirectText({
    required String title,
    required String text,
  }) async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);
      final draft = await _repository.createDraft(
        title: title,
        intakeMode: 'direct_text',
        originalLanguage: 'ml',
        originalText: text,
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

  void reset() {
    state = const GrievanceIntakeState();
  }
}
