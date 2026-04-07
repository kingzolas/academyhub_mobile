import 'package:academyhub_mobile/model/class_model.dart';
import 'package:academyhub_mobile/model/enrollment_model.dart';
import 'package:academyhub_mobile/model/student_note_model.dart';
import 'package:academyhub_mobile/model/teacher_student_summary_model.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/providers/student_note_provider.dart';
import 'package:academyhub_mobile/providers/teacher_student_summary_provider.dart';
import 'package:academyhub_mobile/widgets/attendance_operation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

const _academyDark = Color(0xFF1E1E1E);
const _backgroundDark = Color(0xFF0E1116);
const _surfaceDark = Color(0xFF171B22);
const _surfaceDarkSoft = Color(0xFF1E242E);
const _borderDark = Color(0xFF28303D);

const _academyBlue = Color(0xFF448AFF);
const _academyGreen = Color(0xFF43A047);
const _errorColor = Color(0xFFE85D5D);
const _warningColor = Color(0xFFF4B740);
const _accentColor = Color(0xFF6A5AE0);

const _textPrimaryLight = Color(0xFF1E1E1E);
const _textSecondaryLight = Color(0xFF64748B);
const _pageLight = Color(0xFFF4F6F8);
const _surfaceLight = Colors.white;
const _surfaceLightSoft = Color(0xFFF8FAFC);
const _borderLight = Color(0xFFE5EAF1);

const _textPrimaryDark = Color(0xFFF7F9FC);
const _textSecondaryDark = Color(0xFF9AA6B5);

Color _pageBg(bool isDark) => isDark ? _backgroundDark : _pageLight;
Color _surface(bool isDark) => isDark ? _surfaceDark : _surfaceLight;
Color _surfaceSoft(bool isDark) =>
    isDark ? _surfaceDarkSoft : _surfaceLightSoft;
Color _border(bool isDark) => isDark ? _borderDark : _borderLight;
Color _textPrimary(bool isDark) =>
    isDark ? _textPrimaryDark : _textPrimaryLight;
Color _textSecondary(bool isDark) =>
    isDark ? _textSecondaryDark : _textSecondaryLight;

TextStyle _titleStyle(bool isDark, {double? size}) =>
    GoogleFonts.sairaCondensed(
      fontSize: size ?? 19.sp,
      fontWeight: FontWeight.w700,
      color: _textPrimary(isDark),
      letterSpacing: 0.2,
    );

TextStyle _bodyStyle(
  bool isDark, {
  double? size,
  FontWeight fontWeight = FontWeight.w500,
  Color? color,
  double? height,
}) =>
    GoogleFonts.inter(
      fontSize: size ?? 13.sp,
      fontWeight: fontWeight,
      color: color ?? _textPrimary(isDark),
      height: height,
    );

class TeacherStudentProfileScreen extends StatefulWidget {
  final Enrollment enrollment;
  final ClassModel classData;

  const TeacherStudentProfileScreen({
    super.key,
    required this.enrollment,
    required this.classData,
  });

  @override
  State<TeacherStudentProfileScreen> createState() =>
      _TeacherStudentProfileScreenState();
}

class _TeacherStudentProfileScreenState
    extends State<TeacherStudentProfileScreen> {
  late final TeacherStudentSummaryProvider _summaryProvider;

  @override
  void initState() {
    super.initState();
    _summaryProvider = TeacherStudentSummaryProvider();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _summaryProvider.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool refresh = false}) async {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final noteProv = Provider.of<StudentNoteProvider>(context, listen: false);

    await Future.wait([
      _summaryProvider.loadSummary(
        authProv,
        classId: widget.classData.id,
        studentId: widget.enrollment.student.id,
        refresh: refresh,
      ),
      noteProv.loadNotes(authProv, widget.enrollment.student.id),
    ]);
  }

  void _launchContact(String phone, bool isWhatsApp) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          isWhatsApp
              ? 'WhatsApp indisponível nesta versão. Contato: $phone'
              : 'Ligação indisponível nesta versão. Contato: $phone',
        ),
      ),
    );
  }

  void _openCreateNoteSheet(String studentName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateNoteBottomSheet(
        studentId: widget.enrollment.student.id,
        studentName: studentName,
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Sem cadastro';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return '--';
    return DateFormat('dd/MM/yyyy • HH:mm').format(date);
  }

  String _displayAge(TeacherStudentSummary? summary) {
    final age = summary?.student.age;
    if (age != null) return '$age anos';

    final birthDate = widget.enrollment.student.birthDate;
    final now = DateTime.now();
    int years = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      years -= 1;
    }

    return years >= 0 ? '$years anos' : 'Sem idade';
  }

  List<TeacherGuardianContact> _buildAdditionalContacts(
    TeacherGuardiansSummary guardians,
  ) {
    final primaryIds = <String>{
      if (guardians.father != null) guardians.father!.id,
      if (guardians.mother != null) guardians.mother!.id,
    };

    return guardians.contacts
        .where((contact) => !primaryIds.contains(contact.id))
        .toList();
  }

  Color _recordColor(TeacherAttendanceRecord record) {
    if (record.isPresent) return _academyGreen;

    switch (record.absenceState.toUpperCase()) {
      case 'APPROVED':
        return _academyBlue;
      case 'PENDING':
        return _warningColor;
      case 'REJECTED':
        return _accentColor;
      default:
        return _errorColor;
    }
  }

  List<StudentNoteModel> _resolveNotes(
    StudentNoteProvider noteProvider,
    TeacherStudentSummary? summary,
  ) {
    if (noteProvider.notes.isNotEmpty) {
      return noteProvider.notes;
    }

    if (summary != null && summary.notes.isNotEmpty) {
      return summary.notes;
    }

    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChangeNotifierProvider<TeacherStudentSummaryProvider>.value(
      value: _summaryProvider,
      child: Consumer2<TeacherStudentSummaryProvider, StudentNoteProvider>(
        builder: (context, summaryProvider, noteProvider, _) {
          final summary = summaryProvider.summary;

          if (summaryProvider.isLoading && summary == null) {
            return _TeacherStudentProfileLoading(
              isDark: isDark,
              className: widget.classData.name,
            );
          }

          if (summary == null) {
            return _TeacherStudentProfileError(
              isDark: isDark,
              message: summaryProvider.errorMessage ??
                  'Não foi possível carregar o perfil do aluno.',
              onRetry: () => _loadData(),
            );
          }

          final notes = _resolveNotes(noteProvider, summary);
          final guardians = summary.guardians;
          final extraContacts = _buildAdditionalContacts(guardians);

          return Scaffold(
            backgroundColor: _pageBg(isDark),
            appBar: AppBar(
              backgroundColor: _pageBg(isDark),
              elevation: 0,
              scrolledUnderElevation: 0,
              iconTheme: IconThemeData(color: _textPrimary(isDark)),
              titleSpacing: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Perfil do aluno', style: _titleStyle(isDark)),
                  Text(
                    summary.classInfo.name,
                    style: _bodyStyle(
                      isDark,
                      size: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: _academyBlue,
                    ),
                  ),
                ],
              ),
              actions: [
                Padding(
                  padding: EdgeInsets.only(right: 14.w),
                  child: Material(
                    color: _surfaceSoft(isDark),
                    borderRadius: BorderRadius.circular(14.r),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14.r),
                      onTap: () => _loadData(refresh: true),
                      child: Container(
                        width: 42.w,
                        height: 42.w,
                        alignment: Alignment.center,
                        child: summaryProvider.isRefreshing
                            ? SizedBox(
                                width: 18.w,
                                height: 18.w,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _academyBlue,
                                ),
                              )
                            : Icon(
                                PhosphorIcons.arrow_clockwise,
                                color: _textPrimary(isDark),
                                size: 19.sp,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              backgroundColor: _academyBlue,
              elevation: 1,
              onPressed: () => _openCreateNoteSheet(summary.student.fullName),
              icon:
                  const Icon(PhosphorIcons.pencil_simple, color: Colors.white),
              label: Text(
                'Anotação',
                style: _bodyStyle(
                  isDark,
                  size: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            body: RefreshIndicator(
              onRefresh: () => _loadData(refresh: true),
              color: _academyBlue,
              child: _TeacherStudentProfileBody(
                isDark: isDark,
                summary: summary,
                extraContacts: extraContacts,
                notes: notes,
                noteProvider: noteProvider,
                ageLabel: _displayAge(summary),
                formatDate: _formatDate,
                formatDateTime: _formatDateTime,
                recordColorBuilder: _recordColor,
                onContactTap: _launchContact,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TeacherStudentProfileLoading extends StatelessWidget {
  final bool isDark;
  final String className;

  const _TeacherStudentProfileLoading({
    required this.isDark,
    required this.className,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg(isDark),
      appBar: AppBar(
        backgroundColor: _pageBg(isDark),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: _textPrimary(isDark)),
        title: Text(className, style: _titleStyle(isDark, size: 18.sp)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 40.h),
        children: [
          _LoadingBlock(isDark: isDark, height: 230.h),
          SizedBox(height: 14.h),
          _LoadingBlock(isDark: isDark, height: 180.h),
          SizedBox(height: 14.h),
          _LoadingBlock(isDark: isDark, height: 250.h),
        ],
      ),
    );
  }
}

class _TeacherStudentProfileError extends StatelessWidget {
  final bool isDark;
  final String message;
  final Future<void> Function() onRetry;

  const _TeacherStudentProfileError({
    required this.isDark,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg(isDark),
      appBar: AppBar(
        backgroundColor: _pageBg(isDark),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: _textPrimary(isDark)),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 28.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                PhosphorIcons.warning_circle,
                size: 48.sp,
                color: _errorColor,
              ),
              SizedBox(height: 16.h),
              Text(
                message,
                textAlign: TextAlign.center,
                style: _bodyStyle(
                  isDark,
                  size: 14.sp,
                  color: _textSecondary(isDark),
                  height: 1.5,
                ),
              ),
              SizedBox(height: 20.h),
              ElevatedButton.icon(
                onPressed: () => onRetry(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _academyBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                icon: const Icon(PhosphorIcons.arrow_clockwise),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  final bool isDark;
  final double height;

  const _LoadingBlock({required this.isDark, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: _surface(isDark),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: _border(isDark)),
      ),
      child: Center(
        child: SizedBox(
          width: 26.w,
          height: 26.w,
          child: const CircularProgressIndicator(
            strokeWidth: 2.4,
            color: _academyBlue,
          ),
        ),
      ),
    );
  }
}

class _TeacherStudentProfileBody extends StatelessWidget {
  final bool isDark;
  final TeacherStudentSummary summary;
  final List<TeacherGuardianContact> extraContacts;
  final List<StudentNoteModel> notes;
  final StudentNoteProvider noteProvider;
  final String ageLabel;
  final String Function(DateTime? date) formatDate;
  final String Function(DateTime? date) formatDateTime;
  final Color Function(TeacherAttendanceRecord record) recordColorBuilder;
  final void Function(String phone, bool isWhatsApp) onContactTap;

  const _TeacherStudentProfileBody({
    required this.isDark,
    required this.summary,
    required this.extraContacts,
    required this.notes,
    required this.noteProvider,
    required this.ageLabel,
    required this.formatDate,
    required this.formatDateTime,
    required this.recordColorBuilder,
    required this.onContactTap,
  });

  @override
  Widget build(BuildContext context) {
    final guardians = summary.guardians;
    final health = summary.health;
    final attendance = summary.recentAttendance;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 120.h),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 560.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProfileHeroCard(
                isDark: isDark,
                classInfo: summary.classInfo,
                student: summary.student,
                ageLabel: ageLabel,
                birthDateLabel: formatDate(summary.student.birthDate),
              ),
              SizedBox(height: 16.h),
              _SectionCard(
                isDark: isDark,
                icon: PhosphorIcons.users_three,
                title: 'Responsáveis',
                child: Column(
                  children: [
                    if (guardians.father != null)
                      _GuardianResponsiveTile(
                        isDark: isDark,
                        contact: guardians.father!,
                        highlightLabel: 'Pai',
                        onContactTap: onContactTap,
                      ),
                    if (guardians.father != null && guardians.mother != null)
                      SizedBox(height: 12.h),
                    if (guardians.mother != null)
                      _GuardianResponsiveTile(
                        isDark: isDark,
                        contact: guardians.mother!,
                        highlightLabel: 'Mãe',
                        onContactTap: onContactTap,
                      ),
                    if ((guardians.father != null ||
                            guardians.mother != null) &&
                        extraContacts.isNotEmpty)
                      SizedBox(height: 16.h),
                    if (extraContacts.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Contatos adicionais',
                          style: _bodyStyle(
                            isDark,
                            size: 12.sp,
                            fontWeight: FontWeight.w800,
                            color: _textSecondary(isDark),
                          ),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      ...extraContacts.asMap().entries.map(
                            (entry) => Padding(
                              padding: EdgeInsets.only(
                                bottom: entry.key == extraContacts.length - 1
                                    ? 0
                                    : 10.h,
                              ),
                              child: _GuardianResponsiveTile(
                                isDark: isDark,
                                contact: entry.value,
                                highlightLabel: entry.value.relationship,
                                onContactTap: onContactTap,
                                compact: true,
                              ),
                            ),
                          ),
                    ],
                    if (guardians.father == null &&
                        guardians.mother == null &&
                        extraContacts.isEmpty)
                      _SectionEmptyState(
                        isDark: isDark,
                        icon: PhosphorIcons.user_circle_minus,
                        message:
                            'Nenhum responsável principal foi disponibilizado para esta visão.',
                      ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              _SectionCard(
                isDark: isDark,
                icon: health.hasAlerts
                    ? PhosphorIcons.warning_circle_fill
                    : PhosphorIcons.heartbeat,
                title: 'Saúde e alertas',
                iconColor: health.hasAlerts ? _errorColor : _academyBlue,
                child: Column(
                  children: [
                    if (health.alerts.isNotEmpty)
                      ...health.alerts.asMap().entries.map(
                            (entry) => Padding(
                              padding: EdgeInsets.only(
                                bottom: entry.key == health.alerts.length - 1
                                    ? 0
                                    : 10.h,
                              ),
                              child: _HealthAlertCard(
                                isDark: isDark,
                                label: entry.value.label,
                                description: entry.value.description,
                              ),
                            ),
                          ),
                    if (health.alerts.isNotEmpty && health.details.isNotEmpty)
                      SizedBox(height: 14.h),
                    if (health.details.isNotEmpty)
                      ...health.details.asMap().entries.map(
                            (entry) => Padding(
                              padding: EdgeInsets.only(
                                bottom: entry.key == health.details.length - 1
                                    ? 0
                                    : 10.h,
                              ),
                              child: _HealthDetailCard(
                                isDark: isDark,
                                detail: entry.value,
                              ),
                            ),
                          ),
                    if (!health.hasAlerts && health.details.isEmpty)
                      _SectionEmptyState(
                        isDark: isDark,
                        icon: PhosphorIcons.shield_check,
                        message: 'Sem alertas escolares registrados.',
                      ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              _SectionCard(
                isDark: isDark,
                icon: PhosphorIcons.calendar_check,
                title: 'Frequência recente',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${(attendance.summary.presenceRate * 100).round()}% de presença',
                                style: _titleStyle(isDark, size: 22.sp),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'Janela recente de acompanhamento do aluno.',
                                style: _bodyStyle(
                                  isDark,
                                  size: 12.sp,
                                  color: _textSecondary(isDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color: _surfaceSoft(isDark),
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          child: Text(
                            '${attendance.window.returnedRecords}/${attendance.window.requestedSize} registros',
                            style: _bodyStyle(
                              isDark,
                              size: 11.sp,
                              fontWeight: FontWeight.w800,
                              color: _textSecondary(isDark),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 14.h),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999.r),
                      child: LinearProgressIndicator(
                        minHeight: 10.h,
                        value: attendance.summary.presenceRate
                            .clamp(0.0, 1.0)
                            .toDouble(),
                        backgroundColor: _surfaceSoft(isDark),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(_academyGreen),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    _ResponsiveMetricGrid(
                      isDark: isDark,
                      items: [
                        _MetricGridItem(
                          label: 'Presentes',
                          value: '${attendance.summary.presentCount}',
                          color: _academyGreen,
                        ),
                        _MetricGridItem(
                          label: 'Faltas',
                          value: '${attendance.summary.absentCount}',
                          color: _errorColor,
                        ),
                        _MetricGridItem(
                          label: 'Justificadas',
                          value: '${attendance.summary.justifiedAbsences}',
                          color: _academyBlue,
                        ),
                        _MetricGridItem(
                          label: 'Pendentes',
                          value: '${attendance.summary.pendingJustifications}',
                          color: _warningColor,
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    if (attendance.records.isEmpty)
                      _SectionEmptyState(
                        isDark: isDark,
                        icon: PhosphorIcons.calendar_blank,
                        message:
                            'Ainda não há registros recentes de frequência para este aluno.',
                      )
                    else
                      Column(
                        children: attendance.records
                            .map(
                              (record) => Padding(
                                padding: EdgeInsets.only(bottom: 10.h),
                                child: _AttendanceRecordTile(
                                  isDark: isDark,
                                  record: record,
                                  color: recordColorBuilder(record),
                                  dateLabel: formatDate(record.date),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              _SectionCard(
                isDark: isDark,
                icon: PhosphorIcons.files,
                title: 'Ocorrências e anotações',
                child: noteProvider.isLoading && notes.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(color: _academyBlue),
                      )
                    : notes.isEmpty
                        ? _SectionEmptyState(
                            isDark: isDark,
                            icon: PhosphorIcons.note_blank,
                            message:
                                'Nenhuma anotação registrada para este aluno.',
                          )
                        : Column(
                            children: notes.asMap().entries.map((entry) {
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom:
                                      entry.key == notes.length - 1 ? 0 : 12.h,
                                ),
                                child: _TeacherNoteCard(
                                  note: entry.value,
                                  isDark: isDark,
                                  formatDateTime: formatDateTime,
                                ),
                              );
                            }).toList(),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  final bool isDark;
  final TeacherClassInfo classInfo;
  final TeacherStudentIdentity student;
  final String ageLabel;
  final String birthDateLabel;

  const _ProfileHeroCard({
    required this.isDark,
    required this.classInfo,
    required this.student,
    required this.ageLabel,
    required this.birthDateLabel,
  });

  @override
  Widget build(BuildContext context) {
    final facts = [
      _ProfileFactItem(
        icon: PhosphorIcons.calendar_blank,
        label: 'Idade',
        value: ageLabel,
      ),
      _ProfileFactItem(
        icon: PhosphorIcons.cake,
        label: 'Aniversário',
        value: student.birthday.label ?? '--/--',
      ),
      _ProfileFactItem(
        icon: PhosphorIcons.identification_card,
        label: 'Nascimento',
        value: birthDateLabel,
      ),
      _ProfileFactItem(
        icon: PhosphorIcons.gender_intersex,
        label: 'Gênero',
        value: student.gender ?? 'Sem cadastro',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: _surface(isDark),
        borderRadius: BorderRadius.circular(26.r),
        border: Border.all(color: _border(isDark)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _TopChip(
                isDark: isDark,
                label: classInfo.grade.isEmpty
                    ? classInfo.name
                    : '${classInfo.grade} • ${classInfo.shift}',
                color: _academyBlue,
              ),
              if (student.birthday.isToday)
                _TopChip(
                  isDark: isDark,
                  label: 'Aniversário hoje',
                  color: _academyGreen,
                ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 74.w,
                height: 74.w,
                decoration: BoxDecoration(
                  color: _surfaceSoft(isDark),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    student.initials,
                    style: GoogleFonts.sairaCondensed(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary(isDark),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      style: _titleStyle(isDark, size: 22.sp)
                          .copyWith(height: 1.05),
                    ),
                    SizedBox(height: 10.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: _surfaceSoft(isDark),
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: Text(
                        'Matrícula: ${student.enrollmentNumber ?? 'Sem matrícula'}',
                        style: GoogleFonts.sourceCodePro(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: _textSecondary(isDark),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _ResponsiveProfileFactsGrid(isDark: isDark, items: facts),
        ],
      ),
    );
  }
}

class _ProfileFactItem {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileFactItem({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _ResponsiveProfileFactsGrid extends StatelessWidget {
  final bool isDark;
  final List<_ProfileFactItem> items;

  const _ResponsiveProfileFactsGrid({
    required this.isDark,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 340 ? 2 : 1;
        final aspectRatio = crossAxisCount == 2 ? 2.15 : 3.6;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 10.h,
            crossAxisSpacing: 10.w,
            childAspectRatio: aspectRatio,
          ),
          itemBuilder: (_, index) {
            final item = items[index];
            return _ProfileFactCard(isDark: isDark, item: item);
          },
        );
      },
    );
  }
}

class _ProfileFactCard extends StatelessWidget {
  final bool isDark;
  final _ProfileFactItem item;

  const _ProfileFactCard({
    required this.isDark,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: _surfaceSoft(isDark),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Row(
        children: [
          Container(
            width: 34.w,
            height: 34.w,
            decoration: BoxDecoration(
              color: _academyBlue.withOpacity(isDark ? 0.20 : 0.10),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(item.icon, size: 17.sp, color: _academyBlue),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: _bodyStyle(
                    isDark,
                    size: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: _textSecondary(isDark),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _bodyStyle(
                    isDark,
                    size: 13.sp,
                    fontWeight: FontWeight.w800,
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

class _TopChip extends StatelessWidget {
  final bool isDark;
  final String label;
  final Color color;

  const _TopChip({
    required this.isDark,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        label,
        style: _bodyStyle(
          isDark,
          size: 11.sp,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final Color? iconColor;
  final Widget child;

  const _SectionCard({
    required this.isDark,
    required this.icon,
    required this.title,
    this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: _surface(isDark),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: _border(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  color: (iconColor ?? _academyBlue)
                      .withOpacity(isDark ? 0.20 : 0.10),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  icon,
                  size: 18.sp,
                  color: iconColor ?? _academyBlue,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(title, style: _titleStyle(isDark, size: 21.sp)),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          child,
        ],
      ),
    );
  }
}

class _GuardianResponsiveTile extends StatelessWidget {
  final bool isDark;
  final TeacherGuardianContact contact;
  final String highlightLabel;
  final void Function(String phone, bool isWhatsApp) onContactTap;
  final bool compact;

  const _GuardianResponsiveTile({
    required this.isDark,
    required this.contact,
    required this.highlightLabel,
    required this.onContactTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhone = (contact.phoneNumber ?? '').trim().isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final inlineActions = constraints.maxWidth >= 360;

        return Container(
          padding: EdgeInsets.all(compact ? 14.w : 16.w),
          decoration: BoxDecoration(
            color: _surfaceSoft(isDark),
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: inlineActions
              ? Row(
                  children: [
                    _GuardianAvatar(isDark: isDark, compact: compact),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _GuardianInfo(
                        isDark: isDark,
                        highlightLabel: highlightLabel,
                        name: contact.name,
                        phone: contact.phoneNumber,
                      ),
                    ),
                    if (hasPhone) ...[
                      SizedBox(width: 12.w),
                      _ContactActions(
                        isDark: isDark,
                        phone: contact.phoneNumber!,
                        onContactTap: onContactTap,
                      ),
                    ],
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _GuardianAvatar(isDark: isDark, compact: compact),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _GuardianInfo(
                            isDark: isDark,
                            highlightLabel: highlightLabel,
                            name: contact.name,
                            phone: contact.phoneNumber,
                          ),
                        ),
                      ],
                    ),
                    if (hasPhone) ...[
                      SizedBox(height: 12.h),
                      _ContactActions(
                        isDark: isDark,
                        phone: contact.phoneNumber!,
                        onContactTap: onContactTap,
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _GuardianAvatar extends StatelessWidget {
  final bool isDark;
  final bool compact;

  const _GuardianAvatar({
    required this.isDark,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 42.w : 48.w,
      height: compact ? 42.w : 48.w,
      decoration: BoxDecoration(
        color: _academyBlue.withOpacity(isDark ? 0.20 : 0.10),
        shape: BoxShape.circle,
      ),
      child: Icon(
        PhosphorIcons.user,
        color: _academyBlue,
        size: compact ? 18.sp : 20.sp,
      ),
    );
  }
}

class _GuardianInfo extends StatelessWidget {
  final bool isDark;
  final String highlightLabel;
  final String name;
  final String? phone;

  const _GuardianInfo({
    required this.isDark,
    required this.highlightLabel,
    required this.name,
    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          highlightLabel,
          style: _bodyStyle(
            isDark,
            size: 11.sp,
            fontWeight: FontWeight.w800,
            color: _textSecondary(isDark),
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          name,
          style: _bodyStyle(
            isDark,
            size: 15.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 5.h),
        Row(
          children: [
            Icon(
              PhosphorIcons.phone,
              size: 13.sp,
              color: _textSecondary(isDark),
            ),
            SizedBox(width: 6.w),
            Expanded(
              child: Text(
                (phone ?? '').trim().isEmpty
                    ? 'Telefone não informado'
                    : phone!,
                style: _bodyStyle(
                  isDark,
                  size: 12.sp,
                  color: _textSecondary(isDark),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ContactActions extends StatelessWidget {
  final bool isDark;
  final String phone;
  final void Function(String phone, bool isWhatsApp) onContactTap;

  const _ContactActions({
    required this.isDark,
    required this.phone,
    required this.onContactTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        _CircleActionButton(
          background: _academyGreen.withOpacity(isDark ? 0.18 : 0.10),
          iconColor: _academyGreen,
          icon: PhosphorIcons.whatsapp_logo,
          onTap: () => onContactTap(phone, true),
        ),
        _CircleActionButton(
          background: _academyBlue.withOpacity(isDark ? 0.18 : 0.10),
          iconColor: _academyBlue,
          icon: PhosphorIcons.phone,
          onTap: () => onContactTap(phone, false),
        ),
      ],
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  final Color background;
  final Color iconColor;
  final IconData icon;
  final VoidCallback onTap;

  const _CircleActionButton({
    required this.background,
    required this.iconColor,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40.w,
          height: 40.w,
          child: Icon(icon, color: iconColor, size: 18.sp),
        ),
      ),
    );
  }
}

class _HealthAlertCard extends StatelessWidget {
  final bool isDark;
  final String label;
  final String description;

  const _HealthAlertCard({
    required this.isDark,
    required this.label,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: _errorColor.withOpacity(isDark ? 0.14 : 0.06),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: _errorColor.withOpacity(0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38.w,
            height: 38.w,
            decoration: BoxDecoration(
              color: _errorColor.withOpacity(isDark ? 0.20 : 0.12),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              PhosphorIcons.warning_circle_fill,
              color: _errorColor,
              size: 18.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: _bodyStyle(
                    isDark,
                    size: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: _errorColor,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  description,
                  style: _bodyStyle(
                    isDark,
                    size: 13.sp,
                    color: _textPrimary(isDark),
                    height: 1.45,
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

class _HealthDetailCard extends StatelessWidget {
  final bool isDark;
  final TeacherHealthDetail detail;

  const _HealthDetailCard({
    required this.isDark,
    required this.detail,
  });

  Color _toneColor() {
    switch (detail.tone) {
      case TeacherHealthTone.critical:
        return _errorColor;
      case TeacherHealthTone.warning:
        return _warningColor;
      case TeacherHealthTone.info:
        return _academyBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _toneColor();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: _surfaceSoft(isDark),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10.w,
            height: 10.w,
            margin: EdgeInsets.only(top: 5.h),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.label,
                  style: _bodyStyle(
                    isDark,
                    size: 13.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if ((detail.value ?? '').trim().isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  Text(
                    detail.value ?? '',
                    style: _bodyStyle(
                      isDark,
                      size: 13.sp,
                      color: _textSecondary(isDark),
                      height: 1.45,
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

class _MetricGridItem {
  final String label;
  final String value;
  final Color color;

  const _MetricGridItem({
    required this.label,
    required this.value,
    required this.color,
  });
}

class _ResponsiveMetricGrid extends StatelessWidget {
  final bool isDark;
  final List<_MetricGridItem> items;

  const _ResponsiveMetricGrid({
    required this.isDark,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10.h,
        crossAxisSpacing: 10.w,
        childAspectRatio: 1.9,
      ),
      itemBuilder: (_, index) {
        final item = items[index];
        return _MetricCard(
          isDark: isDark,
          label: item.label,
          value: item.value,
          color: item.color,
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final bool isDark;
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.isDark,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: _titleStyle(isDark, size: 22.sp).copyWith(color: color),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: _bodyStyle(
              isDark,
              size: 12.sp,
              fontWeight: FontWeight.w800,
              color: _textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceRecordTile extends StatelessWidget {
  final bool isDark;
  final TeacherAttendanceRecord record;
  final Color color;
  final String dateLabel;

  const _AttendanceRecordTile({
    required this.isDark,
    required this.record,
    required this.color,
    required this.dateLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: _surfaceSoft(isDark),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12.w,
            height: 12.w,
            margin: EdgeInsets.only(top: 4.h),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        record.label,
                        style: _bodyStyle(
                          isDark,
                          size: 14.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Text(
                      dateLabel,
                      style: _bodyStyle(
                        isDark,
                        size: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: _textSecondary(isDark),
                      ),
                    ),
                  ],
                ),
                if (record.observation.trim().isNotEmpty) ...[
                  SizedBox(height: 6.h),
                  Text(
                    record.observation,
                    style: _bodyStyle(
                      isDark,
                      size: 12.sp,
                      color: _textSecondary(isDark),
                      height: 1.4,
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

class _SectionEmptyState extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String message;

  const _SectionEmptyState({
    required this.isDark,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 8.w),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 34.sp, color: _textSecondary(isDark)),
            SizedBox(height: 10.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: _bodyStyle(
                isDark,
                size: 13.sp,
                color: _textSecondary(isDark),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeacherNoteCard extends StatelessWidget {
  final StudentNoteModel note;
  final bool isDark;
  final String Function(DateTime? date) formatDateTime;

  const _TeacherNoteCard({
    required this.note,
    required this.isDark,
    required this.formatDateTime,
  });

  @override
  Widget build(BuildContext context) {
    late final Color tagColor;
    late final String tagLabel;
    late final IconData tagIcon;

    switch (note.type) {
      case StudentNoteType.attention:
        tagColor = _warningColor;
        tagLabel = 'Atenção';
        tagIcon = PhosphorIcons.warning;
        break;
      case StudentNoteType.warning:
        tagColor = _errorColor;
        tagLabel = 'Advertência';
        tagIcon = PhosphorIcons.warning_octagon;
        break;
      case StudentNoteType.private:
      default:
        tagColor = _academyBlue;
        tagLabel = 'Privada';
        tagIcon = PhosphorIcons.lock_key;
        break;
    }

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: _surfaceSoft(isDark),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: _border(isDark).withOpacity(0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 7.h,
                      ),
                      decoration: BoxDecoration(
                        color: tagColor.withOpacity(isDark ? 0.20 : 0.10),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(tagIcon, size: 14.sp, color: tagColor),
                          SizedBox(width: 6.w),
                          Text(
                            tagLabel,
                            style: _bodyStyle(
                              isDark,
                              size: 11.sp,
                              fontWeight: FontWeight.w800,
                              color: tagColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                formatDateTime(note.createdAt),
                textAlign: TextAlign.end,
                style: _bodyStyle(
                  isDark,
                  size: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: _textSecondary(isDark),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(note.title, style: _titleStyle(isDark, size: 19.sp)),
          SizedBox(height: 6.h),
          Text(
            note.description,
            style: _bodyStyle(
              isDark,
              size: 13.sp,
              color: _textSecondary(isDark),
              height: 1.5,
            ),
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              CircleAvatar(
                radius: 13.sp,
                backgroundColor: _surface(isDark),
                backgroundImage:
                    (note.createdBy?.profilePictureUrl ?? '').isNotEmpty
                        ? NetworkImage(note.createdBy!.profilePictureUrl!)
                        : null,
                child: (note.createdBy?.profilePictureUrl ?? '').isEmpty
                    ? Icon(
                        PhosphorIcons.user,
                        size: 14.sp,
                        color: _textSecondary(isDark),
                      )
                    : null,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  'Por: ${note.createdBy?.fullName ?? 'Professor'}',
                  style: _bodyStyle(
                    isDark,
                    size: 12.sp,
                    fontWeight: FontWeight.w800,
                    color: _textSecondary(isDark),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateNoteBottomSheet extends StatefulWidget {
  final String studentId;
  final String studentName;

  const _CreateNoteBottomSheet({
    required this.studentId,
    required this.studentName,
  });

  @override
  State<_CreateNoteBottomSheet> createState() => _CreateNoteBottomSheetState();
}

class _CreateNoteBottomSheetState extends State<_CreateNoteBottomSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedType = 'PRIVATE';

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty ||
        _descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha título e descrição.'),
          backgroundColor: _errorColor,
        ),
      );
      return;
    }

    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final noteProv = Provider.of<StudentNoteProvider>(context, listen: false);

    final success = await showAttendanceOperationDialog(
      context: context,
      operation: () async {
        final result = await noteProv.createNote(
          authProvider: authProv,
          studentId: widget.studentId,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          type: _selectedType,
        );

        if (!result) {
          throw Exception(noteProv.errorMessage ?? 'Erro ao salvar anotação.');
        }
      },
      loadingTitle: 'Salvando',
      loadingMessage: 'Registrando anotação...',
      successTitle: 'Salvo',
      successMessage: 'A anotação foi vinculada ao perfil do aluno.',
    );

    if (success == true && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: _surface(isDark),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 28.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nova anotação',
                          style: _titleStyle(isDark, size: 22.sp)),
                      SizedBox(height: 4.h),
                      Text(
                        widget.studentName,
                        style: _bodyStyle(
                          isDark,
                          size: 13.sp,
                          color: _textSecondary(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: _surfaceSoft(isDark),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.pop(context),
                    child: SizedBox(
                      width: 38.w,
                      height: 38.w,
                      child: Icon(
                        PhosphorIcons.x,
                        size: 18.sp,
                        color: _textPrimary(isDark),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 18.h),
            _BottomSheetLabel(isDark: isDark, label: 'Visibilidade'),
            SizedBox(height: 8.h),
            DropdownButtonFormField<String>(
              value: _selectedType,
              dropdownColor: _surfaceSoft(isDark),
              decoration: _inputDecoration(isDark),
              items: [
                DropdownMenuItem(
                  value: 'PRIVATE',
                  child: Text(
                    'Privado (somente professor)',
                    style: TextStyle(color: _textPrimary(isDark)),
                  ),
                ),
                DropdownMenuItem(
                  value: 'ATTENTION',
                  child: Text(
                    'Atenção',
                    style: TextStyle(
                      color: _warningColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'WARNING',
                  child: Text(
                    'Advertência',
                    style: TextStyle(
                      color: _errorColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _selectedType = value ?? 'PRIVATE'),
            ),
            SizedBox(height: 16.h),
            _BottomSheetLabel(isDark: isDark, label: 'Assunto'),
            SizedBox(height: 8.h),
            TextField(
              controller: _titleController,
              style: GoogleFonts.inter(color: _textPrimary(isDark)),
              decoration: _inputDecoration(isDark).copyWith(
                hintText: 'Ex: observação de sala',
              ),
            ),
            SizedBox(height: 16.h),
            _BottomSheetLabel(isDark: isDark, label: 'Descrição'),
            SizedBox(height: 8.h),
            TextField(
              controller: _descController,
              maxLines: 4,
              style: GoogleFonts.inter(color: _textPrimary(isDark)),
              decoration: _inputDecoration(isDark).copyWith(
                hintText: 'Descreva a ocorrência ou anotação.',
              ),
            ),
            SizedBox(height: 22.h),
            SizedBox(
              width: double.infinity,
              height: 54.h,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _academyBlue,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                child: Text(
                  'Registrar anotação',
                  style: _bodyStyle(
                    isDark,
                    size: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(bool isDark) {
    return InputDecoration(
      filled: true,
      fillColor: _surfaceSoft(isDark),
      hintStyle: GoogleFonts.inter(color: _textSecondary(isDark)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: BorderSide(color: _border(isDark)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: BorderSide(color: _border(isDark)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: const BorderSide(color: _academyBlue),
      ),
    );
  }
}

class _BottomSheetLabel extends StatelessWidget {
  final bool isDark;
  final String label;

  const _BottomSheetLabel({
    required this.isDark,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: _bodyStyle(
        isDark,
        size: 13.sp,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
