import '../models/complaint_model.dart';
import '../services/hive_service.dart';

class ComplaintRepository {
  Future<ComplaintModel> createComplaint({
    required String userEmail,
    required String title,
    required String category,
    required String department,
    required String district,
    required String description,
    required String priority,
  }) async {
    final complaintId = HiveService.generateNextComplaintId();
    final now = DateTime.now();

    final complaint = ComplaintModel(
      id: complaintId,
      userEmail: userEmail,
      title: title.trim(),
      category: category,
      department: department,
      district: district,
      description: description.trim(),
      priority: priority,
      status: 'Submitted',
      createdAt: now,
      updatedAt: now,
    );

    await HiveService.saveComplaint(complaint);
    return complaint;
  }

  List<ComplaintModel> getComplaintsForUser(String userEmail) {
    return HiveService.getComplaintsForUser(userEmail);
  }

  ComplaintModel? getComplaintById(String id) {
    return HiveService.getComplaintById(id);
  }

  Future<ComplaintModel?> updateComplaint(ComplaintModel complaint) async {
    final updated = complaint.copyWith(updatedAt: DateTime.now());
    await HiveService.saveComplaint(updated);
    return updated;
  }

  Future<ComplaintModel?> updateStatus(String id, String newStatus) async {
    final existing = HiveService.getComplaintById(id);
    if (existing == null) return null;
    final updated = existing.copyWith(
      status: newStatus,
      updatedAt: DateTime.now(),
    );
    await HiveService.saveComplaint(updated);
    return updated;
  }

  Future<void> deleteComplaint(String id) async {
    await HiveService.deleteComplaint(id);
  }
}
