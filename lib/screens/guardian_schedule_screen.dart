import 'package:academyhub_mobile/model/guardian_auth_model.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/services/guardian_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class GuardianScheduleScreen extends StatefulWidget {
  final GuardianLinkedStudent student;

  const GuardianScheduleScreen({
    super.key,
    required this.student,
  });

  @override
  State<GuardianScheduleScreen> createState() => _GuardianScheduleScreenState();
}

class _GuardianScheduleScreenState extends State<GuardianScheduleScreen> {
  final GuardianAuthService _service = GuardianAuthService();

  GuardianScheduleData? _data;
  bool _isLoading = true;
  bool _showWeek = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = context.read<AuthProvider>().token;

    if (token == null || token.trim().isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Sua sessão expirou. Entre novamente para acessar a grade.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _service.getGuardianSchedule(
        token: token,
        studentId: widget.student.id,
      );

      if (!mounted) return;
      setState(() {
        _data = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = _data?.selectedStudent ?? widget.student;
    final schedule = _data?.schedule;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF111827),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Grade de horários',
              style: GoogleFonts.inter(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827),
              ),
            ),
            Text(
              student.fullName,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00A859)),
            )
          : _error != null
              ? _GuardianAcademicError(
                  message: _error!,
                  onRetry: _load,
                )
              : RefreshIndicator(
                  color: const Color(0xFF00A859),
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
                    children: [
                      _GuardianAcademicStudentCard(student: student),
                      SizedBox(height: 16.h),
                      _GuardianLessonHero(
                        currentLesson: schedule?.currentClass,
                        nextLesson: schedule?.nextClass,
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          _GuardianAcademicChip(
                            label: 'Hoje',
                            selected: !_showWeek,
                            onTap: () => setState(() => _showWeek = false),
                          ),
                          SizedBox(width: 10.w),
                          _GuardianAcademicChip(
                            label: 'Semana',
                            selected: _showWeek,
                            onTap: () => setState(() => _showWeek = true),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      if (_showWeek)
                        ..._buildWeekSections(schedule)
                      else
                        _buildTodaySection(schedule),
                    ],
                  ),
                ),
    );
  }

  List<Widget> _buildWeekSections(GuardianScheduleSnapshot? schedule) {
    final days = schedule?.week ?? const <GuardianWeekScheduleDay>[];

    if (days.every((day) => day.items.isEmpty)) {
      return const [
        _GuardianAcademicEmpty(
          title: 'Sem aulas programadas',
          message: 'A grade semanal ainda não possui horários disponíveis.',
        ),
      ];
    }

    return [
      for (final day in days) ...[
        Text(
          day.label,
          style: GoogleFonts.inter(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111827),
          ),
        ),
        SizedBox(height: 8.h),
        if (day.items.isEmpty)
          const _GuardianAcademicInfoCard(
            title: 'Dia livre',
            description: 'Não encontramos horários cadastrados para este dia.',
          )
        else
          ...day.items.map(
            (lesson) => Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: _GuardianLessonCard(
                lesson: lesson,
                isCurrent: lesson.id == schedule?.currentClass?.id,
                isNext: lesson.id == schedule?.nextClass?.id,
              ),
            ),
          ),
        SizedBox(height: 16.h),
      ],
    ];
  }

  Widget _buildTodaySection(GuardianScheduleSnapshot? schedule) {
    final todayLessons = schedule?.today ?? const <GuardianLesson>[];

    if (todayLessons.isEmpty) {
      return _GuardianAcademicEmpty(
        title: 'Sem aulas para hoje',
        message: schedule?.nextClass != null
            ? 'A próxima aula já está destacada acima para facilitar o acompanhamento.'
            : 'Não encontramos mais aulas agendadas para o dia de hoje.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aulas de hoje',
          style: GoogleFonts.inter(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111827),
          ),
        ),
        SizedBox(height: 8.h),
        ...todayLessons.map(
          (lesson) => Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: _GuardianLessonCard(
              lesson: lesson,
              isCurrent: lesson.id == schedule?.currentClass?.id,
              isNext: lesson.id == schedule?.nextClass?.id,
            ),
          ),
        ),
      ],
    );
  }
}

class _GuardianLessonHero extends StatelessWidget {
  final GuardianLesson? currentLesson;
  final GuardianLesson? nextLesson;

  const _GuardianLessonHero({
    required this.currentLesson,
    required this.nextLesson,
  });

  @override
  Widget build(BuildContext context) {
    final lesson = currentLesson ?? nextLesson;
    final isCurrent = currentLesson != null;

    if (lesson == null) {
      return const _GuardianAcademicEmpty(
        title: 'Sem aulas em destaque',
        message: 'Quando houver aulas programadas, a próxima aula aparecerá aqui.',
      );
    }

    return Container(
      padding: EdgeInsets.all(22.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(
          color: isCurrent
              ? const Color(0xFF00A859).withValues(alpha: 0.26)
              : const Color(0xFF2F80ED).withValues(alpha: 0.22),
        ),
        gradient: LinearGradient(
          colors: [
            isCurrent
                ? const Color(0xFFE8F7EF)
                : const Color(0xFFEAF3FF),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GuardianAcademicPill(
            label: isCurrent ? 'Acontecendo agora' : 'Próxima aula',
            color: isCurrent
                ? const Color(0xFF00A859)
                : const Color(0xFF2F80ED),
          ),
          SizedBox(height: 14.h),
          Text(
            lesson.subjectName,
            style: TextStyle(
              color: const Color(0xFF111827),
              fontSize: 28.sp,
              fontFamily: 'GR Milesons Three',
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '${lesson.weekdayLabel} · ${lesson.timeLabel}',
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF374151),
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            lesson.teacherName,
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF4B5563),
            ),
          ),
          if ((lesson.room ?? '').trim().isNotEmpty) ...[
            SizedBox(height: 6.h),
            Text(
              'Local: ${lesson.room}',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GuardianLessonCard extends StatelessWidget {
  final GuardianLesson lesson;
  final bool isCurrent;
  final bool isNext;

  const _GuardianLessonCard({
    required this.lesson,
    required this.isCurrent,
    required this.isNext,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isCurrent
        ? const Color(0xFF00A859)
        : isNext
            ? const Color(0xFF2F80ED)
            : const Color(0xFFE5E7EB);

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58.w,
            padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              children: [
                Text(
                  lesson.startTime,
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  lesson.endTime,
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isCurrent || isNext)
                  Padding(
                    padding: EdgeInsets.only(bottom: 8.h),
                    child: _GuardianAcademicPill(
                      label: isCurrent ? 'Agora' : 'Próxima',
                      color: isCurrent
                          ? const Color(0xFF00A859)
                          : const Color(0xFF2F80ED),
                    ),
                  ),
                Text(
                  lesson.subjectName,
                  style: GoogleFonts.inter(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  lesson.teacherName,
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4B5563),
                  ),
                ),
                if ((lesson.room ?? '').trim().isNotEmpty) ...[
                  SizedBox(height: 6.h),
                  Text(
                    'Local: ${lesson.room}',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuardianAcademicStudentCard extends StatelessWidget {
  final GuardianLinkedStudent student;

  const _GuardianAcademicStudentCard({
    required this.student,
  });

  @override
  Widget build(BuildContext context) {
    final classInfo = student.classInfo;
    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F7EF),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(
              PhosphorIcons.student_fill,
              color: const Color(0xFF00A859),
              size: 22.sp,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.fullName,
                  style: GoogleFonts.inter(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  classInfo == null
                      ? student.relationship
                      : '${student.relationship} · ${classInfo.name} · ${classInfo.shift}',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuardianAcademicChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GuardianAcademicChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF00A859) : Colors.white,
          borderRadius: BorderRadius.circular(999.r),
          border: Border.all(
            color: selected ? const Color(0xFF00A859) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}

class _GuardianAcademicPill extends StatelessWidget {
  final String label;
  final Color color;

  const _GuardianAcademicPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11.sp,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _GuardianAcademicInfoCard extends StatelessWidget {
  final String title;
  final String description;

  const _GuardianAcademicInfoCard({
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6B7280),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuardianAcademicEmpty extends StatelessWidget {
  final String title;
  final String message;

  const _GuardianAcademicEmpty({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(22.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Container(
            width: 58.w,
            height: 58.w,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Icon(
              PhosphorIcons.book_open_fill,
              size: 26.sp,
              color: const Color(0xFF6B7280),
            ),
          ),
          SizedBox(height: 14.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuardianAcademicError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _GuardianAcademicError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIcons.warning_circle_fill,
              size: 42.sp,
              color: const Color(0xFFEF4444),
            ),
            SizedBox(height: 14.h),
            Text(
              'Não foi possível carregar os dados.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B7280),
              ),
            ),
            SizedBox(height: 18.h),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A859),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
