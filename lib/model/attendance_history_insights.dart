import 'attendance_model.dart';

enum AttendanceHistoryRange {
  today,
  yesterday,
  week,
  month,
  all,
}

extension AttendanceHistoryRangeLabel on AttendanceHistoryRange {
  String get label {
    switch (this) {
      case AttendanceHistoryRange.today:
        return 'Hoje';
      case AttendanceHistoryRange.yesterday:
        return 'Ontem';
      case AttendanceHistoryRange.week:
        return '7 dias';
      case AttendanceHistoryRange.month:
        return 'Mês';
      case AttendanceHistoryRange.all:
        return 'Tudo';
    }
  }
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime _normalizeDay(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

bool matchesAttendanceHistoryRange(
  DateTime date,
  AttendanceHistoryRange range, {
  DateTime? referenceDate,
}) {
  final reference = _normalizeDay(referenceDate ?? DateTime.now());
  final normalized = _normalizeDay(date);

  switch (range) {
    case AttendanceHistoryRange.today:
      return _isSameDay(normalized, reference);
    case AttendanceHistoryRange.yesterday:
      return _isSameDay(
          normalized, reference.subtract(const Duration(days: 1)));
    case AttendanceHistoryRange.week:
      final start = reference.subtract(const Duration(days: 6));
      return !normalized.isBefore(start) && !normalized.isAfter(reference);
    case AttendanceHistoryRange.month:
      final start = DateTime(reference.year, reference.month, 1);
      return !normalized.isBefore(start) && !normalized.isAfter(reference);
    case AttendanceHistoryRange.all:
      return true;
  }
}

List<AttendanceSheet> filterAttendanceHistory(
  List<AttendanceSheet> history,
  AttendanceHistoryRange range, {
  DateTime? referenceDate,
}) {
  final filtered = history
      .where(
        (sheet) => matchesAttendanceHistoryRange(
          sheet.date,
          range,
          referenceDate: referenceDate,
        ),
      )
      .toList(growable: false);

  filtered.sort((a, b) => b.date.compareTo(a.date));
  return filtered;
}

class AttendanceStudentInsight {
  final String studentId;
  final String studentName;
  final String? studentPhoto;
  final int totalClasses;
  final int presentCount;
  final int absentCount;
  final int justifiedAbsences;
  final int pendingAbsences;
  final int consecutiveAbsences;
  final List<DateTime> absenceDates;
  final DateTime? lastAttendanceDate;

  const AttendanceStudentInsight({
    required this.studentId,
    required this.studentName,
    this.studentPhoto,
    required this.totalClasses,
    required this.presentCount,
    required this.absentCount,
    required this.justifiedAbsences,
    required this.pendingAbsences,
    required this.consecutiveAbsences,
    required this.absenceDates,
    required this.lastAttendanceDate,
  });

  double get presenceRate =>
      totalClasses == 0 ? 0 : presentCount / totalClasses;

  String get label {
    if (totalClasses == 0) return 'Sem dados';
    if (consecutiveAbsences >= 3 || presenceRate < 0.70) {
      return 'Risco de ausência recorrente';
    }
    if (consecutiveAbsences >= 2 || presenceRate < 0.85 || absentCount >= 3) {
      return 'Atenção';
    }
    return 'Alta frequência';
  }

  bool get isAtRisk => label != 'Alta frequência';
}

class AttendanceHistorySummary {
  final AttendanceHistoryRange range;
  final List<AttendanceSheet> entries;
  final int totalCalls;
  final int totalPresent;
  final int totalAbsent;
  final double averagePresenceRate;
  final AttendanceSheet? latestEntry;
  final AttendanceSheet? yesterdayEntry;
  final List<AttendanceStudentInsight> studentInsights;

  const AttendanceHistorySummary({
    required this.range,
    required this.entries,
    required this.totalCalls,
    required this.totalPresent,
    required this.totalAbsent,
    required this.averagePresenceRate,
    required this.latestEntry,
    required this.yesterdayEntry,
    required this.studentInsights,
  });

  int get atRiskStudents =>
      studentInsights.where((student) => student.isAtRisk).length;
}

class _StudentAccumulator {
  final String studentId;
  String studentName;
  String? studentPhoto;
  int totalClasses = 0;
  int presentCount = 0;
  int absentCount = 0;
  int justifiedAbsences = 0;
  int pendingAbsences = 0;
  final List<DateTime> absenceDates = [];
  final List<bool> timeline = [];
  DateTime? lastAttendanceDate;

  _StudentAccumulator({
    required this.studentId,
    required this.studentName,
    this.studentPhoto,
  });

  void addRecord(AttendanceRecord record, DateTime date) {
    totalClasses += 1;
    timeline.add(record.isPresent);
    lastAttendanceDate ??= date;

    if (record.isPresent) {
      presentCount += 1;
    } else {
      absentCount += 1;
      absenceDates.add(date);

      switch (record.absenceState.toUpperCase()) {
        case 'APPROVED':
          justifiedAbsences += 1;
          break;
        case 'PENDING':
          pendingAbsences += 1;
          break;
      }
    }

    if (studentName.trim().isEmpty && record.studentName.trim().isNotEmpty) {
      studentName = record.studentName;
    }

    if ((studentPhoto == null || studentPhoto!.trim().isEmpty) &&
        record.studentPhoto != null &&
        record.studentPhoto!.trim().isNotEmpty) {
      studentPhoto = record.studentPhoto;
    }
  }

  int get consecutiveAbsences {
    var streak = 0;
    for (final isPresent in timeline) {
      if (isPresent) break;
      streak += 1;
    }
    return streak;
  }

  AttendanceStudentInsight toInsight() {
    absenceDates.sort((a, b) => b.compareTo(a));

    return AttendanceStudentInsight(
      studentId: studentId,
      studentName: studentName,
      studentPhoto: studentPhoto,
      totalClasses: totalClasses,
      presentCount: presentCount,
      absentCount: absentCount,
      justifiedAbsences: justifiedAbsences,
      pendingAbsences: pendingAbsences,
      consecutiveAbsences: consecutiveAbsences,
      absenceDates: List<DateTime>.from(absenceDates),
      lastAttendanceDate: lastAttendanceDate,
    );
  }
}

List<AttendanceStudentInsight> buildAttendanceStudentInsights(
  List<AttendanceSheet> entries,
) {
  final sortedEntries = List<AttendanceSheet>.from(entries)
    ..sort((a, b) => b.date.compareTo(a.date));

  final accumulators = <String, _StudentAccumulator>{};

  for (final sheet in sortedEntries) {
    for (final record in sheet.records) {
      if (record.studentId.trim().isEmpty) {
        continue;
      }

      final accumulator = accumulators.putIfAbsent(
        record.studentId,
        () => _StudentAccumulator(
          studentId: record.studentId,
          studentName: record.studentName,
          studentPhoto: record.studentPhoto,
        ),
      );

      accumulator.addRecord(record, sheet.date);
    }
  }

  final insights = accumulators.values
      .map((accumulator) => accumulator.toInsight())
      .toList();

  insights.sort((a, b) {
    final riskCompare = b.absentCount.compareTo(a.absentCount);
    if (riskCompare != 0) return riskCompare;

    final streakCompare =
        b.consecutiveAbsences.compareTo(a.consecutiveAbsences);
    if (streakCompare != 0) return streakCompare;

    final presenceCompare = a.presenceRate.compareTo(b.presenceRate);
    if (presenceCompare != 0) return presenceCompare;

    return a.studentName.toLowerCase().compareTo(b.studentName.toLowerCase());
  });

  return insights;
}

AttendanceHistorySummary buildAttendanceHistorySummary(
  List<AttendanceSheet> history,
  AttendanceHistoryRange range, {
  DateTime? referenceDate,
}) {
  final filtered = filterAttendanceHistory(
    history,
    range,
    referenceDate: referenceDate,
  );

  int totalPresent = 0;
  int totalAbsent = 0;

  for (final sheet in filtered) {
    totalPresent += sheet.presentCount;
    totalAbsent += sheet.absentCount;
  }

  final latestEntry = filtered.isEmpty ? null : filtered.first;
  final yesterdayReference = _normalizeDay(referenceDate ?? DateTime.now())
      .subtract(const Duration(days: 1));
  AttendanceSheet? yesterdayEntry;

  for (final sheet in filtered) {
    if (_isSameDay(sheet.date, yesterdayReference)) {
      yesterdayEntry = sheet;
      break;
    }
  }

  final studentInsights = buildAttendanceStudentInsights(filtered);
  final totalRecords = totalPresent + totalAbsent;
  final double averagePresenceRate =
      totalRecords == 0 ? 0.0 : totalPresent / totalRecords;

  return AttendanceHistorySummary(
    range: range,
    entries: filtered,
    totalCalls: filtered.length,
    totalPresent: totalPresent,
    totalAbsent: totalAbsent,
    averagePresenceRate: averagePresenceRate,
    latestEntry: latestEntry,
    yesterdayEntry: yesterdayEntry,
    studentInsights: studentInsights,
  );
}

String formatRelativeAttendanceDate(
  DateTime date, {
  DateTime? referenceDate,
}) {
  final reference = _normalizeDay(referenceDate ?? DateTime.now());
  final normalized = _normalizeDay(date);

  if (_isSameDay(normalized, reference)) {
    return 'Hoje';
  }

  if (_isSameDay(normalized, reference.subtract(const Duration(days: 1)))) {
    return 'Ontem';
  }

  final difference = reference.difference(normalized).inDays;
  if (difference > 1 && difference <= 6) {
    return 'Há $difference dias';
  }

  return '${normalized.day.toString().padLeft(2, '0')}/${normalized.month.toString().padLeft(2, '0')}';
}
