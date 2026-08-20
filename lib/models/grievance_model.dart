class AIDecisionSupportModel {

  final String suggestedDepartment;
  final String priority;
  final String reasoning;
  final List<String> keyFacts;
  final String statutoryRelevance;
  final String missingInformation;
  final String suggestedNextStep;
  final double confidenceScore;
  final String disclaimer;

  const AIDecisionSupportModel({
    required this.suggestedDepartment,
    required this.priority,
    required this.reasoning,
    required this.keyFacts,
    required this.statutoryRelevance,
    required this.missingInformation,
    required this.suggestedNextStep,
    required this.confidenceScore,
    required this.disclaimer,
  });

  factory AIDecisionSupportModel.fromJson(Map<String, dynamic> json) {
    var rawFacts = json['key_facts'] as List<dynamic>?;
    List<String> facts = rawFacts != null ? rawFacts.map((e) => e.toString()).toList() : [];

    return AIDecisionSupportModel(
      suggestedDepartment: (json['suggested_department'] ?? '') as String,
      priority: (json['priority'] ?? 'medium') as String,
      reasoning: (json['reasoning'] ?? '') as String,
      keyFacts: facts,
      statutoryRelevance: (json['statutory_relevance'] ?? '') as String,
      missingInformation: (json['missing_information'] ?? '') as String,
      suggestedNextStep: (json['suggested_next_step'] ?? '') as String,
      confidenceScore: ((json['confidence_score'] ?? 0.85) as num).toDouble(),
      disclaimer: (json['disclaimer'] ?? 'AI-assisted recommendation.') as String,
    );
  }
}

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
  final String? category;
  final String? departmentId;
  final String? citizenName;
  final String? citizenPhone;
  final String? rawOcrText;
  final String? predictedDepartment;
  final String? assignedDepartment;
  final String? aiExplanation;
  final AIDecisionSupportModel? decisionSupport;
  final List<GrievanceAuditLogModel> auditLogs;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GrievanceModel({
    required this.id,
    required this.grievanceNumber,
    required this.citizenId,
    this.citizenName,
    this.citizenPhone,
    this.title,
    this.description,
    required this.intakeMode,
    required this.originalLanguage,
    this.originalText,
    this.translatedText,
    required this.status,
    required this.priority,
    this.category,
    this.departmentId,
    this.rawOcrText,
    this.predictedDepartment,
    this.assignedDepartment,
    this.aiExplanation,
    this.decisionSupport,
    this.auditLogs = const [],
    required this.createdAt,
    required this.updatedAt,
  });


  factory GrievanceModel.fromJson(Map<String, dynamic> json) {
    var rawLogs = json['audit_logs'] as List<dynamic>?;
    List<GrievanceAuditLogModel> parsedLogs = rawLogs != null
        ? rawLogs
            .map((item) =>
                GrievanceAuditLogModel.fromJson(item as Map<String, dynamic>))
            .toList()
        : [];

    AIDecisionSupportModel? ds;
    if (json['decision_support'] != null && json['decision_support'] is Map<String, dynamic>) {
      ds = AIDecisionSupportModel.fromJson(json['decision_support'] as Map<String, dynamic>);
    }

    return GrievanceModel(
      id: json['id'] as String,
      grievanceNumber: (json['grievance_number'] ?? json['id']) as String,
      citizenId: (json['citizen_id'] ?? '') as String,
      citizenName: json['citizen_name'] as String?,
      citizenPhone: json['citizen_phone'] as String?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      intakeMode: (json['intake_mode'] ?? 'direct_text') as String,
      originalLanguage: (json['original_language'] ?? 'ml') as String,
      originalText: json['original_text'] as String?,
      translatedText: json['translated_text'] as String?,
      status: (json['status'] ?? 'draft') as String,
      priority: (json['priority'] ?? 'medium') as String,
      category: json['category'] as String?,
      departmentId: json['department_id'] as String?,
      rawOcrText: json['raw_ocr_text'] as String?,
      predictedDepartment: json['predicted_department'] as String?,
      assignedDepartment: json['assigned_department'] as String?,
      aiExplanation: json['ai_explanation'] as String?,
      decisionSupport: ds,
      auditLogs: parsedLogs,
      createdAt: DateTime.parse(
        (json['created_at'] ?? DateTime.now().toIso8601String()) as String,
      ),
      updatedAt: DateTime.parse(
        (json['updated_at'] ?? DateTime.now().toIso8601String()) as String,
      ),
    );
  }
  /// Returns a clean, human-readable title for the grievance.
  String getDisplayTitle() {
    if (title != null && title!.isNotEmpty && !title!.startsWith('Handwritten Petition Intake:')) {
      return title!;
    }

    final sourceText = description ?? originalText ?? rawOcrText;
    if (sourceText != null && sourceText.trim().isNotEmpty) {
      final clean = sourceText.trim();
      final lines = clean.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.toLowerCase().startsWith('വിഷയം:') || trimmed.toLowerCase().startsWith('subject:')) {
          final subjectPart = trimmed.substring(trimmed.indexOf(':') + 1).trim();
          if (subjectPart.isNotEmpty) {
            return subjectPart.length > 55 ? '${subjectPart.substring(0, 55)}...' : subjectPart;
          }
        }
      }
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty && !trimmed.toLowerCase().startsWith('പരാതി തീയതി')) {
          return trimmed.length > 55 ? '${trimmed.substring(0, 55)}...' : trimmed;
        }
      }
      return clean.length > 55 ? '${clean.substring(0, 55)}...' : clean;
    }

    if (title != null && title!.isNotEmpty) {
      return title!;
    }

    return 'Malayalam Petition Intake ($grievanceNumber)';
  }

  /// Returns a short briefing excerpt for previewing in cards and tracking dropdowns.
  String? getShortBriefing() {
    final text = description ?? originalText ?? rawOcrText;
    if (text == null || text.trim().isEmpty) return null;
    final clean = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    return clean.length > 110 ? '${clean.substring(0, 110)}...' : clean;
  }
}

class GrievanceAuditLogModel {
  final String id;
  final String grievanceId;
  final String? actorId;
  final String actorRole;
  final String actionType;
  final String? previousState;
  final String? newState;
  final String? remarks;
  final DateTime createdAt;

  const GrievanceAuditLogModel({
    required this.id,
    required this.grievanceId,
    this.actorId,
    required this.actorRole,
    required this.actionType,
    this.previousState,
    this.newState,
    this.remarks,
    required this.createdAt,
  });

  factory GrievanceAuditLogModel.fromJson(Map<String, dynamic> json) {
    return GrievanceAuditLogModel(
      id: json['id'] as String,
      grievanceId: json['grievance_id'] as String,
      actorId: json['actor_id'] as String?,
      actorRole: (json['actor_role'] ?? 'citizen') as String,
      actionType: (json['action_type'] ?? '') as String,
      previousState: json['previous_state'] as String?,
      newState: json['new_state'] as String?,
      remarks: json['remarks'] as String?,
      createdAt: DateTime.parse(
        (json['created_at'] ?? DateTime.now().toIso8601String()) as String,
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
