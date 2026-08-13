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
  }) async {
    final response = await apiService.post(
      '/grievances/intake/draft',
      data: {
        'title': title ?? 'Multimodal Grievance Draft',
        'intake_mode': intakeMode,
        'original_language': originalLanguage,
        'original_text': originalText,
      },
    );
    return GrievanceModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Uploads an intake file attachment (Image/PDF) for a draft grievance
  Future<GrievanceAttachmentModel> uploadAttachment({
    required String grievanceId,
    required String filePath,
    required String fileName,
    String attachmentType = 'handwritten_petition',
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
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
}
