import 'package:cloud_firestore/cloud_firestore.dart';

/// Defensive JSON casting helpers.
///
/// Firestore / Express payloads do not always preserve Dart primitive types:
/// numbers can arrive as `double`, `int`, or `String` and booleans can arrive
/// as `int` (0/1) from some serializers. Blindly casting with `as int` throws
/// a runtime `TypeError` that crashes the screen. Every model in EduBoard
/// parses through these helpers so a malformed remote field can never take the
/// app down.

int asIntOr(dynamic value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null) return parsed;
    final dbl = double.tryParse(value.trim());
    if (dbl != null) return dbl.round();
  }
  if (value is bool) return value ? 1 : 0;
  return fallback;
}

double asDoubleOr(dynamic value, double fallback) {
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value.trim());
    if (parsed != null) return parsed;
  }
  return fallback;
}

bool asBoolOr(dynamic value, bool fallback) {
  if (value is bool) return value;
  if (value is int) return value != 0;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.trim().toLowerCase();
    if (v == 'true' || v == '1' || v == 'yes') return true;
    if (v == 'false' || v == '0' || v == 'no' || v == '') return false;
  }
  return fallback;
}

String asStringOr(dynamic value, String fallback) {
  if (value == null) return fallback;
  if (value is String) return value;
  if (value is num || value is bool) return value.toString();
  return fallback;
}

DateTime asDateOr(dynamic value, DateTime fallback) {
  if (value == null) return fallback;
  if (value is DateTime) return value;
  // Firestore `Timestamp` objects are returned raw inside doc.data() maps.
  // Calling toString() on them yields "Timestamp(seconds=...)" which
  // DateTime.tryParse cannot read — decode them properly here.
  if (value is Timestamp) return value.toDate();
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.round());
  }
  final str = value.toString().trim();
  if (str.isEmpty) return fallback;
  return DateTime.tryParse(str) ?? fallback;
}
