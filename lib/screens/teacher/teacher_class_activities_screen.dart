import 'package:academyhub_mobile/model/class_activity_model.dart';
import 'package:academyhub_mobile/model/class_model.dart';
import 'package:academyhub_mobile/model/horario_model.dart';
import 'package:academyhub_mobile/model/subject_model.dart';
import 'package:academyhub_mobile/providers/academic_calendar_provider.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/providers/class_activity_list_provider.dart';
import 'package:academyhub_mobile/providers/horario_provider.dart';
import 'package:academyhub_mobile/screens/teacher/class_activity_detail_screen.dart';
import 'package:academyhub_mobile/screens/teacher/create_edit_class_activity_screen.dart';
import 'package:academyhub_mobile/util/teacher_class_context_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

enum _ActivityBoardFilter {
  upcoming,
  planned,
  review,
  history,
}

class TeacherClassActivitiesScreen extends StatefulWidget {
  final ClassModel classData;
  final HorarioModel? preferredSchedule;

  const TeacherClassActivitiesScreen({
    super.key,
    required this.classData,
    this.preferredSchedule,
  });

  @override
  State<TeacherClassActivitiesScreen> createState() =>
      _TeacherClassActivitiesScreenState();
}

class _TeacherClassActivitiesScreenState
    extends State<TeacherClassActivitiesScreen> {
  final ClassActivityListProvider _provider = ClassActivityListProvider();
  final TextEditingController _searchController = TextEditingController();

  _ActivityBoardFilter _selectedFilter = _ActivityBoardFilter.upcoming;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadActivities();
    });
    _searchController.addListener(() {
      if (!mounted) return;
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _provider.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadActivities({bool refresh = false}) {
    final classId = widget.classData.id;
    if (classId.isEmpty) {
      return Future<void>.value();
    }

    return _provider.loadActivities(
      context.read<AuthProvider>(),
      classId: classId,
      refresh: refresh,
    );
  }

  Future<void> _openCreateOrEdit([ClassActivity? activity]) async {
    final authProvider = context.read<AuthProvider>();
    final horarioProvider = context.read<HorarioProvider>();
    final academicProvider = context.read<AcademicCalendarProvider>();
    final availableSubjects = TeacherClassContextHelper.subjectsForClass(
      classId: widget.classData.id,
      horarios: horarioProvider.horarios,
      user: authProvider.user,
      terms: academicProvider.terms,
    );

    SubjectModel? suggestedSubject;
    if (widget.preferredSchedule != null) {
      for (final subject in availableSubjects) {
        if (subject.id == widget.preferredSchedule!.subjectId) {
          suggestedSubject = subject;
          break;
        }
      }
    }

    final result = await Navigator.of(context).push<ClassActivity>(
      MaterialPageRoute(
        builder: (_) => CreateEditClassActivityScreen(
          classData: widget.classData,
          activity: activity,
          availableSubjects: availableSubjects,
          suggestedSubject: suggestedSubject,
        ),
      ),
    );

    if (result != null && mounted) {
      await _loadActivities(refresh: true);
    }
  }

  Future<void> _openDetail(ClassActivity activity) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ClassActivityDetailScreen(
          activityId: activity.id,
          fallbackClassData: widget.classData,
        ),
      ),
    );

    if (!mounted) return;
    await _loadActivities(refresh: true);
  }

  List<ClassActivity> _applyLocalFilters(List<ClassActivity> items) {
    final now = DateTime.now();

    return items.where((activity) {
      final matchesQuery = _searchQuery.isEmpty ||
          [
            activity.title,
            activity.description,
            activity.sourceReference,
            activity.subject?.name ?? '',
          ].join(' ').toLowerCase().contains(_searchQuery);

      if (!matchesQuery) {
        return false;
      }

      switch (_selectedFilter) {
        case _ActivityBoardFilter.upcoming:
          return activity.workflowState == ClassActivityStatus.active &&
              (activity.dueDate == null ||
                  activity.dueDate!
                      .isAfter(now.subtract(const Duration(days: 1))));
        case _ActivityBoardFilter.planned:
          return activity.workflowState == ClassActivityStatus.planned;
        case _ActivityBoardFilter.review:
          return activity.workflowState == ClassActivityStatus.inReview;
        case _ActivityBoardFilter.history:
          return activity.workflowState.isHistory;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChangeNotifierProvider<ClassActivityListProvider>.value(
      value: _provider,
      child: Consumer<ClassActivityListProvider>(
        builder: (context, provider, _) {
          final filteredActivities = _applyLocalFilters(provider.activities);
          final upcomingCount = provider.activities
              .where((item) => item.workflowState == ClassActivityStatus.active)
              .length;
          final plannedCount = provider.activities
              .where(
                  (item) => item.workflowState == ClassActivityStatus.planned)
              .length;
          final reviewCount = provider.activities
              .where(
                  (item) => item.workflowState == ClassActivityStatus.inReview)
              .length;

          return Scaffold(
            backgroundColor:
                isDark ? const Color(0xFF090C10) : const Color(0xFFF4F7FB),
            appBar: AppBar(
              elevation: 0,
              backgroundColor: Colors.transparent,
              foregroundColor: isDark ? Colors.white : const Color(0xFF1A2230),
              titleSpacing: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Atividades',
                    style: GoogleFonts.inter(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    widget.classData.name,
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color:
                          isDark ? Colors.grey[400] : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => _openCreateOrEdit(),
              backgroundColor: const Color(0xFF00A859),
              foregroundColor: Colors.white,
              icon: const Icon(PhosphorIcons.plus_bold),
              label: Text(
                'Nova atividade',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
            body: RefreshIndicator(
              onRefresh: () => _loadActivities(refresh: true),
              child: ListView(
                padding: EdgeInsets.fromLTRB(18.w, 8.h, 18.w, 110.h),
                children: [
                  _ActivitiesHeroCard(
                    classData: widget.classData,
                    preferredSchedule: widget.preferredSchedule,
                    isDark: isDark,
                    totalActivities: provider.activities.length,
                    upcomingCount: upcomingCount,
                    plannedCount: plannedCount,
                    reviewCount: reviewCount,
                  ),
                  SizedBox(height: 18.h),
                  _SearchField(
                    controller: _searchController,
                    isDark: isDark,
                  ),
                  SizedBox(height: 16.h),
                  SizedBox(
                    height: 42.h,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _FilterChipButton(
                          label: 'Hoje & próximas',
                          isSelected:
                              _selectedFilter == _ActivityBoardFilter.upcoming,
                          onTap: () => setState(
                            () =>
                                _selectedFilter = _ActivityBoardFilter.upcoming,
                          ),
                        ),
                        _FilterChipButton(
                          label: 'Planejadas',
                          isSelected:
                              _selectedFilter == _ActivityBoardFilter.planned,
                          onTap: () => setState(
                            () =>
                                _selectedFilter = _ActivityBoardFilter.planned,
                          ),
                        ),
                        _FilterChipButton(
                          label: 'Em correção',
                          isSelected:
                              _selectedFilter == _ActivityBoardFilter.review,
                          onTap: () => setState(
                            () => _selectedFilter = _ActivityBoardFilter.review,
                          ),
                        ),
                        _FilterChipButton(
                          label: 'Histórico',
                          isSelected:
                              _selectedFilter == _ActivityBoardFilter.history,
                          onTap: () => setState(
                            () =>
                                _selectedFilter = _ActivityBoardFilter.history,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 18.h),
                  if (provider.isLoading && provider.activities.isEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 80.h),
                      child: const Center(child: CircularProgressIndicator()),
                    )
                  else if (provider.errorMessage != null &&
                      provider.activities.isEmpty)
                    _ErrorState(
                      isDark: isDark,
                      message: provider.errorMessage!,
                      onRetry: _loadActivities,
                    )
                  else if (filteredActivities.isEmpty)
                    _EmptyActivitiesState(
                      isDark: isDark,
                      filter: _selectedFilter,
                      hasSearch: _searchQuery.isNotEmpty,
                    )
                  else
                    ...filteredActivities.map(
                      (activity) => Padding(
                        padding: EdgeInsets.only(bottom: 14.h),
                        child: _ActivityCard(
                          activity: activity,
                          isDark: isDark,
                          onTap: () => _openDetail(activity),
                          onEdit: () => _openCreateOrEdit(activity),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ActivitiesHeroCard extends StatelessWidget {
  final ClassModel classData;
  final HorarioModel? preferredSchedule;
  final bool isDark;
  final int totalActivities;
  final int upcomingCount;
  final int plannedCount;
  final int reviewCount;

  const _ActivitiesHeroCard({
    required this.classData,
    required this.preferredSchedule,
    required this.isDark,
    required this.totalActivities,
    required this.upcomingCount,
    required this.plannedCount,
    required this.reviewCount,
  });

  @override
  Widget build(BuildContext context) {
    final badgeLabel = preferredSchedule?.subject.name.trim().isNotEmpty == true
        ? preferredSchedule!.subject.name
        : '${classData.grade} • ${classData.shift}';

    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.r),
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF151B24), Color(0xFF0F172A)]
              : const [Color(0xFF0F172A), Color(0xFF1769FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999.r),
            ),
            child: Text(
              badgeLabel,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 11.sp,
              ),
            ),
          ),
          SizedBox(height: 14.h),
          Text(
            classData.name,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 26.sp,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Crie rápido, acompanhe pendências e entre na correção sem perder tempo.',
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.86),
              fontSize: 13.sp,
              height: 1.45,
            ),
          ),
          SizedBox(height: 18.h),
          Row(
            children: [
              _HeroMetric(label: 'Total', value: '$totalActivities'),
              _HeroMetric(label: 'Próximas', value: '$upcomingCount'),
              _HeroMetric(label: 'Planejadas', value: '$plannedCount'),
              _HeroMetric(label: 'Correção', value: '$reviewCount'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.only(right: 8.w),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18.sp,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.82),
                fontSize: 11.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;

  const _SearchField({
    required this.controller,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: GoogleFonts.inter(
        fontSize: 14.sp,
        color: isDark ? Colors.white : const Color(0xFF1A2230),
      ),
      decoration: InputDecoration(
        hintText: 'Buscar atividade, referência ou disciplina...',
        hintStyle: GoogleFonts.inter(
          color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
        ),
        prefixIcon: Icon(
          PhosphorIcons.magnifying_glass,
          color: isDark ? Colors.grey[500] : const Color(0xFF64748B),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF161B22) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18.r),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF2A313B) : const Color(0xFFE7EBF2),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18.r),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF2A313B) : const Color(0xFFE7EBF2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18.r),
          borderSide: const BorderSide(color: Color(0xFF00A859), width: 1.3),
        ),
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(right: 10.w),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF00A859)
                : isDark
                    ? const Color(0xFF171B20)
                    : Colors.white,
            borderRadius: BorderRadius.circular(999.r),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF00A859)
                  : isDark
                      ? const Color(0xFF2A313B)
                      : const Color(0xFFE7EBF2),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? Colors.white
                    : isDark
                        ? Colors.grey[300]
                        : const Color(0xFF475569),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final ClassActivity activity;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _ActivityCard({
    required this.activity,
    required this.isDark,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final dueLabel = activity.dueDate == null
        ? 'Sem prazo'
        : DateFormat('dd/MM • HH:mm').format(activity.dueDate!);
    final statusColor = _statusColor(activity.workflowState);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14181F) : Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: isDark ? const Color(0xFF262D37) : const Color(0xFFE7EBF2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22.r),
          child: Padding(
            padding: EdgeInsets.all(18.w),
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
                          Wrap(
                            spacing: 8.w,
                            runSpacing: 8.h,
                            children: [
                              _Badge(
                                label: activity.workflowState.label,
                                background: statusColor.withOpacity(0.12),
                                color: statusColor,
                              ),
                              _Badge(
                                label: activity.activityType.label,
                                background:
                                    const Color(0xFF1769FF).withOpacity(0.1),
                                color: const Color(0xFF1769FF),
                              ),
                              _Badge(
                                label: activity.sourceType.label,
                                background:
                                    const Color(0xFFF2994A).withOpacity(0.12),
                                color: const Color(0xFFF2994A),
                              ),
                              if (activity.isGraded)
                                _Badge(
                                  label:
                                      'Vale ${activity.maxScore?.toStringAsFixed(1) ?? '10'}',
                                  background:
                                      const Color(0xFF00A859).withOpacity(0.12),
                                  color: const Color(0xFF00A859),
                                ),
                            ],
                          ),
                          SizedBox(height: 14.h),
                          Text(
                            activity.title,
                            style: GoogleFonts.inter(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A2230),
                            ),
                          ),
                          if (activity.sourceReference.trim().isNotEmpty) ...[
                            SizedBox(height: 6.h),
                            Text(
                              activity.sourceReference,
                              style: GoogleFonts.inter(
                                fontSize: 13.sp,
                                height: 1.4,
                                color: isDark
                                    ? Colors.grey[400]
                                    : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(width: 12.w),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') onEdit();
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      itemBuilder: (context) => const [
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: Text('Editar atividade'),
                        ),
                      ],
                      child: Container(
                        width: 38.w,
                        height: 38.w,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1C222B)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Icon(
                          PhosphorIcons.dots_three_outline_vertical_fill,
                          color: isDark
                              ? Colors.grey[300]
                              : const Color(0xFF475569),
                          size: 18.sp,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1A2028)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _InfoLine(
                            icon: PhosphorIcons.calendar_blank,
                            label: 'Prazo',
                            value: dueLabel,
                          ),
                          SizedBox(width: 10.w),
                          _InfoLine(
                            icon: PhosphorIcons.book_bookmark,
                            label: 'Disciplina',
                            value: activity.subject?.name ?? 'Geral',
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          _MetricPill(
                            label: 'Pendentes',
                            value: '${activity.summary.pendingCount}',
                            color: const Color(0xFFF2994A),
                          ),
                          _MetricPill(
                            label: 'Entregues',
                            value:
                                '${activity.summary.deliveredCount + activity.summary.partialCount}',
                            color: const Color(0xFF00A859),
                          ),
                          _MetricPill(
                            label: 'Corrigidos',
                            value: '${activity.summary.correctedCount}',
                            color: const Color(0xFF1769FF),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14.h),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        activity.workflowState == ClassActivityStatus.inReview
                            ? 'Hora de corrigir e fechar as pendências.'
                            : activity.workflowState ==
                                    ClassActivityStatus.planned
                                ? 'Já pode deixar tudo preparado para a turma.'
                                : activity.workflowState.isHistory
                                    ? 'Histórico pronto para consulta rápida.'
                                    : 'Abra para registrar as entregas da turma.',
                        style: GoogleFonts.inter(
                          fontSize: 12.5.sp,
                          height: 1.4,
                          color: isDark
                              ? Colors.grey[400]
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Icon(
                      PhosphorIcons.caret_right_bold,
                      size: 18.sp,
                      color:
                          isDark ? Colors.grey[400] : const Color(0xFF64748B),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(ClassActivityStatus status) {
    switch (status) {
      case ClassActivityStatus.planned:
        return const Color(0xFF1769FF);
      case ClassActivityStatus.inReview:
        return const Color(0xFFF2994A);
      case ClassActivityStatus.completed:
        return const Color(0xFF00A859);
      case ClassActivityStatus.cancelled:
        return const Color(0xFFEF4444);
      case ClassActivityStatus.active:
        return const Color(0xFF7C3AED);
    }
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color background;
  final Color color;

  const _Badge({
    required this.label,
    required this.background,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Row(
        children: [
          Icon(
            icon,
            size: 16.sp,
            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
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

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.only(right: 8.w),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final bool isDark;
  final String message;
  final Future<void> Function({bool refresh}) onRetry;

  const _ErrorState({
    required this.isDark,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171B20) : Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: isDark ? const Color(0xFF2A313B) : const Color(0xFFE7EBF2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            PhosphorIcons.warning_circle_fill,
            size: 34.sp,
            color: Colors.orange,
          ),
          SizedBox(height: 14.h),
          Text(
            'Não foi possível carregar',
            style: GoogleFonts.inter(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1A2230),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 16.h),
          ElevatedButton.icon(
            onPressed: () => onRetry(refresh: true),
            icon: const Icon(PhosphorIcons.arrow_clockwise),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}

class _EmptyActivitiesState extends StatelessWidget {
  final bool isDark;
  final _ActivityBoardFilter filter;
  final bool hasSearch;

  const _EmptyActivitiesState({
    required this.isDark,
    required this.filter,
    required this.hasSearch,
  });

  @override
  Widget build(BuildContext context) {
    String title = 'Nenhuma atividade ainda';
    String message =
        'Crie a primeira atividade da turma para organizar entregas e correções.';
    IconData icon = PhosphorIcons.notepad;
    Color accent = const Color(0xFF1769FF);

    if (hasSearch) {
      title = 'Nada encontrado';
      message = 'Tente outro termo para localizar a atividade.';
      icon = PhosphorIcons.magnifying_glass;
      accent = Colors.orange;
    } else {
      switch (filter) {
        case _ActivityBoardFilter.upcoming:
          title = 'Sem atividades próximas';
          message = 'As atividades ativas da turma vão aparecer aqui.';
          icon = PhosphorIcons.calendar_blank;
          accent = const Color(0xFF1769FF);
          break;
        case _ActivityBoardFilter.planned:
          title = 'Nada planejado';
          message = 'Use o modo rápido ou planeje atividades futuras da turma.';
          icon = PhosphorIcons.timer;
          accent = const Color(0xFF7C3AED);
          break;
        case _ActivityBoardFilter.review:
          title = 'Sem pendências de correção';
          message = 'Quando chegar o momento de corrigir, elas ficarão aqui.';
          icon = PhosphorIcons.check_square_offset;
          accent = const Color(0xFFF2994A);
          break;
        case _ActivityBoardFilter.history:
          title = 'Histórico vazio';
          message =
              'Atividades concluídas ou canceladas aparecerão neste bloco.';
          icon = PhosphorIcons.archive_box;
          accent = const Color(0xFF00A859);
          break;
      }
    }

    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171B20) : Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: isDark ? const Color(0xFF2A313B) : const Color(0xFFE7EBF2),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 62.w,
            height: 62.w,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 28.sp),
          ),
          SizedBox(height: 16.h),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1A2230),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              height: 1.45,
              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
