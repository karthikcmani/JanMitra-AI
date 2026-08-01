import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_model.dart';
import '../models/complaint_model.dart';

class HiveService {
  static const String usersBoxName = 'janmitra_users_box';
  static const String complaintsBoxName = 'janmitra_complaints_box';
  static const String metaBoxName = 'janmitra_meta_box';
  static const String counterKey = 'complaint_counter';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<String>(usersBoxName);
    await Hive.openBox<String>(complaintsBoxName);
    await Hive.openBox<dynamic>(metaBoxName);
  }

  // --- USER OPERATIONS ---
  static Box<String> get _usersBox => Hive.box<String>(usersBoxName);

  static Future<bool> saveUser(UserModel user) async {
    final key = user.email.toLowerCase().trim();
    if (_usersBox.containsKey(key)) {
      return false; // Duplicate email
    }
    await _usersBox.put(key, jsonEncode(user.toJson()));
    return true;
  }

  static UserModel? getUser(String email) {
    final key = email.toLowerCase().trim();
    final data = _usersBox.get(key);
    if (data == null) return null;
    return UserModel.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }

  static bool userExists(String email) {
    final key = email.toLowerCase().trim();
    return _usersBox.containsKey(key);
  }

  // --- COMPLAINT OPERATIONS ---
  static Box<String> get _complaintsBox => Hive.box<String>(complaintsBoxName);
  static Box<dynamic> get _metaBox => Hive.box<dynamic>(metaBoxName);

  static String generateNextComplaintId() {
    final currentCounter =
        (_metaBox.get(counterKey, defaultValue: 0) as int) + 1;
    _metaBox.put(counterKey, currentCounter);
    final formattedCounter = currentCounter.toString().padLeft(6, '0');
    return 'JM-2026-$formattedCounter';
  }

  static Future<void> saveComplaint(ComplaintModel complaint) async {
    await _complaintsBox.put(complaint.id, jsonEncode(complaint.toJson()));
  }

  static List<ComplaintModel> getComplaintsForUser(String userEmail) {
    final emailClean = userEmail.toLowerCase().trim();
    final results = <ComplaintModel>[];
    for (var key in _complaintsBox.keys) {
      final raw = _complaintsBox.get(key);
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final complaint = ComplaintModel.fromJson(map);
        if (complaint.userEmail.toLowerCase().trim() == emailClean) {
          results.add(complaint);
        }
      }
    }
    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }

  static ComplaintModel? getComplaintById(String id) {
    final raw = _complaintsBox.get(id);
    if (raw == null) return null;
    return ComplaintModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<void> deleteComplaint(String id) async {
    await _complaintsBox.delete(id);
  }
}
