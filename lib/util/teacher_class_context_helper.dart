import 'package:academyhub_mobile/model/class_model.dart';
import 'package:academyhub_mobile/model/horario_model.dart';
import 'package:academyhub_mobile/model/subject_model.dart';
import 'package:academyhub_mobile/model/term_model.dart';
import 'package:academyhub_mobile/model/user_model.dart';
import 'package:academyhub_mobile/providers/academic_calendar_provider.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/providers/class_provider.dart';
import 'package:academyhub_mobile/providers/horario_provider.dart';

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
  }) async {
    final token = authProvider.token;
    final user = authProvider.user;

    if (token == null || token.trim().isEmpty) {
      return;
    }

    final futures = <Future<void>>[];

    if (classProvider.classes.isEmpty) {
      final filter = <String, String>{};
      if ((user?.schoolId ?? '').trim().isNotEmpty) {
        filter['schoolId'] = user!.schoolId;
      }
      futures.add(classProvider.fetchClasses(token, filter: filter));
    }

    if (horarioProvider.horarios.isEmpty) {
      futures.add(horarioProvider.fetchHorarios(token));
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

      if (academicProvider.terms.isEmpty) {
        await academicProvider.fetchTermsForSelectedYear();
      }
    }));

    await Future.wait(futures);
  }

  static TermModel? getCurrentTerm(List<TermModel> terms) {
    if (terms.isEmpty) return null;
    final now = DateTime.now();

    for (final term in terms) {
      final started = now.isAfter(term.startDate) || _isSameDay(now, term.startDate);
      final notEnded = now.isBefore(term.endDate) || _isSameDay(now, term.endDate);
      if (started && notEnded) {
        return term;
      }
    }

    return terms.first;
  }

  static List<HorarioModel> relevantHorarios(
    List<HorarioModel> horarios,
    List<TermModel> terms,
  ) {
    final currentTerm = getCurrentTerm(terms);
    if (currentTerm == null) return horarios;
    return horarios.where((horario) => horario.termId == currentTerm.id).toList();
  }

  static List<ClassModel> getAvailableClasses({
    required List<ClassModel> classes,
    required List<HorarioModel> horarios,
    required User? user,
    List<TermModel> terms = const [],
  }) {
    if (user == null) return const [];

    final filteredHorarios = relevantHorarios(horarios, terms);
    if (isPrivilegedUser(user)) {
      final allClasses = List<ClassModel>.from(classes);
      allClasses.sort((left, right) => left.name.compareTo(right.name));
      return allClasses;
    }

    final teacherClassIds = filteredHorarios
        .where((horario) => horario.teacherId == user.id)
        .map((horario) => horario.classId)
        .toSet();

    final available = classes
        .where((classData) => teacherClassIds.contains(classData.id))
        .toList();

    available.sort((left, right) => left.name.compareTo(right.name));
    return available;
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

    final relevantSchedules = relevantHorarios(horarios, terms).where((horario) {
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
    final relevant = relevantHorarios(horarios, terms).where((horario) {
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
    final relevant = relevantHorarios(horarios, terms).where((horario) {
      final sameClass = horario.classId == classId;
      final belongsToTeacher =
          isPrivilegedUser(user) || horario.teacherId == (user?.id ?? '');
      return sameClass && belongsToTeacher;
    }).toList();

    return _resolvePreferredSchedule(relevant);
  }

  static HorarioModel? _resolvePreferredSchedule(List<HorarioModel> horarios) {
    if (horarios.isEmpty) return null;

    final now = DateTime.now();
    final nowInMinutes = now.hour * 60 + now.minute;
    final weekday = now.weekday;

    final todays = horarios
        .where((horario) => horario.dayOfWeek == weekday)
        .toList()
      ..sort((left, right) =>
          _timeToMinutes(left.startTime).compareTo(_timeToMinutes(right.startTime)));

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
