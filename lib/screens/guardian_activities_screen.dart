import 'package:academyhub_mobile/model/guardian_auth_model.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/services/guardian_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class GuardianActivitiesScreen extends StatefulWidget {
  final GuardianLinkedStudent student;

  const GuardianActivitiesScreen({
    super.key,
    required this.student,
  });

  @override
  State<GuardianActivitiesScreen> createState() =>
      _GuardianActivitiesScreenState();
}

class _GuardianActivitiesScreenState extends State<GuardianActivitiesScreen> {
  final GuardianAuthService _service = GuardianAuthService();

  GuardianActivitiesScreenData? _data;
  bool _isLoading = true;
  int _selectedFilter = 0;
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
            'Sua sessão expirou. Entre novamente para acompanhar as atividades.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _service.getGuardianActivities(
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
    final summary = _data?.activities.summary;
    final items = _filteredItems();

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
              'Atividades',
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
              ? _GuardianActivitiesError(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  color: const Color(0xFF00A859),
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
                    children: [
                      _GuardianActivitiesStudentCard(student: student),
                      SizedBox(height: 16.h),
                      _GuardianActivitiesHero(summary: summary),
                      SizedBox(height: 16.h),
                      Wrap(
                        spacing: 10.w,
                        runSpacing: 10.h,
                        children: [
                          _GuardianActivitiesChip(
                            label: 'Pendentes',
                            selected: _selectedFilter == 0,
                            onTap: () => setState(() => _selectedFilter = 0),
                          ),
                          _GuardianActivitiesChip(
                            label: 'Entregues',
                            selected: _selectedFilter == 1,
                            onTap: () => setState(() => _selectedFilter = 1),
                          ),
                          _GuardianActivitiesChip(
                            label: 'Recentes',
                            selected: _selectedFilter == 2,
                            onTap: () => setState(() => _selectedFilter = 2),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      if (items.isEmpty)
                        const _GuardianActivitiesEmpty(
                          title: 'Nenhuma atividade nesta visão',
                          message:
                              'Quando houver novas atividades com visibilidade para responsáveis, elas aparecerão aqui.',
                        )
                      else
                        ...items.map(
                          (item) => Padding(
                            padding: EdgeInsets.only(bottom: 10.h),
                            child: _GuardianActivityCard(item: item),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  List<GuardianActivityItem> _filteredItems() {
    final items = _data?.activities.items ?? const <GuardianActivityItem>[];

    switch (_selectedFilter) {
      case 1:
        return items.where((item) => item.isDelivered).toList();
      case 2:
        return [...items]
          ..sort((left, right) {
            final leftDate = left.dueDate ?? left.assignedAt ?? DateTime(2000);
            final rightDate =
                right.dueDate ?? right.assignedAt ?? DateTime(2000);
            return rightDate.compareTo(leftDate);
          });
      case 0:
      default:
        return items
            .where((item) => item.isPending || item.isOverdue)
            .toList();
    }
  }
}

class _GuardianActivitiesHero extends StatelessWidget {
  final GuardianActivitiesSummary? summary;

  const _GuardianActivitiesHero({
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(22.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _GuardianActivitiesPill(
            label: 'Resumo do período',
            color: Color(0xFF2F80ED),
          ),
          SizedBox(height: 14.h),
          Text(
            '${summary?.recentCount ?? 0} atividades recentes',
            style: TextStyle(
              color: const Color(0xFF111827),
              fontSize: 30.sp,
              fontFamily: 'GR Milesons Three',
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Entregues: ${summary?.deliveredCount ?? 0} · Pendentes: ${summary?.pendingCount ?? 0} · Em atraso: ${summary?.overdueCount ?? 0}',
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

class _GuardianActivityCard extends StatelessWidget {
  final GuardianActivityItem item;

  const _GuardianActivityCard({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final accent = item.isOverdue
        ? const Color(0xFFEF4444)
        : item.isDelivered
            ? const Color(0xFF00A859)
            : const Color(0xFFF59E0B);

    final dueLabel = item.dueDate != null
        ? DateFormat('dd/MM/yyyy').format(item.dueDate!)
        : 'Sem prazo';

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: GoogleFonts.inter(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
              _GuardianActivitiesPill(
                label: _labelForItem(item),
                color: accent,
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            item.subjectName.trim().isEmpty
                ? item.teacherName
                : '${item.subjectName} · ${item.teacherName}',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B7280),
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            item.description.trim().isEmpty
                ? 'Sem descrição complementar.'
                : item.description,
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF4B5563),
              height: 1.45,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Icon(
                PhosphorIcons.calendar_blank_fill,
                size: 16.sp,
                color: const Color(0xFF6B7280),
              ),
              SizedBox(width: 6.w),
              Text(
                'Prazo: $dueLabel',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          if (item.teacherNote.trim().isNotEmpty) ...[
            SizedBox(height: 10.h),
            const Divider(height: 1),
            SizedBox(height: 10.h),
            Text(
              item.teacherNote,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF374151),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _labelForItem(GuardianActivityItem item) {
    if (item.isOverdue) return 'Em atraso';
    switch (item.deliveryStatus.toUpperCase()) {
      case 'DELIVERED':
        return 'Entregue';
      case 'PARTIAL':
        return 'Parcial';
      case 'NOT_DELIVERED':
        return 'Não entregue';
      case 'EXCUSED':
        return 'Dispensado';
      case 'PENDING':
      default:
        return 'Pendente';
    }
  }
}

class _GuardianActivitiesStudentCard extends StatelessWidget {
  final GuardianLinkedStudent student;

  const _GuardianActivitiesStudentCard({
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

class _GuardianActivitiesChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GuardianActivitiesChip({
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

class _GuardianActivitiesPill extends StatelessWidget {
  final String label;
  final Color color;

  const _GuardianActivitiesPill({
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

class _GuardianActivitiesEmpty extends StatelessWidget {
  final String title;
  final String message;

  const _GuardianActivitiesEmpty({
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
              PhosphorIcons.notebook_fill,
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

class _GuardianActivitiesError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _GuardianActivitiesError({
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
