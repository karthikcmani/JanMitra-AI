import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/complaint_model.dart';
import '../repositories/complaint_repository.dart';
import 'auth_provider.dart';
import 'theme_provider.dart';

final complaintRepositoryProvider = Provider<ComplaintRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return ComplaintRepository(apiService);
});

class ComplaintState {
  final List<ComplaintModel> complaints;
  final bool isLoading;
  final String? errorMessage;
  final String selectedCategoryFilter;
  final String selectedStatusFilter;

  const ComplaintState({
    this.complaints = const [],
    this.isLoading = false,
    this.errorMessage,
    this.selectedCategoryFilter = 'All',
    this.selectedStatusFilter = 'All',
  });

  int get totalCount => complaints.length;
  int get pendingCount =>
      complaints.where((c) => c.status != 'Resolved').length;
  int get resolvedCount =>
      complaints.where((c) => c.status == 'Resolved').length;

  ComplaintState copyWith({
    List<ComplaintModel>? complaints,
    bool? isLoading,
    String? errorMessage,
    String? selectedCategoryFilter,
    String? selectedStatusFilter,
  }) {
    return ComplaintState(
      complaints: complaints ?? this.complaints,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      selectedCategoryFilter:
          selectedCategoryFilter ?? this.selectedCategoryFilter,
      selectedStatusFilter: selectedStatusFilter ?? this.selectedStatusFilter,
    );
  }
}

final complaintProvider =
    StateNotifierProvider<ComplaintNotifier, ComplaintState>((ref) {
      final repository = ref.watch(complaintRepositoryProvider);
      final authState = ref.watch(authProvider);
      return ComplaintNotifier(repository, authState.currentUser?.email);
    });

class ComplaintNotifier extends StateNotifier<ComplaintState> {
  final ComplaintRepository _repository;
  final String? _userEmail;

  ComplaintNotifier(this._repository, this._userEmail)
    : super(const ComplaintState()) {
    loadComplaints();
  }

  Future<void> loadComplaints() async {
    if (_userEmail == null || _userEmail.isEmpty) {
      state = state.copyWith(complaints: []);
      return;
    }
    state = state.copyWith(isLoading: true);
    final list = await _repository.getComplaintsForUser(_userEmail);
    state = state.copyWith(complaints: list, isLoading: false);
  }

  Future<ComplaintModel?> createComplaint({
    required String title,
    required String category,
    required String department,
    required String district,
    required String description,
    required String priority,
  }) async {
    if (_userEmail == null || _userEmail.isEmpty) return null;

    final newComplaint = await _repository.createComplaint(
      userEmail: _userEmail,
      title: title,
      category: category,
      department: department,
      district: district,
      description: description,
      priority: priority,
    );

    if (newComplaint != null) {
      await loadComplaints();
    }
    return newComplaint;
  }

  Future<void> updateComplaint(ComplaintModel complaint) async {
    await _repository.updateComplaint(complaint);
    await loadComplaints();
  }

  Future<void> updateStatus(String id, String newStatus) async {
    await _repository.updateStatus(id, newStatus);
    await loadComplaints();
  }

  Future<void> deleteComplaint(String id) async {
    await _repository.deleteComplaint(id);
    await loadComplaints();
  }

  void setCategoryFilter(String category) {
    state = state.copyWith(selectedCategoryFilter: category);
  }

  void setStatusFilter(String status) {
    state = state.copyWith(selectedStatusFilter: status);
  }
}
