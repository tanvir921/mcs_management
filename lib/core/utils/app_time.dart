import 'package:cloud_firestore/cloud_firestore.dart';

class AppTime {
  AppTime._();

  static Duration _serverOffset = Duration.zero;
  static bool _hasSynced = false;

  // Business timezone offset from UTC (Bangladesh Standard Time).
  static const Duration businessOffset = Duration(hours: 6);

  static Future<void> sync() async {
    if (_hasSynced) return;

    final docRef = FirebaseFirestore.instance
        .collection('_meta')
        .doc('server_time');

    try {
      await docRef.set(
        {'ts': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      final snapshot = await docRef.get();
      final data = snapshot.data();
      final ts = data?['ts'] as Timestamp?;

      if (ts != null) {
        final serverUtc = ts.toDate().toUtc();
        final localUtc = DateTime.now().toUtc();
        _serverOffset = serverUtc.difference(localUtc);
        _hasSynced = true;
      }
    } catch (_) {
      // Keep zero offset on failure.
    }
  }

  static DateTime utcNow() {
    return DateTime.now().toUtc().add(_serverOffset);
  }

  // Returns business time as a UTC DateTime with business offset applied.
  static DateTime businessNow() {
    return utcNow().add(businessOffset);
  }

  // Convert a UTC timestamp to business time (UTC with offset applied).
  static DateTime toBusiness(DateTime utcDateTime) {
    final utc = utcDateTime.toUtc();
    return DateTime.utc(
      utc.year,
      utc.month,
      utc.day,
      utc.hour,
      utc.minute,
      utc.second,
      utc.millisecond,
      utc.microsecond,
    ).add(businessOffset);
  }

  // Convert a business time (UTC with offset applied) back to UTC.
  static DateTime toUtcFromBusiness(DateTime businessDateTime) {
    final utcLike = DateTime.utc(
      businessDateTime.year,
      businessDateTime.month,
      businessDateTime.day,
      businessDateTime.hour,
      businessDateTime.minute,
      businessDateTime.second,
      businessDateTime.millisecond,
      businessDateTime.microsecond,
    );
    return utcLike.subtract(businessOffset);
  }

  static DateTime startOfBusinessDayUtc(DateTime businessNow) {
    return DateTime.utc(
      businessNow.year,
      businessNow.month,
      businessNow.day,
    ).subtract(businessOffset);
  }

  static DateTime endOfBusinessDayUtc(DateTime businessNow) {
    return startOfBusinessDayUtc(businessNow)
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));
  }
}
