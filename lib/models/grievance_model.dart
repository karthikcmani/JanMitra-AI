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

class GrievanceIssueModel {
  final String id;
  final String grievanceId;
  final int issueNumber;
  final String title;
  final String? description;
  final String category;
  final String? subcategory;
  final String severity;
  final String priority;
  final String status;
  final Map<String, dynamic>? extractedFacts;
  final String interviewStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GrievanceIssueModel({
    required this.id,
    required this.grievanceId,
    required this.issueNumber,
    required this.title,
    this.description,
    required this.category,
    this.subcategory,
    required this.severity,
    required this.priority,
    required this.status,
    this.extractedFacts,
    required this.interviewStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GrievanceIssueModel.fromJson(Map<String, dynamic> json) {
    return GrievanceIssueModel(
      id: (json['id'] ?? '').toString(),
      grievanceId: (json['grievance_id'] ?? '').toString(),
      issueNumber: (json['issue_number'] as num?)?.toInt() ?? 1,
      title: (json['title'] ?? 'Reported Issue').toString(),
      description: json['description']?.toString(),
      category: (json['category'] ?? 'General').toString(),
      subcategory: json['subcategory']?.toString(),
      severity: (json['severity'] ?? 'MEDIUM').toString(),
      priority: (json['priority'] ?? 'MEDIUM').toString(),
      status: (json['status'] ?? 'OPEN').toString(),
      extractedFacts: json['extracted_facts'] is Map<String, dynamic>
          ? json['extracted_facts'] as Map<String, dynamic>
          : null,
      interviewStatus: (json['interview_status'] ?? 'not_required').toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class GrievanceInterviewQuestionModel {
  final String id;
  final String grievanceId;
  final String? issueId;
  final String question;
  final String questionType;
  final bool required;
  final int orderIndex;
  final String status;
  final DateTime createdAt;

  const GrievanceInterviewQuestionModel({
    required this.id,
    required this.grievanceId,
    this.issueId,
    required this.question,
    required this.questionType,
    required this.required,
    required this.orderIndex,
    required this.status,
    required this.createdAt,
  });

  factory GrievanceInterviewQuestionModel.fromJson(Map<String, dynamic> json) {
    return GrievanceInterviewQuestionModel(
      id: (json['id'] ?? '').toString(),
      grievanceId: (json['grievance_id'] ?? '').toString(),
      issueId: json['issue_id']?.toString(),
      question: (json['question'] ?? '').toString(),
      questionType: (json['question_type'] ?? 'TEXT').toString(),
      required: json['required'] as bool? ?? true,
      orderIndex: (json['order_index'] as num?)?.toInt() ?? 1,
      status: (json['status'] ?? 'PENDING').toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
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
  final String? severity;
  final String? summary;
  final String? aiProcessingStatus;
  final DateTime? aiProcessedAt;
  final String? aiModel;
  final String? aiErrorMessage;
  final String? category;
  final String? departmentId;
  final String? citizenName;
  final String? citizenPhone;
  final String? rawOcrText;
  final String? predictedDepartment;
  final String? assignedDepartment;
  final String? aiExplanation;
  final AIDecisionSupportModel? decisionSupport;
  final List<GrievanceAttachmentModel> attachments;
  final List<GrievanceAuditLogModel> auditLogs;
  final List<GrievanceIssueModel> issues;
  final List<GrievanceInterviewQuestionModel> interviewQuestions;
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
    this.severity,
    this.summary,
    this.aiProcessingStatus,
    this.aiProcessedAt,
    this.aiModel,
    this.aiErrorMessage,
    this.category,
    this.departmentId,
    this.rawOcrText,
    this.predictedDepartment,
    this.assignedDepartment,
    this.aiExplanation,
    this.decisionSupport,
    this.attachments = const [],
    this.auditLogs = const [],
    this.issues = const [],
    this.interviewQuestions = const [],
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

    var rawAtts = json['attachments'] as List<dynamic>?;
    List<GrievanceAttachmentModel> parsedAtts = rawAtts != null
        ? rawAtts
            .map((item) =>
                GrievanceAttachmentModel.fromJson(item as Map<String, dynamic>))
            .toList()
        : [];

    var rawIssues = json['issues'] as List<dynamic>?;
    List<GrievanceIssueModel> parsedIssues = rawIssues != null
        ? rawIssues
            .map((item) =>
                GrievanceIssueModel.fromJson(item as Map<String, dynamic>))
            .toList()
        : [];

    var rawQuestions = json['interview_questions'] as List<dynamic>?;
    List<GrievanceInterviewQuestionModel> parsedQuestions = rawQuestions != null
        ? rawQuestions
            .map((item) =>
                GrievanceInterviewQuestionModel.fromJson(item as Map<String, dynamic>))
            .toList()
        : [];

    AIDecisionSupportModel? ds;
    if (json['decision_support'] != null && json['decision_support'] is Map<String, dynamic>) {
      ds = AIDecisionSupportModel.fromJson(json['decision_support'] as Map<String, dynamic>);
    }

    return GrievanceModel(
      id: (json['id'] ?? '').toString(),
      grievanceNumber: (json['grievance_number'] ?? json['id'] ?? '').toString(),
      citizenId: (json['citizen_id'] ?? '').toString(),
      citizenName: json['citizen_name']?.toString(),
      citizenPhone: json['citizen_phone']?.toString(),
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      intakeMode: (json['intake_mode'] ?? 'direct_text').toString(),
      originalLanguage: (json['original_language'] ?? 'ml').toString(),
      originalText: json['original_text']?.toString(),
      translatedText: json['translated_text']?.toString(),
      status: (json['status'] ?? 'draft').toString(),
      priority: (json['priority'] ?? 'medium').toString(),
      severity: json['severity']?.toString(),
      summary: json['summary']?.toString(),
      aiProcessingStatus: json['ai_processing_status']?.toString(),
      aiProcessedAt: json['ai_processed_at'] != null ? DateTime.tryParse(json['ai_processed_at'].toString()) : null,
      aiModel: json['ai_model']?.toString(),
      aiErrorMessage: json['ai_error_message']?.toString(),
      category: json['category']?.toString(),
      departmentId: (json['department_id'] ?? json['assigned_department'] ?? json['predicted_department'])?.toString(),
      rawOcrText: json['raw_ocr_text']?.toString(),
      predictedDepartment: json['predicted_department']?.toString(),
      assignedDepartment: json['assigned_department']?.toString(),
      aiExplanation: json['ai_explanation']?.toString(),
      decisionSupport: ds,
      attachments: parsedAtts,
      auditLogs: parsedLogs,
      issues: parsedIssues,
      interviewQuestions: parsedQuestions,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
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

    return 'Public Grievance Petition #${grievanceNumber.substring(0, grievanceNumber.length > 8 ? 8 : grievanceNumber.length)}';
  }

  /// Returns a short briefing / summary snippet for UI list cards.
  String? getShortBriefing() {
    if (summary != null && summary!.isNotEmpty) {
      return summary;
    }
    final text = description ?? originalText ?? rawOcrText;
    if (text != null && text.trim().isNotEmpty) {
      final clean = text.trim();
      return clean.length > 120 ? '${clean.substring(0, 120)}...' : clean;
    }
    return null;
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
      id: (json['id'] ?? '').toString(),
      grievanceId: (json['grievance_id'] ?? '').toString(),
      actorId: json['actor_id']?.toString(),
      actorRole: (json['actor_role'] ?? 'citizen').toString(),
      actionType: (json['action_type'] ?? '').toString(),
      previousState: json['previous_state']?.toString(),
      newState: json['new_state']?.toString(),
      remarks: json['remarks']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
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
      id: (json['id'] ?? '').toString(),
      grievanceId: (json['grievance_id'] ?? '').toString(),
      attachmentType: (json['attachment_type'] ?? '').toString(),
      originalFilename: (json['original_filename'] ?? '').toString(),
      mimeType: (json['mime_type'] ?? '').toString(),
      storagePath: (json['storage_path'] ?? '').toString(),
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt(),
      rawExtractedText: json['raw_extracted_text']?.toString(),
      extractionStatus: (json['extraction_status'] ?? 'pending').toString(),
      extractionConfidence: (json['extraction_confidence'] as num?)?.toDouble(),
      extractionEngine: json['extraction_engine']?.toString(),
      extractionError: json['extraction_error']?.toString(),
      extractedAt: json['extracted_at'] != null
          ? DateTime.tryParse(json['extracted_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
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
      sourceType: (json['source_type'] ?? '').toString(),
      sourceAttachmentId: json['source_attachment_id']?.toString(),
      originalLanguage: (json['original_language'] ?? 'ml').toString(),
      extractedText: json['extracted_text']?.toString(),
      extractionStatus: (json['extraction_status'] ?? '').toString(),
      confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
      engineName: (json['engine_name'] ?? '').toString(),
      processedAt: json['processed_at'] != null
          ? DateTime.tryParse(json['processed_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      errorMessage: json['error_message']?.toString(),
    );
  }
}
