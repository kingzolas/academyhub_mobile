import 'package:academyhub_mobile/model/class_model.dart';
import 'package:academyhub_mobile/model/horario_model.dart';
import 'package:academyhub_mobile/model/subject_model.dart';
import 'package:academyhub_mobile/model/term_model.dart';
import 'package:academyhub_mobile/model/user_model.dart';
import 'package:academyhub_mobile/config/api_config.dart';
import 'package:academyhub_mobile/providers/academic_calendar_provider.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/providers/class_provider.dart';
import 'package:academyhub_mobile/providers/horario_provider.dart';
import 'package:flutter/foundation.dart';

class TeacherClassSuggestion {
  final ClassModel classData;
  final HorarioModel? schedule;

  const TeacherClassSuggestion({
    required this.classData,
    required this.schedule,
  });
}

class TeacherClassContextHelper {
  static bool isPrivilegedUser(User? user) {
    if (user == null) return false;
    final roles = user.roles.map((role) => role.toLowerCase()).toList();
    return roles.contains('admin') ||
        roles.contains('diretor') ||
        roles.contains('coordenador') ||
        roles.contains('administrador');
  }

  static Future<void> ensureDataLoaded({
    required AuthProvider authProvider,
    required ClassProvider classProvider,
    required HorarioProvider horarioProvider,
    required AcademicCalendarProvider academicProvider,
    bool forceRefresh = false,
    String screen = 'classes',
  }) async {
    final token = authProvider.token;
    final user = authProvider.user;

    if (token == null || token.trim().isEmpty) {
      return;
    }

    final futures = <Future<void>>[];

    if (forceRefresh || classProvider.classes.isEmpty) {
      final filter = <String, String>{};
      if ((user?.schoolId ?? '').trim().isNotEmpty) {
        filter['schoolId'] = user!.schoolId;
      }
      futures.add(classProvider.fetchClasses(token, filter: filter));
    }

    futures.add(Future<void>(() async {
      if (academicProvider.schoolYears.isEmpty) {
        await academicProvider.fetchSchoolYears();
      }

      if (academicProvider.schoolYears.isEmpty) {
        return;
      }

      final currentYear = DateTime.now().year;
      final resolvedYear = academicProvider.schoolYears.firstWhere(
        (year) => year.year == currentYear,
        orElse: () => academicProvider.schoolYears.first,
      );

      if (academicProvider.selectedSchoolYear?.id != resolvedYear.id) {
        academicProvider.selectSchoolYear(resolvedYear);
      }

      if (forceRefresh || academicProvider.terms.isEmpty) {
        await academicProvider.fetchTermsForSelectedYear();
      }
    }));

    await Future.wait(futures);

    final currentTerm = getCurrentTerm(academicProvider.terms);
    final referenceTerm = getReferenceTerm(
      academicProvider.terms,
      currentTerm: currentTerm,
    );
    logContext(
      screen: screen,
      teacherId: user?.id,
      schoolId: user?.schoolId,
      currentTerm: currentTerm,
      referenceTerm: referenceTerm,
    );

    final relevantForTeacher = assignedHorarios(
      horarioProvider.horarios,
      academicProvider.terms,
      user: user,
    );

    if (forceRefresh ||
        horarioProvider.horarios.isEmpty ||
        relevantForTeacher.isEmpty) {
      final filter = <String, String>{};
      if (!isPrivilegedUser(user) && (user?.id ?? '').trim().isNotEmpty) {
        filter['teacherId'] = user!.id;
      }
      await horarioProvider.fetchHorarios(
        token,
        filter: filter,
        debugScreen: screen,
      );
    }
  }

  static TermModel? getCurrentTerm(
    List<TermModel> terms, {
    DateTime? now,
  }) {
    if (terms.isEmpty) return null;
    final referenceDate = now ?? DateTime.now();

    for (final term in terms) {
      if (term.tipo.toLowerCase() != 'letivo') continue;
      final started = referenceDate.isAfter(term.startDate) ||
          _isSameDay(referenceDate, term.startDate);
      final notEnded = referenceDate.isBefore(term.endDate) ||
          _isSameDay(referenceDate, term.endDate);
      if (started && notEnded) {
        return term;
      }
    }

    return null;
  }

  static TermModel? getReferenceTerm(
    List<TermModel> terms, {
    DateTime? now,
    TermModel? currentTerm,
  }) {
    final candidates = _referenceTermCandidates(
      terms,
      now: now,
      currentTerm: currentTerm,
    );
    return candidates.isEmpty ? null : candidates.first;
  }

  static bool matchesEffectiveTerm(
      HorarioModel horario, TermModel currentTerm) {
    final termMatches = horario.termId == currentTerm.id;
    final targetMatches = horario.targetTermId == currentTerm.id;
    final resolvedMatches = horario.resolvedFromTermId == currentTerm.id;
    return termMatches || targetMatches || resolvedMatches;
  }

  static List<HorarioModel> effectiveHorarios(
    List<HorarioModel> horarios,
    TermModel currentTerm, {
    User? user,
  }) {
    final privileged = isPrivilegedUser(user);
    return horarios.where((horario) {
      final sameEffectiveTerm = matchesEffectiveTerm(horario, currentTerm);
      final belongsToTeacher =
          privileged || user == null || horario.teacherId == user.id;
      final belongsToSchool = _belongsToUserSchool(horario, user);
      return sameEffectiveTerm && belongsToTeacher && belongsToSchool;
    }).toList();
  }

  static List<HorarioModel> agendaHorarios(
    List<HorarioModel> horarios,
    List<TermModel> terms, {
    User? user,
    DateTime? now,
  }) {
    final currentTerm = getCurrentTerm(terms, now: now);
    if (currentTerm == null) return const [];
    return effectiveHorarios(horarios, currentTerm, user: user);
  }

  static List<HorarioModel> assignedHorarios(
    List<HorarioModel> horarios,
    List<TermModel> terms, {
    User? user,
    DateTime? now,
  }) {
    final scoped = horarios.where((horario) {
      final belongsToTeacher = isPrivilegedUser(user) ||
          user == null ||
          horario.teacherId == user.id;
      return belongsToTeacher && _belongsToUserSchool(horario, user);
    }).toList();

    if (scoped.isEmpty || terms.isEmpty) return scoped;

    final currentTerm = getCurrentTerm(terms, now: now);
    if (currentTerm != null) {
      final currentSchedules = scoped
          .where((horario) => matchesEffectiveTerm(horario, currentTerm))
          .toList();
      if (currentSchedules.isNotEmpty) return currentSchedules;
    }

    for (final term in _referenceTermCandidates(
      terms,
      now: now,
      currentTerm: currentTerm,
    )) {
      final schedules = scoped
          .where((horario) => matchesEffectiveTerm(horario, term))
          .toList();
      if (schedules.isNotEmpty) return schedules;
    }

    return const [];
  }

  static List<HorarioModel> relevantHorarios(
    List<HorarioModel> horarios,
    List<TermModel> terms, {
    User? user,
    DateTime? now,
  }) {
    return assignedHorarios(horarios, terms, user: user, now: now);
  }

  static List<ClassModel> getAvailableClasses({
    required List<ClassModel> classes,
    required List<HorarioModel> horarios,
    required User? user,
    List<TermModel> terms = const [],
  }) {
    if (user == null) return const [];

    final filteredHorarios = relevantHorarios(
      horarios,
      terms,
      user: user,
    );
    final classById = <String, ClassModel>{
      for (final classData in classes)
        if (classData.id.isNotEmpty) classData.id: classData,
    };

    for (final horario in filteredHorarios) {
      if (horario.classId.isEmpty) continue;
      classById.putIfAbsent(
        horario.classId,
        () => _classFromHorario(horario),
      );
    }

    if (isPrivilegedUser(user)) {
      final allClasses = classById.values.toList();
      allClasses.sort((left, right) => left.name.compareTo(right.name));
      return allClasses;
    }

    final teacherClassIds = filteredHorarios
        .where((horario) => horario.teacherId == user.id)
        .map((horario) => horario.classId)
        .toSet();

    final available = classById.values
        .where((classData) => teacherClassIds.contains(classData.id))
        .toList();

    available.sort((left, right) => left.name.compareTo(right.name));
    return available;
  }

  static ClassModel _classFromHorario(HorarioModel horario) {
    final classInfo = horario.classInfo;
    return ClassModel(
      id: classInfo.id,
      name: classInfo.name,
      schoolYear: classInfo.schoolYear,
      grade: classInfo.grade,
      shift: classInfo.shift,
      level: classInfo.level,
      room: null,
      monthlyFee: 0,
      capacity: null,
      status: 'Ativa',
      studentCount: 0,
      scheduleSettings: null,
      schoolId: classInfo.schoolId,
    );
  }

  static TeacherClassSuggestion? resolveSuggestedClass({
    required List<ClassModel> classes,
    required List<HorarioModel> horarios,
    required User? user,
    List<TermModel> terms = const [],
  }) {
    final availableClasses = getAvailableClasses(
      classes: classes,
      horarios: horarios,
      user: user,
      terms: terms,
    );

    if (availableClasses.isEmpty) {
      return null;
    }

    final classById = <String, ClassModel>{};
    for (final classData in availableClasses) {
      final id = classData.id;
      if (id.isNotEmpty) {
        classById[id] = classData;
      }
    }

    final relevantSchedules =
        relevantHorarios(horarios, terms, user: user).where((horario) {
      final classId = horario.classId;
      final belongsToTeacher =
          isPrivilegedUser(user) || horario.teacherId == (user?.id ?? '');
      return classById.containsKey(classId) && belongsToTeacher;
    }).toList();

    final preferredSchedule = _resolvePreferredSchedule(relevantSchedules);
    if (preferredSchedule != null) {
      final classData = classById[preferredSchedule.classId];
      if (classData != null) {
        return TeacherClassSuggestion(
          classData: classData,
          schedule: preferredSchedule,
        );
      }
    }

    return TeacherClassSuggestion(
      classData: availableClasses.first,
      schedule: null,
    );
  }

  static List<ClassModel> sortClassesForActivities({
    required List<ClassModel> classes,
    required List<HorarioModel> horarios,
    required User? user,
    List<TermModel> terms = const [],
  }) {
    final available = getAvailableClasses(
      classes: classes,
      horarios: horarios,
      user: user,
      terms: terms,
    );

    final suggestion = resolveSuggestedClass(
      classes: classes,
      horarios: horarios,
      user: user,
      terms: terms,
    );

    if (suggestion == null) {
      return available;
    }

    available.sort((left, right) {
      final leftIsSuggested = left.id == suggestion.classData.id;
      final rightIsSuggested = right.id == suggestion.classData.id;

      if (leftIsSuggested && !rightIsSuggested) return -1;
      if (!leftIsSuggested && rightIsSuggested) return 1;
      return left.name.compareTo(right.name);
    });

    return available;
  }

  static List<SubjectModel> subjectsForClass({
    required String classId,
    required List<HorarioModel> horarios,
    required User? user,
    List<TermModel> terms = const [],
  }) {
    final relevant =
        relevantHorarios(horarios, terms, user: user).where((horario) {
      final sameClass = horario.classId == classId;
      final belongsToTeacher =
          isPrivilegedUser(user) || horario.teacherId == (user?.id ?? '');
      return sameClass && belongsToTeacher;
    }).toList();

    final subjectById = <String, SubjectModel>{};
    for (final horario in relevant) {
      if (horario.subject.id.isEmpty) continue;
      subjectById.putIfAbsent(horario.subject.id, () => horario.subject);
    }

    final items = subjectById.values.toList();
    items.sort((left, right) => left.name.compareTo(right.name));
    return items;
  }

  static HorarioModel? scheduleForClass({
    required String classId,
    required List<HorarioModel> horarios,
    required User? user,
    List<TermModel> terms = const [],
  }) {
    final relevant =
        relevantHorarios(horarios, terms, user: user).where((horario) {
      final sameClass = horario.classId == classId;
      final belongsToTeacher =
          isPrivilegedUser(user) || horario.teacherId == (user?.id ?? '');
      return sameClass && belongsToTeacher;
    }).toList();

    return _resolvePreferredSchedule(relevant);
  }

  static void logContext({
    required String screen,
    required String? teacherId,
    required String? schoolId,
    required TermModel? currentTerm,
    TermModel? referenceTerm,
  }) {
    if (!kDebugMode) return;
    debugPrint('[TeacherMobile][Context] '
        'teacherId=${teacherId ?? '-'} '
        'schoolId=${schoolId ?? '-'} '
        'currentTermId=${currentTerm?.id ?? '-'} '
        'referenceTermId=${referenceTerm?.id ?? '-'} '
        'baseUrl=${ApiConfig.apiUrl} '
        'screen=$screen');
  }

  static List<TermModel> _referenceTermCandidates(
    List<TermModel> terms, {
    DateTime? now,
    TermModel? currentTerm,
  }) {
    final referenceDate = now ?? DateTime.now();
    final letivo = terms
        .where((term) =>
            term.tipo.toLowerCase() == 'letivo' && term.id != currentTerm?.id)
        .toList();

    final ended = letivo
        .where((term) => term.endDate.isBefore(referenceDate))
        .toList()
      ..sort((left, right) => right.endDate.compareTo(left.endDate));
    final upcoming = letivo
        .where((term) => term.startDate.isAfter(referenceDate))
        .toList()
      ..sort((left, right) => left.startDate.compareTo(right.startDate));
    final remaining = letivo
        .where((term) => !ended.contains(term) && !upcoming.contains(term))
        .toList()
      ..sort((left, right) => left.startDate.compareTo(right.startDate));

    return <TermModel>[...ended, ...upcoming, ...remaining];
  }

  static bool _belongsToUserSchool(HorarioModel horario, User? user) {
    final expectedSchoolId = user?.schoolId.trim() ?? '';
    if (expectedSchoolId.isEmpty) return true;

    final scheduleSchoolId = horario.schoolId?.trim() ?? '';
    final classSchoolId = horario.classInfo.schoolId.trim();
    if (scheduleSchoolId.isNotEmpty && scheduleSchoolId != expectedSchoolId) {
      return false;
    }
    if (classSchoolId.isNotEmpty && classSchoolId != expectedSchoolId) {
      return false;
    }
    return true;
  }

  static List<HorarioModel> logFilteredHorarios({
    required String screen,
    required List<HorarioModel> before,
    required List<HorarioModel> after,
    required TermModel currentTerm,
  }) {
    if (!kDebugMode) return after;
    final keptIds = after.map((item) => item.id).toSet();
    final excluded = before.where((item) => !keptIds.contains(item.id));
    final termMismatchCount = excluded
        .where((item) => !matchesEffectiveTerm(item, currentTerm))
        .length;
    debugPrint('[TeacherMobile][HorariosFiltered] '
        'screen=$screen currentTermId=${currentTerm.id} '
        'before=${before.length} after=${after.length} '
        'termMismatch=$termMismatchCount '
        'teacherOrSchoolMismatch=${before.length - after.length - termMismatchCount}');
    return after;
  }

  static void logClasses({
    required String screen,
    required TermModel? currentTerm,
    required List<ClassModel> classes,
    required List<HorarioModel> horarios,
  }) {
    if (!kDebugMode) return;
    debugPrint('[TeacherMobile][ClassesResolved] '
        'screen=$screen '
        'currentTermId=${currentTerm?.id ?? '-'} '
        'totalHorariosAfterTeacherFilter=${horarios.length} '
        'totalClasses=${classes.length} '
        'uniqueClassIds=${classes.map((item) => item.id).toSet().length}');
  }

  static void logAttendanceClasses({
    required TermModel? currentTerm,
    required List<ClassModel> classes,
    required List<HorarioModel> horarios,
  }) {
    if (!kDebugMode) return;
    debugPrint('[TeacherMobile][AttendanceClasses] '
        'currentTermId=${currentTerm?.id ?? '-'} '
        'availableClassesCount=${classes.length} '
        'totalHorariosAfterTeacherFilter=${horarios.length}');
  }

  static void logScreenResult({
    required String screen,
    required bool isLoading,
    required int totalVisibleClasses,
    required int totalVisibleSchedules,
    required bool emptyStateShown,
  }) {
    if (!kDebugMode) return;
    debugPrint('[TeacherMobile][ScreenResult] '
        'screen=$screen '
        'isLoading=$isLoading '
        'totalVisibleClasses=$totalVisibleClasses '
        'totalVisibleSchedules=$totalVisibleSchedules '
        'emptyStateShown=$emptyStateShown');
  }

  static HorarioModel? _resolvePreferredSchedule(List<HorarioModel> horarios) {
    if (horarios.isEmpty) return null;

    final now = DateTime.now();
    final nowInMinutes = now.hour * 60 + now.minute;
    final weekday = now.weekday;

    final todays = horarios
        .where((horario) => horario.dayOfWeek == weekday)
        .toList()
      ..sort((left, right) => _timeToMinutes(left.startTime)
          .compareTo(_timeToMinutes(right.startTime)));

    for (final horario in todays) {
      final start = _timeToMinutes(horario.startTime);
      final end = _timeToMinutes(horario.endTime);
      if (nowInMinutes >= start && nowInMinutes < end) {
        return horario;
      }
    }

    for (final horario in todays) {
      final start = _timeToMinutes(horario.startTime);
      if (nowInMinutes < start) {
        return horario;
      }
    }

    for (var step = 1; step <= 7; step++) {
      final nextWeekday = ((weekday - 1 + step) % 7) + 1;
      final upcoming = horarios
          .where((horario) => horario.dayOfWeek == nextWeekday)
          .toList()
        ..sort((left, right) => _timeToMinutes(left.startTime)
            .compareTo(_timeToMinutes(right.startTime)));

      if (upcoming.isNotEmpty) {
        return upcoming.first;
      }
    }

    return horarios.first;
  }

  static bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  static int _timeToMinutes(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return 0;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return hour * 60 + minute;
  }
}
