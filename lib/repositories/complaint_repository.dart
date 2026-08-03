import '../models/complaint_model.dart';
import '../services/api_service.dart';

class ComplaintRepository {
  final ApiService apiService;

  // Temporary In-Memory Mock Complaints for Phase 1 UI Development
  static final List<ComplaintModel> _mockComplaints = [
    ComplaintModel(
      id: 'JM-2026-000001',
      userEmail: 'citizen@gov.in',
      title: 'Water Supply Disruption in Block C',
      category: 'Water Supply',
      department: 'Municipal Water Board',
      district: 'Central District',
      description:
          'Clean drinking water supply has been disrupted for over 48 hours in Ward 12, Block C.',
      priority: 'High',
      status: 'Verification',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    ComplaintModel(
      id: 'JM-2026-000002',
      userEmail: 'citizen@gov.in',
      title: 'Potholes on Main Sector Road',
      category: 'Road Maintenance',
      department: 'Public Works Department',
      district: 'North District',
      description:
          'Dangerous potholes causing traffic congestion and accidents near Metro Station Gate 2.',
      priority: 'Medium',
      status: 'Submitted',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  static int _nextIdCounter = 3;

  ComplaintRepository(this.apiService);

  Future<ComplaintModel?> createComplaint({
    required String userEmail,
    required String title,
    required String category,
    required String department,
    required String district,
    required String description,
    required String priority,
  }) async {
    final idString = 'JM-2026-${_nextIdCounter.toString().padLeft(6, '0')}';
    _nextIdCounter++;

    final now = DateTime.now();
    final newComplaint = ComplaintModel(
      id: idString,
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

    _mockComplaints.insert(0, newComplaint);
    return newComplaint;
  }

  Future<List<ComplaintModel>> getComplaintsForUser(String userEmail) async {
    return _mockComplaints
        .where(
          (c) =>
              c.userEmail.toLowerCase() == userEmail.toLowerCase() ||
              userEmail.isEmpty,
        )
        .toList();
  }

  Future<ComplaintModel?> getComplaintById(String id) async {
    return _mockComplaints.where((c) => c.id == id).firstOrNull;
  }

  Future<ComplaintModel?> updateComplaint(ComplaintModel complaint) async {
    final index = _mockComplaints.indexWhere((c) => c.id == complaint.id);
    if (index != -1) {
      _mockComplaints[index] = complaint.copyWith(updatedAt: DateTime.now());
      return _mockComplaints[index];
    }
    return complaint;
  }

  Future<ComplaintModel?> updateStatus(String id, String newStatus) async {
    final index = _mockComplaints.indexWhere((c) => c.id == id);
    if (index != -1) {
      _mockComplaints[index] = _mockComplaints[index].copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      );
      return _mockComplaints[index];
    }
    return null;
  }

  Future<bool> deleteComplaint(String id) async {
    final initialLength = _mockComplaints.length;
    _mockComplaints.removeWhere((c) => c.id == id);
    return _mockComplaints.length < initialLength;
  }
}
