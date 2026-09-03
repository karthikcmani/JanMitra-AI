import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/grievance_model.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';


class OfficialDashboardSummaryModel {
  final int totalGrievances;
  final int pending;
  final int underProcessing;
  final int clarificationRequired;
  final int forwarded;
  final int resolved;
  final int highPriority;
  final int todayReceived;
  final List<GrievanceModel> recentGrievances;

  const OfficialDashboardSummaryModel({
    required this.totalGrievances,
    required this.pending,
    required this.underProcessing,
    required this.clarificationRequired,
    required this.forwarded,
    required this.resolved,
    required this.highPriority,
    required this.todayReceived,
    required this.recentGrievances,
  });

  factory OfficialDashboardSummaryModel.fromJson(Map<String, dynamic> json) {
    var rawRecent = json['recent_grievances'] as List<dynamic>?;
    List<GrievanceModel> recent = rawRecent != null
        ? rawRecent.map((item) => GrievanceModel.fromJson(item as Map<String, dynamic>)).toList()
        : [];

    return OfficialDashboardSummaryModel(
      totalGrievances: (json['total_grievances'] as num?)?.toInt() ?? 0,
      pending: (json['pending'] as num?)?.toInt() ?? 0,
      underProcessing: (json['under_processing'] as num?)?.toInt() ?? 0,
      clarificationRequired: (json['clarification_required'] as num?)?.toInt() ?? 0,
      forwarded: (json['forwarded'] as num?)?.toInt() ?? 0,
      resolved: (json['resolved'] as num?)?.toInt() ?? 0,
      highPriority: (json['high_priority'] as num?)?.toInt() ?? 0,
      todayReceived: (json['today_received'] as num?)?.toInt() ?? 0,
      recentGrievances: recent,
    );
  }
}

class DepartmentWorkloadModel {
  final String departmentName;
  final int pending;
  final int underProcessing;
  final int clarificationRequired;
  final int forwarded;
  final int resolved;
  final int total;

  const DepartmentWorkloadModel({
    required this.departmentName,
    required this.pending,
    required this.underProcessing,
    required this.clarificationRequired,
    required this.forwarded,
    required this.resolved,
    required this.total,
  });

  factory DepartmentWorkloadModel.fromJson(Map<String, dynamic> json) {
    return DepartmentWorkloadModel(
      departmentName: (json['department_name'] ?? '').toString(),
      pending: (json['pending'] as num?)?.toInt() ?? 0,
      underProcessing: (json['under_processing'] as num?)?.toInt() ?? 0,
      clarificationRequired: (json['clarification_required'] as num?)?.toInt() ?? 0,
      forwarded: (json['forwarded'] as num?)?.toInt() ?? 0,
      resolved: (json['resolved'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

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

class OfficialRepository {
  final ApiService apiService;

  OfficialRepository(this.apiService);

  Future<OfficialDashboardSummaryModel> getDashboardSummary() async {
    final response = await apiService.get('/official/dashboard/summary');
    return OfficialDashboardSummaryModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<GrievanceModel>> searchGrievances({
    String? query,
    String? status,
    String? priority,
    String? departmentId,
    String? category,
  }) async {
    final queryParams = <String, dynamic>{};
    if (query != null && query.isNotEmpty) queryParams['query'] = query;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (priority != null && priority.isNotEmpty) queryParams['priority'] = priority;
    if (departmentId != null && departmentId.isNotEmpty) queryParams['department_id'] = departmentId;
    if (category != null && category.isNotEmpty) queryParams['category'] = category;

    final response = await apiService.get('/official/grievances/search', queryParameters: queryParams);
    final list = response.data as List<dynamic>;
    return list.map((j) => GrievanceModel.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<GrievanceModel>> getAttentionQueue() async {
    final response = await apiService.get('/official/grievances/attention-queue');
    final list = response.data as List<dynamic>;
    return list.map((j) => GrievanceModel.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<DepartmentWorkloadModel>> getDepartmentWorkload() async {
    final response = await apiService.get('/official/admin/department-workload');
    final list = response.data as List<dynamic>;
    return list.map((j) => DepartmentWorkloadModel.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<GrievanceModel> submitAction({
    required String grievanceId,
    String? departmentName,
    String? newStatus,
    String? remarks,
    String? question,
  }) async {
    final payload = <String, dynamic>{};
    if (departmentName != null) payload['department_name'] = departmentName;
    if (newStatus != null) payload['new_status'] = newStatus;
    if (remarks != null) payload['remarks'] = remarks;
    if (question != null) payload['question'] = question;

    final response = await apiService.post(
      '/official/grievances/$grievanceId/action',
      data: payload,
    );

    return GrievanceModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> getOfficialUsers() async {
    final response = await apiService.get('/official/admin/officials');
    final list = response.data as List<dynamic>;
    return list.map((j) => Map<String, dynamic>.from(j as Map)).toList();
  }

  Future<Map<String, dynamic>> updateOfficialUser({
    required String userId,
    bool? isActive,
    String? departmentId,
  }) async {
    final payload = <String, dynamic>{};
    if (isActive != null) payload['is_active'] = isActive;
    if (departmentId != null) payload['department_id'] = departmentId;

    final response = await apiService.put(
      '/official/admin/users/$userId',
      data: payload,
    );

    return Map<String, dynamic>.from(response.data as Map);
  }
}

final officialRepositoryProvider = Provider<OfficialRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return OfficialRepository(apiService);
});

final officialSummaryProvider = FutureProvider.autoDispose<OfficialDashboardSummaryModel>((ref) async {
  final repo = ref.watch(officialRepositoryProvider);
  return await repo.getDashboardSummary();
});

final attentionQueueProvider = FutureProvider.autoDispose<List<GrievanceModel>>((ref) async {
  final repo = ref.watch(officialRepositoryProvider);
  return await repo.getAttentionQueue();
});

final departmentWorkloadProvider = FutureProvider.autoDispose<List<DepartmentWorkloadModel>>((ref) async {
  final repo = ref.watch(officialRepositoryProvider);
  return await repo.getDepartmentWorkload();
});

final officialUsersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(officialRepositoryProvider);
  return await repo.getOfficialUsers();
});
