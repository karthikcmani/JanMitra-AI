import 'package:dio/dio.dart';
import '../models/grievance_model.dart';
import '../services/api_service.dart';

class GrievanceRepository {
  final ApiService apiService;

  GrievanceRepository(this.apiService);

  /// Initializes a new Grievance Draft on FastAPI backend
  Future<GrievanceModel> createDraft({
    String? title,
    String intakeMode = 'ocr_handwritten',
    String originalLanguage = 'ml',
    String? originalText,
    String? petitionerName,
    String filingType = 'self',
    String? relationship,
    String? petitionerPhone,
  }) async {
    final response = await apiService.post(
      '/grievances/intake/draft',
      data: {
        'title': title ?? 'Multimodal Grievance Draft',
        'intake_mode': intakeMode,
        'original_language': originalLanguage,
        'original_text': originalText,
        'petitioner_name': petitionerName,
        'filing_type': filingType,
        'relationship': relationship,
        'petitioner_phone': petitionerPhone,
      },
    );
    return GrievanceModel.fromJson(response.data as Map<String, dynamic>);
  }

  DioMediaType _resolveMediaType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return DioMediaType('image', 'jpeg');
    } else if (lower.endsWith('.png')) {
      return DioMediaType('image', 'png');
    } else if (lower.endsWith('.webp')) {
      return DioMediaType('image', 'webp');
    } else if (lower.endsWith('.pdf')) {
      return DioMediaType('application', 'pdf');
    } else if (lower.endsWith('.wav')) {
      return DioMediaType('audio', 'wav');
    } else if (lower.endsWith('.mp3')) {
      return DioMediaType('audio', 'mpeg');
    } else if (lower.endsWith('.m4a') || lower.endsWith('.mp4')) {
      return DioMediaType('audio', 'mp4');
    } else if (lower.endsWith('.aac')) {
      return DioMediaType('audio', 'aac');
    } else if (lower.endsWith('.ogg') || lower.endsWith('.opus')) {
      return DioMediaType('audio', 'ogg');
    } else if (lower.endsWith('.flac')) {
      return DioMediaType('audio', 'flac');
    } else if (lower.endsWith('.webm')) {
      return DioMediaType('audio', 'webm');
    }
    return DioMediaType('application', 'octet-stream');
  }

  /// Uploads an intake file attachment (Image/PDF/Audio) for a draft grievance
  Future<GrievanceAttachmentModel> uploadAttachment({
    required String grievanceId,
    required String filePath,
    required String fileName,
    String attachmentType = 'handwritten_petition',
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: fileName,
        contentType: _resolveMediaType(fileName),
      ),
      'attachment_type': attachmentType,
    });

    final response = await apiService.post(
      '/grievances/$grievanceId/attachments',
      data: formData,
    );
    return GrievanceAttachmentModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  /// Triggers intake extraction (Cloud Vision OCR) on a grievance attachment
  Future<NormalizedExtractionResultModel> extractAttachment({
    required String grievanceId,
    required String attachmentId,
  }) async {
    final response = await apiService.post(
      '/grievances/$grievanceId/attachments/$attachmentId/extract',
    );
    return NormalizedExtractionResultModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  /// Retrieves all grievances belonging to authenticated citizen
  Future<List<GrievanceModel>> getMyGrievances() async {
    final response = await apiService.get('/grievances/my');
    final list = response.data as List<dynamic>;
    return list
        .map((json) => GrievanceModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Retrieves detailed information for a specific grievance
  Future<GrievanceModel> getGrievanceById(String id) async {
    final response = await apiService.get('/grievances/$id');
    return GrievanceModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Submits citizen response to an official clarification request
  Future<GrievanceModel> submitClarification({
    required String grievanceId,
    required String responseText,
  }) async {
    final response = await apiService.post(
      '/grievances/$grievanceId/clarification',
      data: {'response_text': responseText},
    );
    return GrievanceModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Submits citizen verified / transcribed text for a grievance
  Future<GrievanceModel> verifyGrievance({
    required String grievanceId,
    required String verifiedText,
    String? attachmentId,
    String? petitionerName,
    String filingType = 'self',
    String? relationship,
    String? petitionerPhone,
  }) async {
    final response = await apiService.post(
      '/grievances/$grievanceId/verify',
      data: {
        'verified_text': verifiedText,
        'attachment_id': attachmentId,
        'petitioner_name': petitionerName,
        'filing_type': filingType,
        'relationship': relationship,
        'petitioner_phone': petitionerPhone,
      },
    );
    return GrievanceModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Triggers Sprint 11 AI Intelligence Analysis (Summarization, Multi-issue detection, Interview Generation)
  Future<GrievanceModel> triggerAIIntelligence(String grievanceId) async {
    final response = await apiService.post(
      '/grievances/$grievanceId/analyze-intelligence',
    );
    return GrievanceModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Submits citizen answers to generated interview questions and triggers re-analysis
  Future<GrievanceModel> submitInterviewResponses({
    required String grievanceId,
    required List<Map<String, String>> responses,
  }) async {
    final response = await apiService.post(
      '/grievances/$grievanceId/interview/responses',
      data: {'responses': responses},
    );
    return GrievanceModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Searches official government document knowledge base (Acts, Codes, Regulations)
  Future<List<Map<String, dynamic>>> searchKnowledgeBase(String query) async {
    final response = await apiService.get(
      '/legal/search',
      queryParameters: {'q': query},
    );
    final list = response.data as List<dynamic>;
    return list.map((j) => Map<String, dynamic>.from(j as Map)).toList();
  }

  /// Checks if candidate grievance is duplicate of an existing active grievance
  Future<Map<String, dynamic>> checkDuplicate({
    String? title,
    String? text,
    String? currentId,
  }) async {
    try {
      final response = await apiService.post(
        '/grievances/check-duplicate',
        data: {
          'title': title,
          'text': text,
          'current_id': currentId,
        },
      );
      return Map<String, dynamic>.from(response.data as Map);
    } catch (_) {
      return {'is_duplicate': false};
    }
  }
}

