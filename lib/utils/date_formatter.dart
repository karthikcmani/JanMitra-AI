/// Utilities for parsing server UTC timestamps and formatting cleanly in IST (Indian Standard Time).
DateTime parseUtcToLocal(dynamic raw) {
  if (raw == null) return DateTime.now();
  if (raw is DateTime) {
    return raw.isUtc ? raw.toLocal() : raw;
  }
  String str = raw.toString().trim();
  if (str.isEmpty) return DateTime.now();

  // Standardize ISO-8601 string format
  if (str.contains(' ') && !str.contains('T')) {
    str = str.replaceFirst(' ', 'T');
  }

  // All server SQLite & PostgreSQL timestamps are created in UTC.
  // If timezone suffix (+00:00, +05:30, or Z) is absent, explicitly treat as UTC.
  if (!str.endsWith('Z') && !RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(str)) {
    str += 'Z';
  }

  final parsed = DateTime.tryParse(str) ?? DateTime.now();
  return parsed.toLocal();
}

/// Formats any DateTime accurately into Indian Standard Time (IST, UTC+5:30)
/// Example: `13/10/2026 07:43 PM IST`
String formatToIST(DateTime? dateTime, {bool includeSeconds = false}) {
  if (dateTime == null) return '';
  final local = dateTime.isUtc ? dateTime.toLocal() : dateTime;
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year;

  final hour24 = local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final hourStr = hour12.toString().padLeft(2, '0');

  if (includeSeconds) {
    final second = local.second.toString().padLeft(2, '0');
    return '$day/$month/$year $hourStr:$minute:$second $period IST';
  }
  return '$day/$month/$year $hourStr:$minute $period IST';
}
