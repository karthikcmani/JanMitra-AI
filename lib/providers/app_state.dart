import 'package:flutter/material.dart';
import '../models/grievance.dart';
import '../models/department.dart';
import '../models/chat_message.dart';
import '../services/mock_data_service.dart';

enum UserRole { citizen, admin }

class AppState extends ChangeNotifier {
  bool _isDarkMode = true;
  UserRole _userRole = UserRole.citizen;

  List<Grievance> _grievances = [];
  List<DepartmentMetric> _departmentMetrics = [];
  List<ChatMessage> _chatMessages = [];

  GrievanceCategory? _categoryFilter;
  GrievanceStatus? _statusFilter;
  String _searchQuery = '';

  Grievance? _selectedGrievance;

  bool get isDarkMode => _isDarkMode;
  UserRole get userRole => _userRole;
  List<Grievance> get grievances => _grievances;
  List<DepartmentMetric> get departmentMetrics => _departmentMetrics;
  List<ChatMessage> get chatMessages => _chatMessages;

  GrievanceCategory? get categoryFilter => _categoryFilter;
  GrievanceStatus? get statusFilter => _statusFilter;
  String get searchQuery => _searchQuery;
  Grievance? get selectedGrievance => _selectedGrievance;

  AppState() {
    _initData();
  }

  void _initData() {
    _grievances = MockDataService.getInitialGrievances();
    _departmentMetrics = MockDataService.getDepartmentMetrics();
    _chatMessages = MockDataService.getInitialChatMessages();
    if (_grievances.isNotEmpty) {
      _selectedGrievance = _grievances.first;
    }
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void switchUserRole(UserRole role) {
    _userRole = role;
    notifyListeners();
  }

  void setSelectedGrievance(Grievance g) {
    _selectedGrievance = g;
    notifyListeners();
  }

  void setCategoryFilter(GrievanceCategory? cat) {
    _categoryFilter = cat;
    notifyListeners();
  }

  void setStatusFilter(GrievanceStatus? st) {
    _statusFilter = st;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearFilters() {
    _categoryFilter = null;
    _statusFilter = null;
    _searchQuery = '';
    notifyListeners();
  }

  List<Grievance> get filteredGrievances {
    return _grievances.where((g) {
      if (_categoryFilter != null && g.category != _categoryFilter) {
        return false;
      }
      if (_statusFilter != null && g.status != _statusFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = g.title.toLowerCase().contains(q);
        final matchDesc = g.description.toLowerCase().contains(q);
        final matchId = g.id.toLowerCase().contains(q);
        final matchLoc = g.location.toLowerCase().contains(q);
        final matchWard = g.ward.toLowerCase().contains(q);
        return matchTitle || matchDesc || matchId || matchLoc || matchWard;
      }
      return true;
    }).toList();
  }

  // Dashboard Aggregates
  int get totalCount => _grievances.length;
  int get resolvedCount => _grievances.where((g) => g.status == GrievanceStatus.resolved).toList().length;
  int get inProgressCount => _grievances.where((g) => g.status == GrievanceStatus.inProgress || g.status == GrievanceStatus.underReview).toList().length;
  int get escalatedCount => _grievances.where((g) => g.status == GrievanceStatus.escalated).toList().length;

  double get overallSlaCompliance {
    if (_departmentMetrics.isEmpty) return 92.5;
    final total = _departmentMetrics.fold<double>(0.0, (sum, item) => sum + item.slaCompliancePercent);
    return total / _departmentMetrics.length;
  }

  void upvoteGrievance(String id) {
    final index = _grievances.indexWhere((g) => g.id == id);
    if (index != -1) {
      _grievances[index].upvotes += 1;
      notifyListeners();
    }
  }

  void updateGrievanceStatus(String id, GrievanceStatus newStatus, {String? officerNote}) {
    final index = _grievances.indexWhere((g) => g.id == id);
    if (index != -1) {
      final g = _grievances[index];
      g.status = newStatus;

      if (newStatus == GrievanceStatus.resolved) {
        g.resolvedAt = DateTime.now();
      }

      g.timeline.add(
        TimelineStep(
          title: 'Status Updated: ${newStatus.label}',
          timestamp: 'Just Now',
          description: officerNote ?? 'Updated by administrative authority.',
          isCompleted: true,
          actor: _userRole == UserRole.admin ? 'Administrative Lead' : 'System Agent',
        ),
      );

      if (_selectedGrievance?.id == id) {
        _selectedGrievance = g;
      }

      notifyListeners();
    }
  }

  void fileNewGrievance({
    required String title,
    required String description,
    required GrievanceCategory category,
    required String location,
    required String ward,
    required int urgencyScore,
    required GrievancePriority priority,
    required String aiAction,
    String? similarityAlert,
  }) {
    final newId = 'JM-2026-${8900 + _grievances.length}';
    final now = DateTime.now();

    final newGrievance = Grievance(
      id: newId,
      title: title,
      description: description,
      category: category,
      priority: priority,
      status: GrievanceStatus.underReview,
      urgencyScore: urgencyScore,
      location: location,
      ward: ward,
      duplicateCount: similarityAlert != null ? 3 : 1,
      filedAt: now,
      assignedOfficer: 'JanMitra Automated Triage Engine',
      aiActionRecommendation: aiAction,
      sentiment: urgencyScore > 80 ? 'High Public Concern' : 'Moderate Priority',
      similarityAlert: similarityAlert,
      upvotes: 1,
      timeline: [
        TimelineStep(
          title: 'Grievance Filed',
          timestamp: 'Just Now',
          description: 'Logged into JanMitra AI Platform.',
          isCompleted: true,
          actor: 'Citizen',
        ),
        TimelineStep(
          title: 'AI Priority & Triage',
          timestamp: 'Just Now',
          description: 'Assigned Urgency Score $urgencyScore%. Category verified.',
          isCompleted: true,
          actor: 'JanMitra AI Core',
        ),
        TimelineStep(
          title: 'Officer Allocation',
          timestamp: 'In Progress',
          description: 'Routing to department executive lead.',
          isCompleted: false,
        ),
      ],
    );

    _grievances.insert(0, newGrievance);
    _selectedGrievance = newGrievance;
    notifyListeners();
  }

  void sendChatMessage(String text) {
    if (text.trim().isEmpty) return;

    final userMsg = ChatMessage(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    _chatMessages.add(userMsg);
    notifyListeners();

    // Generate AI response simulation
    Future.delayed(const Duration(milliseconds: 600), () {
      final replyText = _generateAiReply(text);
      final aiMsg = ChatMessage(
        id: 'msg-ai-${DateTime.now().millisecondsSinceEpoch}',
        text: replyText,
        isUser: false,
        timestamp: DateTime.now(),
        suggestedActions: [
          'Track JM-2026-8891',
          'File Water Supply issue',
          'View Ward 12 Analytics',
        ],
      );
      _chatMessages.add(aiMsg);
      notifyListeners();
    });
  }

  String _generateAiReply(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('status') || lower.contains('8891')) {
      return 'Grievance **JM-2026-8891** (Pipe Burst in Sector 4) has been escalated to P1 Urgent. The Executive Engineer Water Works has dispatched field team Alpha. SLA target resolution is expected by 12:00 PM today.';
    } else if (lower.contains('water') || lower.contains('leak') || lower.contains('supply')) {
      return 'I noticed you mentioned a Water Supply issue. Would you like me to pre-fill a P1 Water Supply Grievance form for your ward with automated AI triage?';
    } else if (lower.contains('road') || lower.contains('pothole')) {
      return 'Road & PWD grievances in your region are currently averaging an 88.8% SLA resolution rate. You can lodge a new road repair request using the "File Grievance" tab.';
    } else if (lower.contains('heatmap') || lower.contains('analytics') || lower.contains('ward')) {
      return 'Based on current AI spatial clustering, **Ward 12 (Central Zone)** has the highest active complaint density (14 reports) due to the main pipeline repair.';
    } else {
      return 'Thank you for reaching out to JanMitra AI. I can assist you with filing grievances, tracking status by ID, analyzing ward bottleneck trends, or fetching department contact info.';
    }
  }
}
