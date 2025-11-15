import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class StorageService {
  static const String _medicationsKey = 'medications_v1';
  static const String _historyKey = 'history_v1';

  Future<List<Medication>> loadMedications() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_medicationsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(Medication.fromJson).toList(growable: true);
  }

  Future<void> saveMedications(List<Medication> items) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_medicationsKey, encoded);
  }

  Future<List<ReminderLogEntry>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(ReminderLogEntry.fromJson).toList(growable: true);
  }

  Future<void> appendHistory(ReminderLogEntry entry) async {
    final current = await loadHistory();
    current.add(entry);
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(current.map((e) => e.toJson()).toList());
    await prefs.setString(_historyKey, encoded);
  }
}



