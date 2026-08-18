class GrievanceModel {
  final String id;
  final String grievanceNumber;
  final String citizenId;
  final String? title;
  final String? description;
  final String intakeMode;
  final String originalLanguage;
  final String? originalText;
  final String? translatedText;
  final String status;
  final String priority;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GrievanceModel({
    required this.id,
    required this.grievanceNumber,
    required this.citizenId,
    this.title,
    this.description,
    required this.intakeMode,
    required this.originalLanguage,
    this.originalText,
    this.translatedText,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GrievanceModel.fromJson(Map<String, dynamic> json) {
    return GrievanceModel(
      id: json['id'] as String,
      grievanceNumber: (json['grievance_number'] ?? json['id']) as String,
      citizenId: (json['citizen_id'] ?? '') as String,
      title: json['title'] as String?,
      description: json['description'] as String?,
      intakeMode: (json['intake_mode'] ?? 'direct_text') as String,
      originalLanguage: (json['original_language'] ?? 'ml') as String,
      originalText: json['original_text'] as String?,
      translatedText: json['translated_text'] as String?,
      status: (json['status'] ?? 'draft') as String,
      priority: (json['priority'] ?? 'medium') as String,
      createdAt: DateTime.parse(
        (json['created_at'] ?? DateTime.now().toIso8601String()) as String,
      ),
      updatedAt: DateTime.parse(
        (json['updated_at'] ?? DateTime.now().toIso8601String()) as String,
      ),
    );
  }
}

class GrievanceAttachmentModel {
  final String id;
  final String grievanceId;
  final String attachmentType;
  final String originalFilename;
  final String mimeType;
  final String storagePath;
  final int? fileSizeBytes;
  final String? rawExtractedText;
  final String extractionStatus;
  final double? extractionConfidence;
  final String? extractionEngine;
  final String? extractionError;
  final DateTime? extractedAt;
  final DateTime createdAt;

  const GrievanceAttachmentModel({
    required this.id,
    required this.grievanceId,
    required this.attachmentType,
    required this.originalFilename,
    required this.mimeType,
    required this.storagePath,
    this.fileSizeBytes,
    this.rawExtractedText,
    required this.extractionStatus,
    this.extractionConfidence,
    this.extractionEngine,
    this.extractionError,
    this.extractedAt,
    required this.createdAt,
  });

  factory GrievanceAttachmentModel.fromJson(Map<String, dynamic> json) {
    return GrievanceAttachmentModel(
      id: json['id'] as String,
      grievanceId: json['grievance_id'] as String,
      attachmentType: json['attachment_type'] as String,
      originalFilename: json['original_filename'] as String,
      mimeType: json['mime_type'] as String,
      storagePath: json['storage_path'] as String,
      fileSizeBytes: json['file_size_bytes'] as int?,
      rawExtractedText: json['raw_extracted_text'] as String?,
      extractionStatus: (json['extraction_status'] ?? 'pending') as String,
      extractionConfidence: (json['extraction_confidence'] as num?)?.toDouble(),
      extractionEngine: json['extraction_engine'] as String?,
      extractionError: json['extraction_error'] as String?,
      extractedAt: json['extracted_at'] != null
          ? DateTime.parse(json['extracted_at'] as String)
          : null,
      createdAt: DateTime.parse(
        (json['created_at'] ?? DateTime.now().toIso8601String()) as String,
      ),
    );
  }
}

class NormalizedExtractionResultModel {
  final String sourceType;
  final String? sourceAttachmentId;
  final String originalLanguage;
  final String? extractedText;
  final String extractionStatus;
  final double? confidenceScore;
  final String engineName;
  final DateTime processedAt;
  final String? errorMessage;

  const NormalizedExtractionResultModel({
    required this.sourceType,
    this.sourceAttachmentId,
    required this.originalLanguage,
    this.extractedText,
    required this.extractionStatus,
    this.confidenceScore,
    required this.engineName,
    required this.processedAt,
    this.errorMessage,
  });

  factory NormalizedExtractionResultModel.fromJson(Map<String, dynamic> json) {
    return NormalizedExtractionResultModel(
      sourceType: json['source_type'] as String,
      sourceAttachmentId: json['source_attachment_id'] as String?,
      originalLanguage: (json['original_language'] ?? 'ml') as String,
      extractedText: json['extracted_text'] as String?,
      extractionStatus: json['extraction_status'] as String,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
      engineName: json['engine_name'] as String,
      processedAt: DateTime.parse(
        (json['processed_at'] ?? DateTime.now().toIso8601String()) as String,
      ),
      errorMessage: json['error_message'] as String?,
    );
  }
}
