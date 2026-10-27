import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/khosra_entry.dart';

File _cacheFile() => File('${Directory.systemTemp.path}/mcs_khosra_entries_v1.json');

dynamic _jsonSafe(dynamic value) {
  if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
  if (value is DateTime) return value.toUtc().toIso8601String();
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), _jsonSafe(v)));
  }
  if (value is Iterable) {
    return value.map(_jsonSafe).toList();
  }
  return value;
}

Future<List<KhosraEntry>> loadLocalKhosraEntries() async {
  try {
    final file = _cacheFile();
    if (!await file.exists()) return const [];
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((m) => KhosraEntry.fromMap(Map<String, dynamic>.from(m), hasPendingWrites: true))
        .toList();
  } catch (_) {
    return const [];
  }
}

Future<void> saveLocalKhosraEntries(Iterable<KhosraEntry> entries) async {
  try {
    final file = _cacheFile();
    final payload = entries.map((e) => _jsonSafe(e.toMap())).toList();
    await file.writeAsString(jsonEncode(payload), flush: true);
  } catch (_) {}
}

