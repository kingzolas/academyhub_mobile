import 'package:academyhub_mobile/model/guardian_auth_model.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/services/guardian_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class GuardianAttendanceScreen extends StatefulWidget {
  final GuardianLinkedStudent student;

  const GuardianAttendanceScreen({
    super.key,
    required this.student,
  });

  @override
  State<GuardianAttendanceScreen> createState() =>
      _GuardianAttendanceScreenState();
}

class _GuardianAttendanceScreenState extends State<GuardianAttendanceScreen> {
  final GuardianAuthService _service = GuardianAuthService();

  GuardianAttendanceScreenData? _data;
  bool _isLoading = true;
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
        _error =
            'Sua sessão expirou. Entre novamente para acompanhar a frequência.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _service.getGuardianAttendance(
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
    final summary = _data?.attendance.summary;
    final records = _data?.attendance.recentRecords ?? const <GuardianAttendanceRecord>[];

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
              'Frequência',
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
              ? _GuardianAttendanceError(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  color: const Color(0xFF00A859),
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
                    children: [
                      _GuardianAttendanceStudentCard(student: student),
                      SizedBox(height: 16.h),
                      _GuardianAttendanceHero(summary: summary),
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          Expanded(
                            child: _GuardianAttendanceMetric(
                              label: 'Presenças',
                              value: '${summary?.presentCount ?? 0}',
                              color: const Color(0xFF00A859),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: _GuardianAttendanceMetric(
                              label: 'Faltas',
                              value: '${summary?.absentCount ?? 0}',
                              color: const Color(0xFFEF4444),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: _GuardianAttendanceMetric(
                              label: 'Recentes',
                              value: '${summary?.recentAbsences ?? 0}',
                              color: const Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 18.h),
                      Text(
                        'Histórico recente',
                        style: GoogleFonts.inter(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      if (records.isEmpty)
                        const _GuardianAttendanceEmpty(
                          title: 'Sem registros encontrados',
                          message:
                              'Os registros de frequência aparecerão aqui assim que forem lançados.',
                        )
                      else
                        ...records.map(
                          (record) => Padding(
                            padding: EdgeInsets.only(bottom: 10.h),
                            child: _GuardianAttendanceRecordCard(record: record),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _GuardianAttendanceHero extends StatelessWidget {
  final GuardianAttendanceSummary? summary;

  const _GuardianAttendanceHero({
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final rate = summary?.presenceRate ?? 0;
    final attention = summary?.attentionLevel == 'attention';
    final accent =
        attention ? const Color(0xFFF59E0B) : const Color(0xFF00A859);

    return Container(
      padding: EdgeInsets.all(22.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GuardianAttendancePill(
            label: attention ? 'Atenção com a frequência' : 'Frequência saudável',
            color: accent,
          ),
          SizedBox(height: 14.h),
          Text(
            '${rate.toStringAsFixed(1)}%',
            style: TextStyle(
              color: const Color(0xFF111827),
              fontSize: 34.sp,
              fontFamily: 'GR Milesons Three',
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            attention
                ? 'Vale acompanhar as faltas recentes para evitar acúmulo.'
                : 'A presença do aluno está dentro de uma faixa confortável.',
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF4B5563),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuardianAttendanceRecordCard extends StatelessWidget {
  final GuardianAttendanceRecord record;

  const _GuardianAttendanceRecordCard({
    required this.record,
  });

  @override
  Widget build(BuildContext context) {
    final isAbsent = record.isAbsent;
    final accent =
        isAbsent ? const Color(0xFFEF4444) : const Color(0xFF00A859);
    final dateLabel = record.date != null
        ? DateFormat('dd/MM/yyyy').format(record.date!)
        : 'Sem data';

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Icon(
              isAbsent
                  ? PhosphorIcons.x_circle_fill
                  : PhosphorIcons.check_circle_fill,
              color: accent,
              size: 22.sp,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.label,
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  dateLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                if (record.observation.trim().isNotEmpty) ...[
                  SizedBox(height: 6.h),
                  Text(
                    record.observation,
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF4B5563),
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

class _GuardianAttendanceMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _GuardianAttendanceMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6B7280),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 22.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuardianAttendanceStudentCard extends StatelessWidget {
  final GuardianLinkedStudent student;

  const _GuardianAttendanceStudentCard({
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

class _GuardianAttendancePill extends StatelessWidget {
  final String label;
  final Color color;

  const _GuardianAttendancePill({
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

class _GuardianAttendanceEmpty extends StatelessWidget {
  final String title;
  final String message;

  const _GuardianAttendanceEmpty({
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
              PhosphorIcons.calendar_check_fill,
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

class _GuardianAttendanceError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _GuardianAttendanceError({
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
